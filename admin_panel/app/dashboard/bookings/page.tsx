'use client';

import { useState, useEffect } from 'react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Eye, ShieldAlert, XCircle, FileDown } from 'lucide-react';
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

interface BookingTimelineEvent {
    id: string;
    status: string;
    note: string;
    triggeredBy: string;
    timestamp: string;
}

interface Booking {
    id: string;
    carName: string;
    renterName: string;
    hostName?: string;
    startDate: string;
    endDate: string;
    totalAmount: number;
    status: string;
    cancellationReason?: string;
    declineReason?: string;
}

export default function BookingsPage() {
    const [bookings, setBookings] = [...useState<Booking[]>([])];
    const [loading, setLoading] = useState(true);
    const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
    const [timeline, setTimeline] = useState<BookingTimelineEvent[]>([]);
    const [timelineLoading, setTimelineLoading] = useState(false);
    const [processing, setProcessing] = useState<string | null>(null);
    const [filter, setFilter] = useState<string>('all');
    const [forceCancelReason, setForceCancelReason] = useState('');

    useEffect(() => {
        fetchBookings();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const fetchBookings = async () => {
        try {
            const res = await fetch('/api/bookings');
            const data = await res.json();
            setBookings(data);
        } catch (error) {
            console.error('Error fetching bookings:', error);
        } finally {
            setLoading(false);
        }
    };

    const fetchTimeline = async (bookingId: string) => {
        setTimelineLoading(true);
        try {
            const res = await fetch(`/api/bookings/${bookingId}/timeline`);
            const data = await res.json();
            setTimeline(data);
        } catch (error) {
            console.error('Error fetching timeline:', error);
        } finally {
            setTimelineLoading(false);
        }
    };

    const handleViewBooking = (booking: Booking) => {
        setSelectedBooking(booking);
        fetchTimeline(booking.id);
        setForceCancelReason('');
    };

    const handleForceCancel = async (bookingId: string) => {
        if (!forceCancelReason.trim()) {
            alert('Please provide a reason for force cancellation.');
            return;
        }

        if (!confirm('Are you strictly sure you want to force cancel this booking? This bypasses standard protocols and alerts both parties.')) {
            return;
        }

        setProcessing('cancel');
        try {
            const res = await fetch(`/api/bookings/${bookingId}/force-cancel`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason: forceCancelReason }),
            });
            if (res.ok) {
                await fetchBookings();
                await fetchTimeline(bookingId);
                setForceCancelReason('');
                setSelectedBooking(prev => prev ? { ...prev, status: 'cancelled' } : null);
            } else {
                alert('Failed to force cancel');
            }
        } catch (error) {
            console.error('Error force cancelling:', error);
        } finally {
            setProcessing(null);
        }
    };

    const handleMarkDisputed = async (bookingId: string) => {
        if (!confirm('Mark this booking as disputed for administrative review?')) return;

        setProcessing('dispute');
        try {
            const res = await fetch(`/api/bookings/${bookingId}/dispute`, { method: 'POST' });
            if (res.ok) {
                await fetchBookings();
                await fetchTimeline(bookingId);
                setSelectedBooking(prev => prev ? { ...prev, status: 'disputed' } : null);
            } else {
                alert('Failed to mark disputed');
            }
        } catch (error) {
            console.error('Error marking disputed:', error);
        } finally {
            setProcessing(null);
        }
    };

    const handleDownloadReport = async (bookingId: string) => {
        setProcessing('report');
        try {
            const res = await fetch(`/api/bookings/${bookingId}/report`);
            if (res.ok) {
                const blob = await res.blob();
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `RozRides_Report_${bookingId.substring(0, 8)}.pdf`;
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

    const getStatusBadge = (status: string) => {
        let variant: 'default' | 'success' | 'destructive' | 'warning' | 'outline' = 'outline';
        
        // Define styling mapping
        if (status === 'confirmed' || status === 'completed') variant = 'success';
        if (status === 'pending' || status === 'active') variant = 'warning';
        if (status === 'rejected' || status === 'expired' || status === 'cancelled') variant = 'destructive';
        if (status === 'disputed') return <Badge className="bg-orange-500 hover:bg-orange-600 font-bold uppercase">{status}</Badge>;

        return <Badge variant={variant as "success" | "warning" | "destructive" | "default" | "outline"} className="uppercase">{status}</Badge>;
    };

    const filteredBookings = bookings.filter((booking) =>
        filter === 'all' ? true : booking.status === filter
    );

    if (loading) {
        return <div className="text-center py-8">Loading Bookings Oversight...</div>;
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-4xl font-bold mb-2">Bookings Oversight</h1>
                    <p className="text-muted-foreground">Monitor transactions, audit timelines, and resolve disputes.</p>
                </div>
            </div>

            <div className="flex gap-2 flex-wrap">
                {['all', 'pending', 'confirmed', 'active', 'completed', 'disputed', 'cancelled'].map(f => (
                    <Button
                        key={f}
                        variant={filter === f ? 'default' : 'outline'}
                        onClick={() => setFilter(f)}
                        size="sm"
                        className="capitalize"
                    >
                        {f} ({f === 'all' ? bookings.length : bookings.filter(b => b.status === f).length})
                    </Button>
                ))}
            </div>

            <div className="border rounded-md bg-white dark:bg-gray-800">
                <Table>
                    <TableHeader>
                        <TableRow>
                            <TableHead>Booking ID</TableHead>
                            <TableHead>Car</TableHead>
                            <TableHead>Renter</TableHead>
                            <TableHead>Dates</TableHead>
                            <TableHead>Amount (PKR)</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {filteredBookings.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                                    No bookings found in this view.
                                </TableCell>
                            </TableRow>
                        ) : (
                            filteredBookings.map((booking) => (
                                <TableRow key={booking.id}>
                                    <TableCell className="font-mono text-xs">{booking.id.slice(0, 8)}...</TableCell>
                                    <TableCell className="font-medium">{booking.carName}</TableCell>
                                    <TableCell>{booking.renterName}</TableCell>
                                    <TableCell className="text-sm">
                                        {new Date(booking.startDate).toLocaleDateString()} - <br/>
                                        {new Date(booking.endDate).toLocaleDateString()}
                                    </TableCell>
                                    <TableCell className="font-bold">Rs. {booking.totalAmount}</TableCell>
                                    <TableCell>{getStatusBadge(booking.status)}</TableCell>
                                    <TableCell className="text-right">
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => handleViewBooking(booking)}
                                        >
                                            <Eye className="w-4 h-4 mr-2" />
                                            Audit
                                        </Button>
                                    </TableCell>
                                </TableRow>
                            ))
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Booking Details & Timeline Dialog */}
            <Dialog open={!!selectedBooking} onOpenChange={() => setSelectedBooking(null)}>
                <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle>Booking Audit: {selectedBooking?.id}</DialogTitle>
                    </DialogHeader>
                    {selectedBooking && (
                        <div className="space-y-6">
                            
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 bg-gray-50 dark:bg-gray-900 p-4 rounded-lg">
                                <div>
                                    <p className="text-xs text-muted-foreground uppercase">Car Target</p>
                                    <p className="font-medium text-sm">{selectedBooking.carName}</p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground uppercase">Renter Account</p>
                                    <p className="font-medium text-sm">{selectedBooking.renterName}</p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground uppercase">Total Pay</p>
                                    <p className="font-bold text-primary text-sm">Rs. {selectedBooking.totalAmount}</p>
                                </div>
                                <div>
                                    <p className="text-xs text-muted-foreground uppercase">Current State</p>
                                    <div className="mt-1">{getStatusBadge(selectedBooking.status)}</div>
                                </div>
                            </div>

                            {selectedBooking.status === 'completed' && (
                                <div className="flex justify-end">
                                    <Button
                                        variant="outline"
                                        className="bg-blue-50 border-blue-200 hover:bg-blue-100 text-blue-700"
                                        onClick={() => handleDownloadReport(selectedBooking.id)}
                                        disabled={processing !== null}
                                    >
                                        <FileDown className="w-4 h-4 mr-2" />
                                        {processing === 'report' ? 'Generating...' : 'Download Trip Report'}
                                    </Button>
                                </div>
                            )}

                            {/* Timeline Feed */}
                            <div>
                                <h3 className="text-lg font-bold mb-4">Immutable Timeline Audit Log</h3>
                                {timelineLoading ? (
                                    <p className="text-sm text-muted-foreground py-4">Fetching audit trails...</p>
                                ) : timeline.length === 0 ? (
                                    <p className="text-sm text-yellow-600 bg-yellow-50 p-4 rounded border border-yellow-200">
                                        No timeline events were found. (Bookings made before Module 1.4 will not have audit trails).
                                    </p>
                                ) : (
                                    <div className="space-y-4">
                                        {timeline.map((event) => (
                                            <div key={event.id} className="relative pl-6 pb-4 border-l-2 border-gray-200 dark:border-gray-700 last:border-0 last:pb-0">
                                                <div className="absolute -left-1.5 top-1.5 w-3 h-3 bg-primary rounded-full" />
                                                <div className="bg-white dark:bg-gray-800 border rounded-lg p-3 shadow-sm">
                                                    <div className="flex justify-between items-start mb-1">
                                                        <div className="flex items-center gap-2">
                                                            {getStatusBadge(event.status)}
                                                            <span className="text-xs font-medium text-muted-foreground uppercase mx-2">
                                                                Trigger: {event.triggeredBy === 'system' ? 'SYSTEM' : 'USER'}
                                                            </span>
                                                        </div>
                                                        <span className="text-xs text-muted-foreground">
                                                            {new Date(event.timestamp).toLocaleString()}
                                                        </span>
                                                    </div>
                                                    <p className="text-sm font-medium mt-2 text-gray-800 dark:text-gray-200">
                                                        {event.note}
                                                    </p>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {/* Admin Overrides */}
                            <div className="border-t pt-6 bg-red-50/50 dark:bg-red-950/20 p-4 rounded-lg border-red-100 dark:border-red-900 mt-6">
                                <h3 className="text-lg font-bold text-red-700 dark:text-red-400 mb-2 flex items-center">
                                    <ShieldAlert className="w-5 h-5 mr-2" />
                                    Administrative Override
                                </h3>
                                <p className="text-sm text-muted-foreground mb-4">
                                    Executing these commands bypasses standard restrictions and applies directly to the transaction.
                                </p>

                                <div className="space-y-4">
                                    {selectedBooking.status !== 'cancelled' && selectedBooking.status !== 'disputed' && (
                                        <div className="flex gap-2">
                                            <Button
                                                variant="outline"
                                                className="border-orange-200 hover:bg-orange-50 text-orange-700"
                                                onClick={() => handleMarkDisputed(selectedBooking.id)}
                                                disabled={processing !== null}
                                            >
                                                Mark as Disputed
                                            </Button>
                                        </div>
                                    )}

                                    {selectedBooking.status !== 'cancelled' && selectedBooking.status !== 'completed' && (
                                        <div className="flex flex-col md:flex-row gap-2">
                                            <input
                                                type="text"
                                                placeholder="Provide mandatory reason for force cancellation..."
                                                value={forceCancelReason}
                                                onChange={(e) => setForceCancelReason(e.target.value)}
                                                className="flex-1 text-sm rounded-md border border-gray-300 px-3 py-2"
                                            />
                                            <Button
                                                variant="destructive"
                                                onClick={() => handleForceCancel(selectedBooking.id)}
                                                disabled={processing !== null || !forceCancelReason.trim()}
                                            >
                                                <XCircle className="w-4 h-4 mr-2" />
                                                Force Cancel Booking
                                            </Button>
                                        </div>
                                    )}
                                </div>
                            </div>

                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}

