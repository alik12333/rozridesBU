'use client';

import { useState, useEffect } from 'react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Eye, CheckCircle, XCircle, Handshake } from 'lucide-react';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';

interface DamageClaim {
    id: string;
    bookingId: string;
    carId: string;
    renterName: string;
    hostName: string;
    renterId: string;
    hostId: string;
    description: string;
    hostClaimedDeduction: number;
    renterAgreedDeduction: number;
    status: string;
    adminNotes: string | null;
    mutualAmount: number | null;
    preInspectionRef: string;
    postInspectionRef: string;
    resolvedAt: string | null;
    createdAt: string;
}

export default function ClaimsPage() {
    const [claims, setClaims] = useState<DamageClaim[]>([]);
    const [loading, setLoading] = useState(true);
    const [selected, setSelected] = useState<DamageClaim | null>(null);
    const [processing, setProcessing] = useState<string | null>(null);
    const [adminNotes, setAdminNotes] = useState('');
    const [mutualAmount, setMutualAmount] = useState('');
    const [filter, setFilter] = useState('all');

    useEffect(() => {
        fetchClaims();
    }, []);

    const fetchClaims = async () => {
        try {
            const res = await fetch('/api/claims');
            const data = await res.json();
            setClaims(Array.isArray(data) ? data : []);
        } catch (error) {
            console.error('Error fetching claims:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleResolve = async (
        resolution: 'resolved_for_host' | 'resolved_for_renter' | 'resolved_mutually'
    ) => {
        if (!selected) return;
        if (resolution === 'resolved_mutually' && !mutualAmount) {
            alert('Please enter the mutual settlement amount.');
            return;
        }
        setProcessing(resolution);
        try {
            const res = await fetch(`/api/claims/${selected.id}/resolve`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    resolution,
                    adminNotes,
                    mutualAmount: mutualAmount ? parseFloat(mutualAmount) : undefined,
                }),
            });
            if (res.ok) {
                await fetchClaims();
                setSelected(prev =>
                    prev ? { ...prev, status: resolution } : null
                );
            } else {
                alert('Failed to resolve claim.');
            }
        } catch (error) {
            console.error('Error resolving:', error);
        } finally {
            setProcessing(null);
        }
    };

    const getStatusBadge = (status: string) => {
        const map: Record<string, string> = {
            open: 'bg-orange-100 text-orange-700 border-orange-200',
            admin_reviewing: 'bg-blue-100 text-blue-700 border-blue-200',
            resolved_for_host: 'bg-green-100 text-green-700 border-green-200',
            resolved_for_renter: 'bg-teal-100 text-teal-700 border-teal-200',
            resolved_mutually: 'bg-purple-100 text-purple-700 border-purple-200',
        };
        const label: Record<string, string> = {
            open: 'Open',
            admin_reviewing: 'Under Review',
            resolved_for_host: 'Host Won',
            resolved_for_renter: 'Renter Won',
            resolved_mutually: 'Mutual',
        };
        return (
            <span className={`text-xs font-bold uppercase px-2 py-1 rounded-full border ${map[status] ?? 'bg-gray-100 text-gray-600'}`}>
                {label[status] ?? status}
            </span>
        );
    };

    const filtered = claims.filter(c => filter === 'all' ? true : c.status === filter);
    const isResolved = (s: string) => s.startsWith('resolved_');

    if (loading) return <div className="text-center py-8">Loading Claims...</div>;

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-4xl font-bold mb-2">Damage Claims</h1>
                <p className="text-muted-foreground">Review disputes raised by renters and issue resolutions.</p>
            </div>

            {/* Filter pills */}
            <div className="flex gap-2 flex-wrap">
                {['all', 'open', 'admin_reviewing', 'resolved_for_host', 'resolved_for_renter', 'resolved_mutually'].map(f => (
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
                            <TableHead>Booking</TableHead>
                            <TableHead>Renter</TableHead>
                            <TableHead>Host</TableHead>
                            <TableHead>Host Claimed</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead>Date</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {filtered.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={8} className="text-center py-8 text-muted-foreground">
                                    No claims found.
                                </TableCell>
                            </TableRow>
                        ) : (
                            filtered.map(claim => (
                                <TableRow key={claim.id}>
                                    <TableCell className="font-mono text-xs">{claim.id.slice(0, 8)}…</TableCell>
                                    <TableCell className="font-mono text-xs">{claim.bookingId.slice(0, 8)}…</TableCell>
                                    <TableCell>{claim.renterName}</TableCell>
                                    <TableCell>{claim.hostName}</TableCell>
                                    <TableCell className="font-bold text-red-600">PKR {claim.hostClaimedDeduction.toLocaleString()}</TableCell>
                                    <TableCell>{getStatusBadge(claim.status)}</TableCell>
                                    <TableCell className="text-sm text-muted-foreground">
                                        {new Date(claim.createdAt).toLocaleDateString()}
                                    </TableCell>
                                    <TableCell className="text-right">
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => {
                                                setSelected(claim);
                                                setAdminNotes(claim.adminNotes ?? '');
                                                setMutualAmount(claim.mutualAmount?.toString() ?? '');
                                            }}
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

            {/* Detail Dialog */}
            <Dialog open={!!selected} onOpenChange={() => setSelected(null)}>
                <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle>Claim Review: {selected?.id}</DialogTitle>
                    </DialogHeader>
                    {selected && (
                        <div className="space-y-6">
                            {/* Summary Cards */}
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 bg-gray-50 dark:bg-gray-900 p-4 rounded-lg">
                                <div><p className="text-xs text-muted-foreground uppercase">Renter</p><p className="font-medium text-sm">{selected.renterName}</p></div>
                                <div><p className="text-xs text-muted-foreground uppercase">Host</p><p className="font-medium text-sm">{selected.hostName}</p></div>
                                <div><p className="text-xs text-muted-foreground uppercase">Host Claimed</p><p className="font-bold text-red-600 text-sm">PKR {selected.hostClaimedDeduction.toLocaleString()}</p></div>
                                <div><p className="text-xs text-muted-foreground uppercase">Renter Believes</p><p className="font-bold text-teal-600 text-sm">PKR {selected.renterAgreedDeduction.toLocaleString()}</p></div>
                            </div>

                            {/* Renter's Account */}
                            <div>
                                <h3 className="text-base font-bold mb-2">Renter&apos;s Account</h3>
                                <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
                                    <p className="text-sm text-gray-700 whitespace-pre-wrap">{selected.description}</p>
                                </div>
                            </div>

                            {/* Inspection References */}
                            <div>
                                <h3 className="text-base font-bold mb-2">Inspection References</h3>
                                <div className="grid grid-cols-2 gap-3 text-sm">
                                    <div className="bg-gray-50 border rounded-lg p-3">
                                        <p className="text-xs text-muted-foreground uppercase mb-1">Pre-Trip Ref</p>
                                        <p className="font-mono text-xs break-all">{selected.preInspectionRef}</p>
                                    </div>
                                    <div className="bg-gray-50 border rounded-lg p-3">
                                        <p className="text-xs text-muted-foreground uppercase mb-1">Post-Trip Ref</p>
                                        <p className="font-mono text-xs break-all">{selected.postInspectionRef}</p>
                                    </div>
                                </div>
                            </div>

                            {/* Status */}
                            <div className="flex items-center gap-2">
                                <span className="text-sm font-semibold">Current Status:</span>
                                {getStatusBadge(selected.status)}
                            </div>

                            {/* Resolution Panel */}
                            {!isResolved(selected.status) && (
                                <div className="border-t pt-6 bg-amber-50/50 dark:bg-amber-950/20 p-4 rounded-lg border-amber-100">
                                    <h3 className="text-base font-bold text-amber-800 dark:text-amber-300 mb-4">Issue Resolution</h3>

                                    <div className="space-y-4">
                                        {/* Admin notes */}
                                        <div>
                                            <label className="block text-sm font-medium mb-1">Admin Notes (optional)</label>
                                            <textarea
                                                rows={3}
                                                className="w-full text-sm rounded-md border border-gray-300 px-3 py-2"
                                                placeholder="Reasoning for this decision, evidence reviewed, etc."
                                                value={adminNotes}
                                                onChange={e => setAdminNotes(e.target.value)}
                                            />
                                        </div>

                                        {/* Mutual amount */}
                                        <div>
                                            <label className="block text-sm font-medium mb-1">Mutual Settlement Amount (PKR) — for &quot;Resolve Mutually&quot;</label>
                                            <input
                                                type="number"
                                                min="0"
                                                className="w-full md:w-48 text-sm rounded-md border border-gray-300 px-3 py-2"
                                                placeholder="e.g., 2500"
                                                value={mutualAmount}
                                                onChange={e => setMutualAmount(e.target.value)}
                                            />
                                        </div>

                                        {/* Resolution buttons */}
                                        <div className="flex flex-wrap gap-3">
                                            <Button
                                                className="bg-green-600 hover:bg-green-700 text-white"
                                                disabled={processing !== null}
                                                onClick={() => handleResolve('resolved_for_host')}
                                            >
                                                <CheckCircle className="w-4 h-4 mr-2" />
                                                {processing === 'resolved_for_host' ? 'Processing…' : 'Resolve for Host'}
                                            </Button>
                                            <Button
                                                className="bg-teal-600 hover:bg-teal-700 text-white"
                                                disabled={processing !== null}
                                                onClick={() => handleResolve('resolved_for_renter')}
                                            >
                                                <XCircle className="w-4 h-4 mr-2" />
                                                {processing === 'resolved_for_renter' ? 'Processing…' : 'Resolve for Renter'}
                                            </Button>
                                            <Button
                                                className="bg-purple-600 hover:bg-purple-700 text-white"
                                                disabled={processing !== null}
                                                onClick={() => handleResolve('resolved_mutually')}
                                            >
                                                <Handshake className="w-4 h-4 mr-2" />
                                                {processing === 'resolved_mutually' ? 'Processing…' : 'Resolve Mutually'}
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {/* Already resolved */}
                            {isResolved(selected.status) && selected.adminNotes && (
                                <div className="bg-gray-50 border rounded-lg p-4">
                                    <p className="text-xs text-muted-foreground uppercase mb-1">Admin Notes</p>
                                    <p className="text-sm text-gray-700">{selected.adminNotes}</p>
                                </div>
                            )}
                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}
