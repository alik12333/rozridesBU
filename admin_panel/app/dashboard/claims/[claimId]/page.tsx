'use client';

import { useState, useEffect, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { db } from '@/lib/firebase-client';
import { doc, getDoc, updateDoc, collection, query, orderBy, getDocs } from 'firebase/firestore';
import { Button } from '@/components/ui/button';
import { CheckCircle, XCircle, Handshake, ArrowLeft } from 'lucide-react';

interface ClaimData {
    claimId: string;
    bookingId: string;
    carId: string;
    hostId: string;
    renterId: string;
    hostClaimedAmount: number;
    status: string;
    resolvedInFavorOf: string | null;
    finalDeductionAmount: number | null;
    adminNotes: string | null;
    depositAmount?: number;
}

interface InspectionItem {
    description?: string;
    photoUrls: string[];
    condition: string;
}

interface Inspection {
    items: Record<string, InspectionItem>;
    fuelLevel?: string;
    odometerReading?: number;
    depositCollected?: number;
}

interface ChatMessage {
    id: string;
    text: string;
    senderId: string;
    senderName?: string;
    type: string;
    createdAt: Date;
}

export default function ClaimReviewPage() {
    const params = useParams();
    const router = useRouter();
    const claimId = params.claimId as string;

    const [claim, setClaim] = useState<ClaimData | null>(null);
    const [preTrip, setPreTrip] = useState<Inspection | null>(null);
    const [postTrip, setPostTrip] = useState<Inspection | null>(null);
    const [messages, setMessages] = useState<ChatMessage[]>([]);
    const [loading, setLoading] = useState(true);

    const [adminNotes, setAdminNotes] = useState('');
    const [customSplit, setCustomSplit] = useState('');
    const [processing, setProcessing] = useState<string | null>(null);

    const chatEndRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (!claimId) return;
        fetchData();
    }, [claimId]);

    const fetchData = async () => {
        try {
            const claimRef = doc(db, 'damageClaims', claimId);
            const claimSnap = await getDoc(claimRef);
            if (!claimSnap.exists()) return;

            const claimData = { claimId, ...claimSnap.data() } as ClaimData;

            // Fetch booking to get deposit amount
            const bookingSnap = await getDoc(doc(db, 'bookings', claimData.bookingId));
            if (bookingSnap.exists()) {
                claimData.depositAmount = bookingSnap.data().securityDeposit;
            }

            setClaim(claimData);

            if (claimData.status === 'open') {
                await updateDoc(claimRef, { status: 'admin_reviewing' });
                claimData.status = 'admin_reviewing';
                setClaim({ ...claimData });
            }

            // Fetch inspections
            const preSnap = await getDoc(doc(db, 'bookings', claimData.bookingId, 'inspections', 'pre_trip'));
            if (preSnap.exists()) setPreTrip(preSnap.data() as Inspection);

            const postSnap = await getDoc(doc(db, 'bookings', claimData.bookingId, 'inspections', 'post_trip'));
            if (postSnap.exists()) setPostTrip(postSnap.data() as Inspection);

            // Fetch chat
            const convId = `${claimData.carId}_${claimData.renterId}`;
            const msgQ = query(collection(db, 'conversations', convId, 'messages'), orderBy('createdAt', 'asc'));
            const msgSnap = await getDocs(msgQ);
            
            const msgs = msgSnap.docs.map(d => ({
                id: d.id,
                ...d.data(),
                createdAt: d.data().createdAt?.toDate() || new Date()
            })) as ChatMessage[];
            setMessages(msgs);

            setTimeout(() => {
                chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
            }, 500);

        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    const handleResolve = async (decision: 'host' | 'renter' | 'split') => {
        if (!claim) return;

        let finalAmount = 0;
        if (decision === 'host') {
            finalAmount = claim.hostClaimedAmount;
            if (!confirm(`Confirm: Host keeps PKR ${finalAmount}. This decision is final and will notify both parties.`)) return;
        } else if (decision === 'renter') {
            finalAmount = 0;
            if (!confirm(`Confirm: Full deposit returned to renter. This decision is final.`)) return;
        } else if (decision === 'split') {
            finalAmount = parseFloat(customSplit);
            if (isNaN(finalAmount) || finalAmount < 0 || finalAmount > (claim.depositAmount || 0)) {
                alert(`Invalid split amount. Must be between 0 and ${claim.depositAmount}`);
                return;
            }
            if (!confirm(`Confirm: Host keeps PKR ${finalAmount}. This is a custom split decision.`)) return;
        }

        setProcessing(decision);
        try {
            const res = await fetch(`/api/claims/${claim.claimId}/resolve`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    bookingId: claim.bookingId,
                    resolvedInFavorOf: decision,
                    finalDeductionAmount: finalAmount,
                    adminNotes,
                    hostId: claim.hostId,
                    renterId: claim.renterId,
                    depositAmount: claim.depositAmount,
                })
            });

            if (res.ok) {
                setClaim({ ...claim, status: 'resolved', resolvedInFavorOf: decision, finalDeductionAmount: finalAmount });
                alert('Claim resolved successfully.');
            } else {
                alert('Failed to resolve claim.');
            }
        } catch (e) {
            console.error(e);
            alert('Error resolving claim');
        } finally {
            setProcessing(null);
        }
    };

    const renderPhotos = (inspection: Inspection | null) => {
        if (!inspection || !inspection.items) return <div className="text-gray-500 text-sm">No data available</div>;
        return (
            <div className="space-y-6">
                {Object.entries(inspection.items).map(([area, item]) => (
                    <div key={area} className="border rounded bg-white p-3 shadow-sm">
                        <p className="font-bold capitalize mb-2">{area.replace('_', ' ')}</p>
                        <div className="grid grid-cols-2 gap-2">
                            {item.photoUrls?.map((url, i) => (
                                <img key={i} src={url} alt={area} className="w-full h-32 object-cover rounded cursor-pointer" onClick={() => window.open(url, '_blank')} />
                            ))}
                        </div>
                        <p className="text-sm mt-2 text-gray-700">{item.description || 'No damage noted.'}</p>
                    </div>
                ))}
                {(inspection.fuelLevel || inspection.odometerReading) && (
                    <div className="border rounded bg-gray-50 p-3 text-sm">
                        <p><strong>Fuel:</strong> {inspection.fuelLevel || 'N/A'}</p>
                        <p><strong>Odo:</strong> {inspection.odometerReading || 'N/A'} km</p>
                    </div>
                )}
            </div>
        );
    };

    if (loading) return <div className="p-8 text-center">Loading...</div>;
    if (!claim) return <div className="p-8 text-center text-red-500">Claim not found</div>;

    const isResolved = claim.status === 'resolved';

    return (
        <div className="flex flex-col h-[calc(100vh-100px)] overflow-hidden">
            <div className="flex items-center gap-4 mb-4 shrink-0">
                <Button variant="ghost" size="icon" onClick={() => router.push('/dashboard/claims')}>
                    <ArrowLeft className="w-5 h-5" />
                </Button>
                <div>
                    <h1 className="text-2xl font-bold">Review Claim #{claim.claimId.slice(0,8)}</h1>
                    <p className="text-muted-foreground text-sm">Booking ID: {claim.bookingId}</p>
                </div>
                {isResolved && (
                    <span className="ml-auto bg-green-100 text-green-800 font-bold px-3 py-1 rounded-full text-sm">
                        RESOLVED ({claim.resolvedInFavorOf?.toUpperCase()})
                    </span>
                )}
            </div>

            <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-4 min-h-0">
                {/* Column 1 */}
                <div className="bg-gray-100 rounded-lg p-4 overflow-y-auto">
                    <h2 className="font-bold text-lg mb-4 sticky top-0 bg-gray-100 py-2 border-b z-10">AT PICKUP</h2>
                    {renderPhotos(preTrip)}
                </div>

                {/* Column 2 */}
                <div className="bg-gray-100 rounded-lg p-4 overflow-y-auto">
                    <h2 className="font-bold text-lg mb-4 sticky top-0 bg-gray-100 py-2 border-b z-10">AT RETURN</h2>
                    {renderPhotos(postTrip)}
                </div>

                {/* Column 3 */}
                <div className="bg-gray-50 rounded-lg flex flex-col border">
                    <h2 className="font-bold text-lg p-4 border-b bg-gray-100 shrink-0">CONVERSATION</h2>
                    <div className="flex-1 p-4 overflow-y-auto space-y-3">
                        {messages.length === 0 ? <p className="text-center text-gray-500 text-sm mt-10">No messages.</p> : null}
                        {messages.map(msg => {
                            if (msg.type === 'system') {
                                return (
                                    <div key={msg.id} className="text-center text-xs text-gray-500 italic my-2">
                                        {msg.text}
                                    </div>
                                );
                            }
                            const isRenter = msg.senderId === claim.renterId;
                            return (
                                <div key={msg.id} className={`flex flex-col ${isRenter ? 'items-start' : 'items-end'}`}>
                                    <span className="text-[10px] text-gray-400 mb-1">{msg.senderName || (isRenter ? 'Renter' : 'Host')} • {msg.createdAt.toLocaleTimeString()}</span>
                                    <div className={`px-3 py-2 rounded-lg max-w-[85%] text-sm ${isRenter ? 'bg-blue-100 text-blue-900 rounded-tl-none' : 'bg-gray-200 text-gray-900 rounded-tr-none'}`}>
                                        {msg.text}
                                    </div>
                                </div>
                            );
                        })}
                        <div ref={chatEndRef} />
                    </div>
                </div>
            </div>

            {/* Resolution Panel */}
            <div className="mt-4 shrink-0 bg-white border rounded-lg shadow-sm p-5">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-lg uppercase">Admin Resolution</h3>
                    <div className="bg-red-50 text-red-700 px-3 py-1 rounded font-bold border border-red-200">
                        Host Claimed Deduction: PKR {claim.hostClaimedAmount?.toLocaleString()}
                    </div>
                </div>

                {isResolved ? (
                    <div className="bg-green-50 border border-green-200 rounded p-4 text-green-800">
                        <p className="font-bold mb-1">Decision Finalized</p>
                        <p className="text-sm">Resolved in favor of: <strong>{claim.resolvedInFavorOf?.toUpperCase()}</strong></p>
                        <p className="text-sm">Final Deduction: <strong>PKR {claim.finalDeductionAmount?.toLocaleString()}</strong></p>
                        {claim.adminNotes && <p className="text-sm mt-2 pt-2 border-t border-green-200">Notes: {claim.adminNotes}</p>}
                    </div>
                ) : (
                    <div className="flex gap-6">
                        <div className="flex-1 space-y-2">
                            <label className="text-sm font-semibold">Admin Notes (optional)</label>
                            <textarea 
                                className="w-full h-20 border rounded-md p-2 text-sm" 
                                placeholder="Explain decision..."
                                value={adminNotes}
                                onChange={e => setAdminNotes(e.target.value)}
                            />
                        </div>
                        <div className="flex-1 flex flex-col justify-end gap-3">
                            <div className="flex gap-3">
                                <Button className="flex-1 bg-teal-600 hover:bg-teal-700 h-12" onClick={() => handleResolve('renter')} disabled={!!processing}>
                                    <XCircle className="w-5 h-5 mr-2"/> SIDE WITH RENTER (Return Full Deposit)
                                </Button>
                                <Button className="flex-1 bg-red-600 hover:bg-red-700 h-12" onClick={() => handleResolve('host')} disabled={!!processing}>
                                    <CheckCircle className="w-5 h-5 mr-2"/> SIDE WITH HOST (Keep PKR {claim.hostClaimedAmount})
                                </Button>
                            </div>
                            <div className="flex gap-2 items-center bg-purple-50 p-2 rounded border border-purple-200">
                                <span className="text-sm font-bold text-purple-900 whitespace-nowrap px-2">SPLIT:</span>
                                <input 
                                    type="number" 
                                    className="border rounded px-3 py-2 w-32 text-sm" 
                                    placeholder="Amount..."
                                    value={customSplit}
                                    onChange={e => setCustomSplit(e.target.value)}
                                />
                                <Button className="flex-1 bg-purple-600 hover:bg-purple-700" onClick={() => handleResolve('split')} disabled={!!processing}>
                                    <Handshake className="w-4 h-4 mr-2"/> APPLY SPLIT
                                </Button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
