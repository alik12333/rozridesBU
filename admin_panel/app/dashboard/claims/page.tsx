'use client';

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Eye } from 'lucide-react';
import { useRouter } from 'next/navigation';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import { db } from '@/lib/firebase-client';
import { collection, onSnapshot, query, orderBy, doc, getDoc } from 'firebase/firestore';

interface DamageClaim {
    claimId: string;
    bookingId: string;
    carId: string;
    renterId: string;
    hostId: string;
    hostClaimedAmount: number;
    status: string;
    createdAt: Date;
    
    // Joined data
    carName?: string;
    renterName?: string;
    hostName?: string;
}

export default function ClaimsPage() {
    const router = useRouter();
    const [claims, setClaims] = useState<DamageClaim[]>([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');

    useEffect(() => {
        const unsubscribe = onSnapshot(
            collection(db, 'damageClaims'),
            async (snapshot) => {
                const claimsData = snapshot.docs.map(doc => ({
                    claimId: doc.id,
                    ...doc.data(),
                    createdAt: doc.data().createdAt?.toDate() || new Date(),
                })) as DamageClaim[];

                // Fetch joined data
                const enrichedClaims = await Promise.all(claimsData.map(async (claim) => {
                    let carName = 'Unknown';
                    let renterName = 'Unknown';
                    let hostName = 'Unknown';

                    try {
                        const bookingSnap = await getDoc(doc(db, 'bookings', claim.bookingId));
                        if (bookingSnap.exists()) {
                            carName = bookingSnap.data().carName || 'Unknown';
                            renterName = bookingSnap.data().renterName || 'Unknown';
                        }
                        
                        const hostSnap = await getDoc(doc(db, 'users', claim.hostId));
                        if (hostSnap.exists()) {
                            hostName = hostSnap.data().fullName || 'Unknown';
                        }
                    } catch (e) {
                        console.error('Error fetching joined data', e);
                    }

                    return {
                        ...claim,
                        carName,
                        renterName,
                        hostName
                    };
                }));

                setClaims(enrichedClaims);
                setLoading(false);
            },
            (error) => {
                console.error("Error fetching claims:", error);
                setLoading(false);
            }
        );

        return () => unsubscribe();
    }, []);

    const getStatusBadge = (status: string) => {
        const map: Record<string, string> = {
            open: 'bg-red-100 text-red-700 border-red-200',
            admin_reviewing: 'bg-orange-100 text-orange-700 border-orange-200',
            decided: 'bg-yellow-100 text-yellow-700 border-yellow-200',
            resolved: 'bg-green-100 text-green-700 border-green-200',
        };
        const label: Record<string, string> = {
            open: 'Open',
            admin_reviewing: 'Reviewing',
            decided: 'Awaiting Confirmation',
            resolved: 'Resolved',
        };
        return (
            <span className={`text-xs font-bold uppercase px-2 py-1 rounded-full border ${map[status] ?? 'bg-gray-100 text-gray-600'}`}>
                {label[status] ?? status}
            </span>
        );
    };

    // Sort order: open -> admin_reviewing -> decided -> resolved
    const statusOrder: Record<string, number> = {
        'open': 1,
        'admin_reviewing': 2,
        'decided': 3,
        'resolved': 4,
    };

    const sortedClaims = [...claims].sort((a, b) => {
        const orderA = statusOrder[a.status] || 99;
        const orderB = statusOrder[b.status] || 99;
        if (orderA !== orderB) return orderA - orderB;
        return b.createdAt.getTime() - a.createdAt.getTime();
    });

    const filtered = sortedClaims.filter(c => filter === 'all' ? true : c.status === filter);

    if (loading) return <div className="text-center py-8">Loading Claims...</div>;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-4xl font-bold mb-2">Damage Claims</h1>
                <p className="text-muted-foreground">Review disputes raised by renters and issue resolutions.</p>
            </div>

            {/* Filter pills */}
            <div className="flex gap-2 flex-wrap">
                {['all', 'open', 'admin_reviewing', 'decided', 'resolved'].map(f => (
                    <Button
                        key={f}
                        variant={filter === f ? 'default' : 'outline'}
                        onClick={() => setFilter(f)}
                        size="sm"
                        className="capitalize text-xs"
                    >
                        {f.replace(/_/g, ' ')} ({f === 'all' ? claims.length : claims.filter(c => c.status === f).length})
                    </Button>
                ))}
            </div>

            <div className="border rounded-md bg-white dark:bg-gray-800">
                <Table>
                    <TableHeader>
                        <TableRow>
                            <TableHead>Claim ID</TableHead>
                            <TableHead>Car Name</TableHead>
                            <TableHead>Renter</TableHead>
                            <TableHead>Host</TableHead>
                            <TableHead>Host Claimed</TableHead>
                            <TableHead>Date Flagged</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {filtered.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={8} className="text-center py-8 text-muted-foreground">
                                    No open disputes. The platform is running smoothly.
                                </TableCell>
                            </TableRow>
                        ) : (
                            filtered.map(claim => (
                                <TableRow key={claim.claimId}>
                                    <TableCell className="font-mono text-xs">{claim.claimId.slice(0, 8)}</TableCell>
                                    <TableCell>{claim.carName}</TableCell>
                                    <TableCell>{claim.renterName}</TableCell>
                                    <TableCell>{claim.hostName}</TableCell>
                                    <TableCell className="font-bold text-red-600">PKR {claim.hostClaimedAmount?.toLocaleString()}</TableCell>
                                    <TableCell className="text-sm text-muted-foreground">
                                        {claim.createdAt.toLocaleDateString()}
                                    </TableCell>
                                    <TableCell>{getStatusBadge(claim.status)}</TableCell>
                                    <TableCell className="text-right">
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => router.push(`/dashboard/claims/${claim.claimId}`)}
                                        >
                                            <Eye className="w-4 h-4 mr-2" />
                                            Review
                                        </Button>
                                    </TableCell>
                                </TableRow>
                            ))
                        )}
                    </TableBody>
                </Table>
            </div>
        </div>
    );
}
