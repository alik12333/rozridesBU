'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { CheckCircle, XCircle, Eye } from 'lucide-react';
import Image from 'next/image';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';

interface Listing {
    id: string;
    ownerName: string;
    carName: string;
    carNumber?: string;
    brand: string;
    model: string;
    year: number;
    pricePerDay: number;
    images: string[];
    status: string;
    transmission: string;
    fuelType: string;
    withDriver: boolean;
}

export default function ListingsPage() {
    const [listings, setListings] = useState<Listing[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedListing, setSelectedListing] = useState<Listing | null>(null);
    const [processing, setProcessing] = useState<string | null>(null);
    const [filter, setFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('pending');

    useEffect(() => {
        fetchListings();
    }, []);

    const fetchListings = async () => {
        try {
            const res = await fetch('/api/listings');
            const data = await res.json();
            setListings(data);
        } catch (error) {
            console.error('Error fetching listings:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleApprove = async (listingId: string) => {
        setProcessing(listingId);
        try {
            const res = await fetch(`/api/listings/${listingId}/approve`, { method: 'POST' });
            if (res.ok) {
                await fetchListings();
                setSelectedListing(null);
            }
        } catch (error) {
            console.error('Error approving listing:', error);
        } finally {
            setProcessing(null);
        }
    };

    const handleReject = async (listingId: string) => {
        setProcessing(listingId);
        try {
            const res = await fetch(`/api/listings/${listingId}/reject`, { method: 'POST' });
            if (res.ok) {
                await fetchListings();
                setSelectedListing(null);
            }
        } catch (error) {
            console.error('Error rejecting listing:', error);
        } finally {
            setProcessing(null);
        }
    };

    const getStatusBadge = (status: string) => {
        const variants: Record<string, any> = {
            approved: 'success',
            pending: 'warning',
            rejected: 'destructive',
        };
        return <Badge variant={variants[status]}>{status.toUpperCase()}</Badge>;
    };

    const filteredListings = listings.filter((listing) =>
        filter === 'all' ? true : listing.status === filter
    );

    if (loading) {
        return <div className="text-center py-8">Loading...</div>;
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-4xl font-bold mb-2">Car Listings</h1>
                    <p className="text-muted-foreground">Manage and approve car listings</p>
                </div>
                <div className="flex gap-2">
                    <Button
                        variant={filter === 'all' ? 'default' : 'outline'}
                        onClick={() => setFilter('all')}
                    >
                        All ({listings.length})
                    </Button>
                    <Button
                        variant={filter === 'pending' ? 'default' : 'outline'}
                        onClick={() => setFilter('pending')}
                    >
                        Pending ({listings.filter((l) => l.status === 'pending').length})
                    </Button>
                    <Button
                        variant={filter === 'approved' ? 'default' : 'outline'}
                        onClick={() => setFilter('approved')}
                    >
                        Approved ({listings.filter((l) => l.status === 'approved').length})
                    </Button>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {filteredListings.length === 0 ? (
                    <p className="text-muted-foreground col-span-full text-center py-8">
                        No listings found
                    </p>
                ) : (
                    filteredListings.map((listing) => (
                        <Card key={listing.id} className="overflow-hidden hover:shadow-lg transition-shadow">
                            <div className="relative h-48 bg-gray-100">
                                {listing.images[0] && (
                                    <Image
                                        src={listing.images[0]}
                                        alt={listing.carName}
                                        fill
                                        className="object-cover"
                                    />
                                )}
                                <div className="absolute top-2 right-2">
                                    {getStatusBadge(listing.status)}
                                </div>
                            </div>
                            <CardHeader className="pb-3">
                                <CardTitle className="text-lg">{listing.carName}</CardTitle>
                                <p className="text-sm text-muted-foreground">
                                    {listing.brand} {listing.model} ({listing.year})
                                </p>
                            </CardHeader>
                            <CardContent className="space-y-3">
                                <div className="flex items-center justify-between text-sm">
                                    <span className="text-muted-foreground">Owner:</span>
                                    <span className="font-medium">{listing.ownerName}</span>
                                </div>
                                <div className="flex items-center justify-between text-sm">
                                    <span className="text-muted-foreground">Price:</span>
                                    <span className="font-bold text-primary">Rs. {listing.pricePerDay}/day</span>
                                </div>
                                <div className="flex gap-2 text-xs">
                                    <Badge variant="outline">{listing.transmission}</Badge>
                                    <Badge variant="outline">{listing.fuelType}</Badge>
                                    {listing.withDriver && <Badge variant="outline">With Driver</Badge>}
                                </div>
                                <div className="flex gap-2 pt-2">
                                    <Button
                                        size="sm"
                                        variant="outline"
                                        className="flex-1"
                                        onClick={() => setSelectedListing(listing)}
                                    >
                                        <Eye className="w-4 h-4 mr-1" />
                                        View
                                    </Button>
                                    {listing.status === 'pending' && (
                                        <>
                                            <Button
                                                size="sm"
                                                onClick={() => handleApprove(listing.id)}
                                                disabled={processing === listing.id}
                                            >
                                                <CheckCircle className="w-4 h-4" />
                                            </Button>
                                            <Button
                                                size="sm"
                                                variant="destructive"
                                                onClick={() => handleReject(listing.id)}
                                                disabled={processing === listing.id}
                                            >
                                                <XCircle className="w-4 h-4" />
                                            </Button>
                                        </>
                                    )}
                                </div>
                            </CardContent>
                        </Card>
                    ))
                )}
            </div>

            {/* Listing Details Dialog */}
            <Dialog open={!!selectedListing} onOpenChange={() => setSelectedListing(null)}>
                <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle>{selectedListing?.carName}</DialogTitle>
                    </DialogHeader>
                    {selectedListing && (
                        <div className="space-y-4">
                            {/* Images */}
                            <div className="grid grid-cols-2 gap-2">
                                {selectedListing.images.map((img, idx) => (
                                    <div key={idx} className="relative h-48 bg-gray-100 rounded">
                                        <Image src={img} alt={`Image ${idx + 1}`} fill className="object-cover rounded" />
                                    </div>
                                ))}
                            </div>
                            {/* Details */}
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <p className="text-sm text-muted-foreground">Owner</p>
                                    <p className="font-medium">{selectedListing.ownerName}</p>
                                </div>
                                <div>
                                    <p className="text-sm text-muted-foreground">Price per Day</p>
                                    <p className="font-medium">Rs. {selectedListing.pricePerDay}</p>
                                </div>
                                <div>
                                    <p className="text-sm text-muted-foreground">Status</p>
                                    {getStatusBadge(selectedListing.status)}
                                </div>
                                {selectedListing.carNumber && (
                                    <div className="col-span-full">
                                        <p className="text-sm text-muted-foreground">Car Number (Private)</p>
                                        <Badge variant="secondary" className="text-lg font-mono">
                                            {selectedListing.carNumber}
                                        </Badge>
                                    </div>
                                )}
                            </div>
                            {selectedListing.status === 'pending' && (
                                <div className="flex gap-2 pt-4">
                                    <Button
                                        className="flex-1"
                                        onClick={() => handleApprove(selectedListing.id)}
                                        disabled={processing === selectedListing.id}
                                    >
                                        <CheckCircle className="w-4 h-4 mr-2" />
                                        Approve Listing
                                    </Button>
                                    <Button
                                        variant="destructive"
                                        className="flex-1"
                                        onClick={() => handleReject(selectedListing.id)}
                                        disabled={processing === selectedListing.id}
                                    >
                                        <XCircle className="w-4 h-4 mr-2" />
                                        Reject Listing
                                    </Button>
                                </div>
                            )}
                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}
