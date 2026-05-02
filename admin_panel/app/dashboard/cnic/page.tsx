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

interface CNICData {
    id: string;
    fullName: string;
    email: string;
    cnic: {
        number: string;
        frontImage?: string;
        backImage?: string;
        verificationStatus: string;
    };
}

export default function CNICPage() {
    const [cnicData, setCnicData] = useState<CNICData[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedImage, setSelectedImage] = useState<string | null>(null);
    const [processing, setProcessing] = useState<string | null>(null);

    useEffect(() => {
        fetchCNICData();
    }, []);

    const fetchCNICData = async () => {
        try {
            const res = await fetch('/api/cnic');
            const data = await res.json();
            setCnicData(data);
        } catch (error) {
            console.error('Error fetching CNIC data:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleApprove = async (userId: string) => {
        setProcessing(userId);
        try {
            const res = await fetch(`/api/cnic/${userId}/approve`, { method: 'POST' });
            if (res.ok) {
                await fetchCNICData();
            } else {
                const data = await res.json();
                alert(`Failed to approve: ${data.error} \nDetails: ${data.details || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Error approving CNIC:', error);
            alert(`Network error approving CNIC: ${error}`);
        } finally {
            setProcessing(null);
        }
    };

    const handleReject = async (userId: string) => {
        setProcessing(userId);
        try {
            const res = await fetch(`/api/cnic/${userId}/reject`, { method: 'POST' });
            if (res.ok) {
                await fetchCNICData();
            } else {
                const data = await res.json();
                alert(`Failed to reject: ${data.error} \nDetails: ${data.details || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Error rejecting CNIC:', error);
            alert(`Network error rejecting CNIC: ${error}`);
        } finally {
            setProcessing(null);
        }
    };

    const getStatusBadge = (status: string) => {
        const variants: Record<string, "success" | "warning" | "destructive" | "default"> = {
            approved: 'success',
            pending: 'warning',
            rejected: 'destructive',
        };
        return <Badge variant={variants[status] || 'default'}>{status.toUpperCase()}</Badge>;
    };

    if (loading) {
        return <div className="text-center py-8">Loading...</div>;
    }

    const pendingCNICs = cnicData.filter((c) => c.cnic.verificationStatus === 'pending');
    const approvedCNICs = cnicData.filter((c) => c.cnic.verificationStatus === 'approved');
    // rejectedCNICs defined but never used, so we omit it here unless needed for UI


    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-4xl font-bold mb-2">CNIC Verification</h1>
                <p className="text-muted-foreground">Review and verify user CNIC documents</p>
            </div>

            {/* Pending CNICs */}
            <Card>
                <CardHeader>
                    <CardTitle>Pending Verification ({pendingCNICs.length})</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {pendingCNICs.length === 0 ? (
                            <p className="text-muted-foreground col-span-full text-center py-8">
                                No pending CNIC verifications
                            </p>
                        ) : (
                            pendingCNICs.map((item) => (
                                <Card key={item.id} className="overflow-hidden">
                                    <CardHeader className="pb-3">
                                        <div className="flex items-start justify-between">
                                            <div>
                                                <h3 className="font-semibold">{item.fullName}</h3>
                                                <p className="text-sm text-muted-foreground">{item.cnic.number}</p>
                                            </div>
                                            {getStatusBadge(item.cnic.verificationStatus)}
                                        </div>
                                    </CardHeader>
                                    <CardContent className="space-y-3">
                                        <div className="grid grid-cols-2 gap-2">
                                            {item.cnic.frontImage && (
                                                <div
                                                    className="relative h-24 bg-gray-100 rounded cursor-pointer hover:opacity-80"
                                                    onClick={() => setSelectedImage(item.cnic.frontImage!)}
                                                >
                                                    <Image
                                                        src={item.cnic.frontImage}
                                                        alt="CNIC Front"
                                                        fill
                                                        className="object-cover rounded"
                                                    />
                                                    <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 hover:opacity-100 transition-opacity">
                                                        <Eye className="w-6 h-6 text-white" />
                                                    </div>
                                                </div>
                                            )}
                                            {item.cnic.backImage && (
                                                <div
                                                    className="relative h-24 bg-gray-100 rounded cursor-pointer hover:opacity-80"
                                                    onClick={() => setSelectedImage(item.cnic.backImage!)}
                                                >
                                                    <Image
                                                        src={item.cnic.backImage}
                                                        alt="CNIC Back"
                                                        fill
                                                        className="object-cover rounded"
                                                    />
                                                    <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 hover:opacity-100 transition-opacity">
                                                        <Eye className="w-6 h-6 text-white" />
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                        <div className="flex gap-2">
                                            <Button
                                                size="sm"
                                                className="flex-1"
                                                onClick={() => handleApprove(item.id)}
                                                disabled={processing === item.id}
                                            >
                                                <CheckCircle className="w-4 h-4 mr-1" />
                                                Approve
                                            </Button>
                                            <Button
                                                size="sm"
                                                variant="destructive"
                                                className="flex-1"
                                                onClick={() => handleReject(item.id)}
                                                disabled={processing === item.id}
                                            >
                                                <XCircle className="w-4 h-4 mr-1" />
                                                Reject
                                            </Button>
                                        </div>
                                    </CardContent>
                                </Card>
                            ))
                        )}
                    </div>
                </CardContent>
            </Card>

            {/* Approved CNICs */}
            {approvedCNICs.length > 0 && (
                <Card>
                    <CardHeader>
                        <CardTitle>Approved ({approvedCNICs.length})</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-2">
                            {approvedCNICs.map((item) => (
                                <div
                                    key={item.id}
                                    className="flex items-center justify-between p-3 border rounded-lg"
                                >
                                    <div>
                                        <p className="font-medium">{item.fullName}</p>
                                        <p className="text-sm text-muted-foreground">{item.cnic.number}</p>
                                    </div>
                                    {getStatusBadge(item.cnic.verificationStatus)}
                                </div>
                            ))}
                        </div>
                    </CardContent>
                </Card>
            )}

            {/* Image Viewer Dialog */}
            <Dialog open={!!selectedImage} onOpenChange={() => setSelectedImage(null)}>
                <DialogContent className="max-w-3xl">
                    <DialogHeader>
                        <DialogTitle>CNIC Document</DialogTitle>
                    </DialogHeader>
                    {selectedImage && (
                        <div className="relative w-full h-96">
                            <Image
                                src={selectedImage}
                                alt="CNIC Document"
                                fill
                                className="object-contain"
                            />
                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}
