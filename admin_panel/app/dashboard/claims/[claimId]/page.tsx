'use client';

import { useState, useEffect, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { db } from '@/lib/firebase-client';
import { doc, getDoc, updateDoc, collection, query, orderBy, getDocs, onSnapshot } from 'firebase/firestore';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { CheckCircle, XCircle, Handshake, ArrowLeft, FileDown, Sparkles, Loader2 } from 'lucide-react';

interface ClaimData {
    claimId: string;
    bookingId: string;
    carId: string;
    hostId: string;
    renterId: string;
    hostClaimedAmount: number;
    description?: string;
    status: string;
    adminDecision: string | null;
    resolvedInFavorOf: string | null;
    finalDeductionAmount: number | null;
    extraChargeAmount: number;
    requiresExtraPayment: boolean;
    adminNotes: string | null;
    hostConfirmed: boolean;
    renterConfirmed: boolean;
    depositAmount?: number;
}

interface InspectionItem {
    notes?: string;
    photoUrls: string[];
    hasDamage: boolean;
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
    const [extraAmount, setExtraAmount] = useState('');
    const [processing, setProcessing] = useState<string | null>(null);

    const [aiStatus, setAiStatus] = useState<'idle' | 'analyzing' | 'complete' | 'error'>('idle');
    const [aiResult, setAiResult] = useState<{ recommendation: string, reasoning: string, suggestedSplitAmount?: number } | null>(null);

    const [confirmModal, setConfirmModal] = useState<{
        isOpen: boolean;
        type: 'host' | 'renter' | 'split' | 'extra' | 'force-close' | null;
        message: string;
        finalAmount: number;
        extraCharge: number;
    }>({ isOpen: false, type: null, message: '', finalAmount: 0, extraCharge: 0 });

    const chatEndRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (!claimId) return;

        const claimRef = doc(db, 'damageClaims', claimId);
        const unsub = onSnapshot(claimRef, async (claimSnap) => {
            if (!claimSnap.exists()) {
                setLoading(false);
                return;
            }
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

            // Fetch inspections (only once)
            if (!preTrip) {
                const preSnap = await getDoc(doc(db, 'bookings', claimData.bookingId, 'inspections', 'pre_trip'));
                if (preSnap.exists()) setPreTrip(preSnap.data() as Inspection);
            }
            if (!postTrip) {
                const postSnap = await getDoc(doc(db, 'bookings', claimData.bookingId, 'inspections', 'post_trip'));
                if (postSnap.exists()) setPostTrip(postSnap.data() as Inspection);
            }

            // Fetch chat (only once)
            if (messages.length === 0) {
                const convId = `${claimData.carId}_${claimData.renterId}`;
                const msgQ = query(collection(db, 'conversations', convId, 'messages'), orderBy('createdAt', 'asc'));
                const msgSnap = await getDocs(msgQ);
                const msgs = msgSnap.docs.map(d => ({
                    id: d.id,
                    ...d.data(),
                    createdAt: d.data().createdAt?.toDate() || new Date()
                })) as ChatMessage[];
                setMessages(msgs);
                setTimeout(() => chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 500);
            }

            setLoading(false);
        });

        return () => unsub();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [claimId]);

    const handleDownloadReport = async () => {
        if (!claim) return;
        setProcessing('report');
        try {
            const res = await fetch(`/api/bookings/${claim.bookingId}/report`);
            if (res.ok) {
                const blob = await res.blob();
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `RozRides_Report_${claim.bookingId.substring(0, 8)}.pdf`;
                document.body.appendChild(a);
                a.click();
                a.remove();
            } else {
                alert('Failed to generate report');
            }
        } catch (error) {
            console.error('Error downloading report:', error);
            alert('Error downloading report');
        } finally {
            setProcessing(null);
        }
    };

    const analyzeWithAI = async () => {
        if (!claim) return;
        setAiStatus('analyzing');
        setAiResult(null);

        try {
            const res = await fetch(`/api/claims/${claim.claimId}/analyze`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    claimDetails: {
                        description: claim.description,
                        hostClaimedAmount: claim.hostClaimedAmount,
                        depositAmount: claim.depositAmount,
                    },
                    preTrip,
                    postTrip,
                    messages: messages.map(m => ({
                        sender: m.senderId === claim.renterId ? 'Renter' : (m.senderId === claim.hostId ? 'Host' : 'System'),
                        text: m.text,
                        time: m.createdAt
                    }))
                })
            });

            if (res.ok) {
                const data = await res.json();
                setAiResult(data);
                setAiStatus('complete');
            } else {
                setAiStatus('error');
            }
        } catch (e) {
            console.error(e);
            setAiStatus('error');
        }
    };

    const handleResolveClick = (decision: 'host' | 'renter' | 'split' | 'extra') => {
        if (!claim) return;

        let finalAmount = 0;
        let extraCharge = 0;
        let message = '';
        
        if (decision === 'host') {
            finalAmount = claim.hostClaimedAmount;
            message = `Confirm: Host keeps PKR ${finalAmount}. This will notify both parties.`;
        } else if (decision === 'renter') {
            finalAmount = 0;
            message = `Confirm: Full deposit returned to renter.`;
        } else if (decision === 'split') {
            finalAmount = parseFloat(customSplit);
            if (isNaN(finalAmount) || finalAmount < 0 || finalAmount > (claim.depositAmount || 0)) {
                alert(`Invalid split amount. Must be between 0 and ${claim.depositAmount}`);
                return;
            }
            message = `Confirm: Host keeps PKR ${finalAmount}. This is a custom split decision.`;
        } else if (decision === 'extra') {
            extraCharge = parseFloat(extraAmount);
            if (isNaN(extraCharge) || extraCharge <= 0) {
                alert(`Invalid extra amount. Must be a positive number greater than 0.`);
                return;
            }
            finalAmount = claim.depositAmount || 0;
            message = `Confirm: Host keeps full deposit AND renter pays extra PKR ${extraCharge}.`;
        }

        setConfirmModal({
            isOpen: true,
            type: decision,
            message,
            finalAmount,
            extraCharge
        });
    };

    const executeResolve = async () => {
        if (!claim || !confirmModal.type || confirmModal.type === 'force-close') return;

        setProcessing(confirmModal.type);
        setConfirmModal(prev => ({ ...prev, isOpen: false }));
        
        try {
            const res = await fetch(`/api/claims/${claim.claimId}/resolve`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    bookingId: claim.bookingId,
                    resolvedInFavorOf: confirmModal.type,
                    finalDeductionAmount: confirmModal.finalAmount,
                    extraChargeAmount: confirmModal.extraCharge,
                    adminNotes,
                    hostId: claim.hostId,
                    renterId: claim.renterId,
                    depositAmount: claim.depositAmount,
                })
            });

            if (res.ok) {
                alert('Claim decision posted. Awaiting confirmation from parties.');
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

    const handleForceCloseClick = () => {
        if (!claim) return;
        setConfirmModal({
            isOpen: true,
            type: 'force-close',
            message: 'Are you sure you want to FORCE CLOSE this trip? This bypasses the cash settlement confirmation.',
            finalAmount: 0,
            extraCharge: 0
        });
    };

    const executeForceClose = async () => {
        if (!claim) return;
        
        setProcessing('force-close');
        setConfirmModal(prev => ({ ...prev, isOpen: false }));
        
        try {
            const res = await fetch(`/api/claims/${claim.claimId}/force-close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    bookingId: claim.bookingId,
                    adminReason: 'Admin manually closed this trip due to unresponsive parties.',
                }),
            });
            if (res.ok) {
                alert('Trip force closed successfully.');
            } else {
                const err = await res.json();
                alert(`Failed to force close: ${err.error}`);
            }
        } catch (e) {
            console.error(e);
            alert('Error force closing trip');
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
                        <div className="flex justify-between items-center mb-2">
                            <p className="font-bold capitalize">{area.replace('_', ' ')}</p>
                            {item.hasDamage && (
                                <span className="bg-red-100 text-red-700 text-[10px] font-bold px-2 py-0.5 rounded-full border border-red-200">
                                    DAMAGE FOUND
                                </span>
                            )}
                        </div>
                        <div className="grid grid-cols-2 gap-2">
                            {item.photoUrls?.map((url, i) => (
                                // eslint-disable-next-line @next/next/no-img-element
                                <img key={i} src={url} alt={area} className="w-full h-32 object-cover rounded cursor-pointer" onClick={() => window.open(url, '_blank')} />
                            ))}
                        </div>
                        <p className="text-sm mt-2 text-gray-700">{item.notes || 'No notes provided.'}</p>
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
        <div className="flex flex-col h-[calc(100vh-100px)] overflow-y-auto pb-6">
            <div className="flex items-center gap-4 mb-4 shrink-0">
                <Button variant="ghost" size="icon" onClick={() => router.push('/dashboard/claims')}>
                    <ArrowLeft className="w-5 h-5" />
                </Button>
                <div className="flex items-center gap-4">
                    <h1 className="text-2xl font-bold">Review Claim #{claim.claimId.slice(0,8)}</h1>
                    <p className="text-muted-foreground text-sm">Booking ID: {claim.bookingId}</p>
                    {(claim.status === 'decided' || isResolved) && (
                        <Button 
                            variant="outline" 
                            size="sm" 
                            className="bg-blue-50 border-blue-200 text-blue-700 hover:bg-blue-100"
                            onClick={handleDownloadReport}
                            disabled={processing === 'report'}
                        >
                            <FileDown className="w-4 h-4 mr-2" />
                            {processing === 'report' ? 'Generating...' : 'Download Report'}
                        </Button>
                    )}
                </div>
                {claim.status === 'decided' && (
                    <div className="ml-auto flex items-center gap-4 bg-blue-50 border border-blue-200 px-4 py-2 rounded-lg">
                        <span className="text-blue-800 font-bold text-sm uppercase">
                            DECISION POSTED
                        </span>
                        <Button variant="destructive" size="sm" onClick={handleForceCloseClick} disabled={!!processing}>
                            FORCE CLOSE TRIP
                        </Button>
                    </div>
                )}
                {isResolved && (
                    <span className="ml-auto bg-green-100 text-green-800 font-bold px-3 py-1 rounded-full text-sm">
                        RESOLVED ({claim.resolvedInFavorOf?.toUpperCase()})
                    </span>
                )}
            </div>

            <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-4 min-h-[500px]">
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

            {/* Bottom Panels Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4 shrink-0">

            {/* AI Recommendation Panel */}
            <div className="h-full bg-gradient-to-r from-indigo-50 to-purple-50 border border-purple-200 rounded-lg p-5 flex flex-col">
                <div className="flex justify-between items-center">
                    <div className="flex items-center gap-2">
                        <div className="p-2 bg-purple-100 text-purple-700 rounded-full">
                            <Sparkles className="w-5 h-5" />
                        </div>
                        <h3 className="font-bold text-lg text-purple-900">AI Assistant</h3>
                    </div>
                    {aiStatus === 'idle' && (
                        <Button 
                            className="bg-purple-600 hover:bg-purple-700 text-white" 
                            onClick={analyzeWithAI}
                        >
                            Analyze Claim with AI
                        </Button>
                    )}
                </div>

                {aiStatus === 'analyzing' && (
                    <div className="mt-4 flex items-center justify-center gap-3 py-6">
                        <Loader2 className="w-6 h-6 animate-spin text-purple-600" />
                        <span className="text-purple-700 font-medium animate-pulse">
                            AI is analyzing inspections, host notes, and chat history...
                        </span>
                    </div>
                )}

                {aiStatus === 'error' && (
                    <div className="mt-4 bg-red-50 text-red-700 p-3 rounded border border-red-200">
                        Failed to generate AI recommendation. Please try again or resolve manually.
                        <Button variant="outline" size="sm" className="ml-4" onClick={analyzeWithAI}>Retry</Button>
                    </div>
                )}

                {aiStatus === 'complete' && aiResult && (
                    <div className="mt-4 bg-white rounded-lg p-4 border border-purple-100 shadow-sm">
                        <div className="flex gap-4">
                            <div className="flex-1">
                                <p className="text-xs font-bold text-gray-500 uppercase mb-1">Reasoning</p>
                                <p className="text-sm text-gray-800 leading-relaxed whitespace-pre-wrap">
                                    {aiResult.reasoning}
                                </p>
                            </div>
                            <div className="w-1/3 bg-purple-50 rounded-md p-3 border border-purple-100 flex flex-col justify-center items-center text-center">
                                <p className="text-xs font-bold text-gray-500 uppercase mb-1">Suggested Outcome</p>
                                <div className="text-lg font-bold text-purple-900 uppercase">
                                    {aiResult.recommendation === 'host' ? 'Side with Host' : 
                                     aiResult.recommendation === 'renter' ? 'Side with Renter' : 
                                     aiResult.recommendation === 'split' ? 'Split Deduction' : 'Extra Charge'}
                                </div>
                                {(aiResult.recommendation === 'split' || aiResult.recommendation === 'extra') && aiResult.suggestedSplitAmount && (
                                    <div className="mt-2 text-sm font-bold bg-white px-3 py-1 rounded-full text-purple-700 border border-purple-200">
                                        PKR {aiResult.suggestedSplitAmount.toLocaleString()}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                )}
            </div>

            {/* Resolution Panel */}
            <div className="h-full bg-white border rounded-lg shadow-sm p-5 flex flex-col">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-lg uppercase">Admin Resolution</h3>
                    <div className="bg-red-50 text-red-700 px-3 py-1 rounded font-bold border border-red-200">
                        Host Claimed Deduction: PKR {claim.hostClaimedAmount?.toLocaleString()}
                    </div>
                </div>

                {claim.description && (
                    <div className="mb-6 p-4 bg-gray-50 border rounded-lg">
                        <p className="text-xs font-bold text-gray-500 uppercase mb-1">Host Description of Damage</p>
                        <p className="text-sm text-gray-800 italic">&quot;{claim.description}&quot;</p>
                    </div>
                )}

                {isResolved ? (
                    <div className="bg-green-50 border border-green-200 rounded p-4 text-green-800">
                        <p className="font-bold mb-1">Decision Finalized</p>
                        <p className="text-sm">Admin ruled: <strong>{claim.resolvedInFavorOf?.toUpperCase()}</strong></p>
                        <p className="text-sm mt-2">Awaiting cash confirmation from both parties in the mobile app.</p>
                    </div>
                ) : claim.status === 'decided' ? (
                    <div className="space-y-4">
                        {/* Decision summary */}
                        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                            <p className="font-bold text-blue-900 mb-1">Decision Posted</p>
                            <p className="text-sm text-blue-800">
                                Admin ruled: <strong className="uppercase">{claim.adminDecision || claim.resolvedInFavorOf}</strong>
                                {claim.finalDeductionAmount ? ` — PKR ${claim.finalDeductionAmount.toLocaleString()}` : ''}
                                {claim.requiresExtraPayment ? ` + PKR ${claim.extraChargeAmount?.toLocaleString()} extra` : ''}
                            </p>
                        </div>
                        {/* Real-time confirmation tracker */}
                        <div className="border border-gray-200 rounded-lg p-4 bg-white">
                            <p className="font-bold text-gray-800 mb-3 text-sm uppercase">Cash Settlement Confirmations</p>
                            <div className="space-y-2">
                                <div className="flex items-center justify-between">
                                    <span className="text-sm text-gray-700">Host confirmed:</span>
                                    {claim.hostConfirmed
                                        ? <span className="text-green-600 font-bold text-sm">✅ Confirmed</span>
                                        : <span className="text-amber-600 font-bold text-sm">❌ Pending</span>}
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-sm text-gray-700">Renter confirmed:</span>
                                    {claim.renterConfirmed
                                        ? <span className="text-green-600 font-bold text-sm">✅ Confirmed</span>
                                        : <span className="text-amber-600 font-bold text-sm">❌ Pending</span>}
                                </div>
                            </div>
                            <p className="text-xs text-gray-500 mt-3">Trip closes automatically when both parties confirm in the mobile app.</p>
                        </div>
                        {/* Admin force close */}
                        <div className="flex justify-end">
                            <Button variant="destructive" size="sm" onClick={handleForceCloseClick} disabled={!!processing}>
                                {processing === 'force-close' ? 'Closing...' : '⚡ Force Close Trip'}
                            </Button>
                        </div>
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
                                <Button className="flex-1 bg-teal-600 hover:bg-teal-700 h-10" onClick={() => handleResolveClick('renter')} disabled={!!processing}>
                                    <XCircle className="w-4 h-4 mr-2"/> SIDE WITH RENTER
                                </Button>
                                <Button className="flex-1 bg-red-600 hover:bg-red-700 h-10" onClick={() => handleResolveClick('host')} disabled={!!processing}>
                                    <CheckCircle className="w-4 h-4 mr-2"/> SIDE WITH HOST
                                </Button>
                            </div>
                            <div className="flex gap-2 items-center bg-purple-50 p-1.5 rounded border border-purple-200">
                                <span className="text-[10px] font-bold text-purple-900 uppercase px-1">Split</span>
                                <input 
                                    type="number" 
                                    className="border rounded px-2 py-1 w-24 text-sm" 
                                    placeholder="Amount"
                                    value={customSplit}
                                    onChange={e => setCustomSplit(e.target.value)}
                                />
                                <Button className="flex-1 bg-purple-600 hover:bg-purple-700 h-8 text-xs" onClick={() => handleResolveClick('split')} disabled={!!processing}>
                                    <Handshake className="w-3 h-3 mr-1"/> APPLY SPLIT
                                </Button>
                            </div>
                            <div className="flex gap-2 items-center bg-orange-50 p-1.5 rounded border border-orange-200">
                                <span className="text-[10px] font-bold text-orange-900 uppercase px-1">Extra</span>
                                <input 
                                    type="number" 
                                    className="border rounded px-2 py-1 w-24 text-sm" 
                                    placeholder="Amount"
                                    value={extraAmount}
                                    onChange={e => setExtraAmount(e.target.value)}
                                />
                                <Button className="flex-1 bg-orange-600 hover:bg-orange-700 h-8 text-xs" onClick={() => handleResolveClick('extra')} disabled={!!processing}>
                                    APPLY EXTRA CHARGE
                                </Button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
            </div>

            {/* Custom Confirmation Dialog */}
            <Dialog open={confirmModal.isOpen} onOpenChange={(isOpen) => setConfirmModal(prev => ({ ...prev, isOpen }))}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Confirm Action</DialogTitle>
                        <DialogDescription className="pt-4 pb-2 text-base text-gray-800 font-medium">
                            {confirmModal.message}
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter className="mt-6">
                        <Button variant="outline" onClick={() => setConfirmModal(prev => ({ ...prev, isOpen: false }))}>
                            Cancel
                        </Button>
                        <Button 
                            variant={confirmModal.type === 'force-close' ? 'destructive' : 'default'}
                            onClick={() => {
                                if (confirmModal.type === 'force-close') executeForceClose();
                                else executeResolve();
                            }}
                            disabled={!!processing}
                        >
                            {processing ? 'Processing...' : 'Yes, Confirm'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}
