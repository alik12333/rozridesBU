'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { 
    CheckCircle, 
    XCircle, 
    Eye, 
    Zap, 
    User, 
    CreditCard, 
    ShieldCheck, 
    AlertCircle,
    Loader2,
    Check
} from 'lucide-react';
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
    aiResult?: {
        extractedNumber: string;
        matches: boolean;
        verifying: boolean;
        error?: string;
    };
}

export default function CNICPage() {
    const [cnicData, setCnicData] = useState<CNICData[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedImage, setSelectedImage] = useState<string | null>(null);
    const [processing, setProcessing] = useState<string | null>(null);
    const [aiAuto, setAiAuto] = useState(false);

    useEffect(() => {
        fetchCNICData();
        const storedAiAuto = localStorage.getItem('aiAutoApprove');
        if (storedAiAuto) setAiAuto(storedAiAuto === 'true');
    }, []);

    const fetchCNICData = async () => {
        try {
            const res = await fetch('/api/cnic');
            const data = await res.json();
            // Initialize AI state for each item
            const enrichedData = data.map((item: any) => ({
                ...item,
                aiResult: { verifying: false }
            }));
            setCnicData(enrichedData);
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
                alert(`Failed to approve: ${data.error}`);
            }
        } catch (error) {
            console.error('Error approving CNIC:', error);
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
                alert(`Failed to reject: ${data.error}`);
            }
        } catch (error) {
            console.error('Error rejecting CNIC:', error);
        } finally {
            setProcessing(null);
        }
    };

    const runAiVerification = async (userId: string) => {
        // Update local state to show verifying
        setCnicData(prev => prev.map(item => 
            item.id === userId ? { ...item, aiResult: { ...item.aiResult!, verifying: true } } : item
        ));

        try {
            const res = await fetch(`/api/cnic/${userId}/verify`, { method: 'POST' });
            
            let data;
            try {
                data = await res.json();
            } catch (e) {
                throw new Error('Server returned an invalid response format.');
            }

            if (res.ok) {
                setCnicData(prev => prev.map(item => 
                    item.id === userId ? { 
                        ...item, 
                        aiResult: { 
                            verifying: false, 
                            extractedNumber: data.extractedNumber, 
                            matches: data.matches 
                        } 
                    } : item
                ));

                // If auto-approve is on and it matches, approve it!
                if (aiAuto && data.matches) {
                    await handleApprove(userId);
                }
            } else {
                setCnicData(prev => prev.map(item => 
                    item.id === userId ? { ...item, aiResult: { verifying: false, error: data.error, details: data.details } } : item
                ));
            }
        } catch (error: any) {
            console.error('AI verification failed:', error);
            setCnicData(prev => prev.map(item => 
                item.id === userId ? { 
                    ...item, 
                    aiResult: { 
                        verifying: false, 
                        error: 'Connection Failed', 
                        details: error.message || 'The server took too long to respond.' 
                    } 
                } : item
            ));
        }
    };

    const toggleAiAuto = () => {
        const newValue = !aiAuto;
        setAiAuto(newValue);
        localStorage.setItem('aiAutoApprove', String(newValue));
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
        return (
            <div className="flex flex-col items-center justify-center py-20">
                <Loader2 className="w-10 h-10 animate-spin text-purple-600 mb-4" />
                <p className="text-muted-foreground font-medium">Loading CNIC data...</p>
            </div>
        );
    }

    const pendingCNICs = cnicData.filter((c) => c.cnic.verificationStatus === 'pending');
    const approvedCNICs = cnicData.filter((c) => c.cnic.verificationStatus === 'approved');

    return (
        <div className="max-w-7xl mx-auto space-y-8 pb-12">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-6 rounded-3xl shadow-sm border border-purple-50">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
                        <ShieldCheck className="w-8 h-8 text-purple-600" />
                        CNIC Verification
                    </h1>
                    <p className="text-muted-foreground">Ensure trust and safety by verifying identity documents</p>
                </div>
                
                <div className="flex items-center gap-3 bg-purple-50 p-3 rounded-2xl border border-purple-100">
                    <div className="flex flex-col text-right">
                        <span className="text-sm font-bold text-purple-900">Enable AI: Auto</span>
                        <span className="text-[10px] text-purple-600">Auto-approve on match</span>
                    </div>
                    <Button 
                        onClick={toggleAiAuto}
                        variant={aiAuto ? "default" : "outline"}
                        className={`rounded-full px-6 transition-all duration-300 ${aiAuto ? 'bg-purple-600 hover:bg-purple-700 shadow-md shadow-purple-200' : 'border-purple-200 text-purple-600'}`}
                    >
                        {aiAuto ? 'ON' : 'OFF'}
                    </Button>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
                {/* Pending Column */}
                <div className="lg:col-span-8 space-y-6">
                    <div className="flex items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center gap-2">
                            Pending Requests
                            <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100 border-none">
                                {pendingCNICs.length}
                            </Badge>
                        </h2>
                        {pendingCNICs.length > 0 && (
                            <Button 
                                variant="ghost" 
                                size="sm" 
                                className="text-purple-600 hover:text-purple-700 hover:bg-purple-50"
                                onClick={() => pendingCNICs.forEach(item => !item.aiResult?.verifying && runAiVerification(item.id))}
                            >
                                <Zap className="w-4 h-4 mr-2" />
                                Verify All with AI
                            </Button>
                        )}
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {pendingCNICs.length === 0 ? (
                            <Card className="col-span-full py-12 border-dashed flex flex-col items-center justify-center text-center">
                                <div className="p-4 bg-gray-50 rounded-full mb-4">
                                    <Check className="w-8 h-8 text-gray-300" />
                                </div>
                                <h3 className="text-lg font-semibold text-gray-900">All clear!</h3>
                                <p className="text-muted-foreground">No pending CNIC verifications at the moment.</p>
                            </Card>
                        ) : (
                            pendingCNICs.map((item) => (
                                <Card key={item.id} className="overflow-hidden border-none shadow-lg hover:shadow-xl transition-shadow duration-300 rounded-3xl">
                                    <CardHeader className="bg-gray-50/50 pb-4">
                                        <div className="flex justify-between items-start">
                                            <div className="flex items-center gap-3">
                                                <div className="p-2 bg-purple-100 rounded-xl">
                                                    <User className="w-5 h-5 text-purple-600" />
                                                </div>
                                                <div>
                                                    <h3 className="font-bold text-gray-900">{item.fullName}</h3>
                                                    <p className="text-xs text-muted-foreground font-mono">{item.cnic.number}</p>
                                                </div>
                                            </div>
                                            {getStatusBadge(item.cnic.verificationStatus)}
                                        </div>
                                    </CardHeader>
                                    
                                    <CardContent className="pt-6 space-y-6">
                                        {/* Images */}
                                        <div className="grid grid-cols-2 gap-3">
                                            {item.cnic.frontImage && (
                                                <div className="group relative aspect-[3/2] bg-gray-100 rounded-2xl overflow-hidden cursor-pointer" onClick={() => setSelectedImage(item.cnic.frontImage!)}>
                                                    <Image src={item.cnic.frontImage} alt="Front" fill className="object-cover transition-transform group-hover:scale-105" />
                                                    <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                                                        <Eye className="text-white w-6 h-6" />
                                                    </div>
                                                    <Badge className="absolute top-2 left-2 bg-black/50 backdrop-blur-sm border-none text-[10px]">FRONT</Badge>
                                                </div>
                                            )}
                                            {item.cnic.backImage && (
                                                <div className="group relative aspect-[3/2] bg-gray-100 rounded-2xl overflow-hidden cursor-pointer" onClick={() => setSelectedImage(item.cnic.backImage!)}>
                                                    <Image src={item.cnic.backImage} alt="Back" fill className="object-cover transition-transform group-hover:scale-105" />
                                                    <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                                                        <Eye className="text-white w-6 h-6" />
                                                    </div>
                                                    <Badge className="absolute top-2 left-2 bg-black/50 backdrop-blur-sm border-none text-[10px]">BACK</Badge>
                                                </div>
                                            )}
                                        </div>

                                        {/* AI Analysis Result */}
                                        <div className="bg-gray-50 p-4 rounded-2xl border border-gray-100">
                                            <div className="flex items-center justify-between mb-2">
                                                <span className="text-xs font-bold text-gray-500 uppercase tracking-wider flex items-center gap-1">
                                                    <Zap className="w-3 h-3" />
                                                    AI Verification
                                                </span>
                                                {!item.aiResult?.extractedNumber && !item.aiResult?.verifying && !item.aiResult?.error && (
                                                    <Button 
                                                        variant="ghost" 
                                                        size="sm" 
                                                        className="h-6 text-[10px] text-purple-600"
                                                        onClick={() => runAiVerification(item.id)}
                                                    >
                                                        Run Analysis
                                                    </Button>
                                                )}
                                            </div>

                                            {item.aiResult?.verifying ? (
                                                <div className="flex items-center gap-2 py-2">
                                                    <Loader2 className="w-4 h-4 animate-spin text-purple-600" />
                                                    <span className="text-sm text-purple-600 font-medium animate-pulse">Extracting data...</span>
                                                </div>
                                            ) : item.aiResult?.extractedNumber ? (
                                                <div className="space-y-2">
                                                    <div className="flex justify-between items-center">
                                                        <span className="text-sm text-gray-600">Extracted:</span>
                                                        <span className="text-sm font-mono font-bold text-gray-900">{item.aiResult.extractedNumber}</span>
                                                    </div>
                                                    <div className="flex justify-between items-center">
                                                        <span className="text-sm text-gray-600">Status:</span>
                                                        {item.aiResult.matches ? (
                                                            <Badge className="bg-green-100 text-green-700 hover:bg-green-100 border-none flex items-center gap-1">
                                                                <CheckCircle className="w-3 h-3" />
                                                                MATCHED
                                                            </Badge>
                                                        ) : (
                                                            <Badge className="bg-red-100 text-red-700 hover:bg-red-100 border-none flex items-center gap-1">
                                                                <XCircle className="w-3 h-3" />
                                                                NO MATCH
                                                            </Badge>
                                                        )}
                                                    </div>
                                                </div>
                                            ) : item.aiResult?.error ? (
                                                <div className="flex flex-col gap-1 text-red-600 py-1">
                                                    <div className="flex items-center gap-2">
                                                        <AlertCircle className="w-4 h-4" />
                                                        <span className="text-xs font-medium">{item.aiResult.error}</span>
                                                        <Button variant="ghost" size="sm" className="h-6 text-[10px] p-0 underline" onClick={() => runAiVerification(item.id)}>Retry</Button>
                                                    </div>
                                                    {item.aiResult.details && (
                                                        <span className="text-[10px] opacity-70 italic ml-6 line-clamp-1">{item.aiResult.details}</span>
                                                    )}
                                                </div>
                                            ) : (
                                                <p className="text-xs text-gray-400 italic">Click "Run Analysis" to verify with AI</p>
                                            )}
                                        </div>

                                        {/* Actions */}
                                        <div className="flex gap-3">
                                            <Button
                                                className="flex-1 bg-green-600 hover:bg-green-700 rounded-xl"
                                                onClick={() => handleApprove(item.id)}
                                                disabled={processing === item.id}
                                            >
                                                {processing === item.id ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle className="w-4 h-4 mr-2" />}
                                                Approve
                                            </Button>
                                            <Button
                                                variant="destructive"
                                                className="flex-1 rounded-xl"
                                                onClick={() => handleReject(item.id)}
                                                disabled={processing === item.id}
                                            >
                                                {processing === item.id ? <Loader2 className="w-4 h-4 animate-spin" /> : <XCircle className="w-4 h-4 mr-2" />}
                                                Reject
                                            </Button>
                                        </div>
                                    </CardContent>
                                </Card>
                            ))
                        )}
                    </div>
                </div>

                {/* Approved Column */}
                <div className="lg:col-span-4 space-y-6">
                    <h2 className="text-xl font-bold flex items-center gap-2">
                        Recently Approved
                        <Badge variant="outline" className="border-green-200 text-green-600">
                            {approvedCNICs.length}
                        </Badge>
                    </h2>
                    
                    <div className="space-y-3">
                        {approvedCNICs.length === 0 ? (
                            <p className="text-sm text-muted-foreground italic">No approved records yet.</p>
                        ) : (
                            approvedCNICs.slice(0, 10).map((item) => (
                                <div
                                    key={item.id}
                                    className="flex items-center justify-between p-4 bg-white border border-gray-100 rounded-2xl shadow-sm"
                                >
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 bg-green-50 rounded-full flex items-center justify-center">
                                            <User className="w-5 h-5 text-green-600" />
                                        </div>
                                        <div>
                                            <p className="text-sm font-bold text-gray-900">{item.fullName}</p>
                                            <p className="text-[10px] font-mono text-muted-foreground">{item.cnic.number}</p>
                                        </div>
                                    </div>
                                    <div className="p-1.5 bg-green-100 rounded-full">
                                        <Check className="w-3 h-3 text-green-600" />
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </div>

            {/* Image Viewer Dialog */}
            <Dialog open={!!selectedImage} onOpenChange={() => setSelectedImage(null)}>
                <DialogContent className="max-w-4xl p-0 overflow-hidden bg-transparent border-none shadow-none">
                    {selectedImage && (
                        <div className="relative w-full h-[80vh] bg-black/90 rounded-3xl overflow-hidden">
                            <Image
                                src={selectedImage}
                                alt="CNIC Document"
                                fill
                                className="object-contain"
                            />
                            <Button 
                                variant="ghost" 
                                className="absolute top-4 right-4 text-white hover:bg-white/20"
                                onClick={() => setSelectedImage(null)}
                            >
                                <XCircle className="w-8 h-8" />
                            </Button>
                        </div>
                    )}
                </DialogContent>
            </Dialog>
        </div>
    );
}
