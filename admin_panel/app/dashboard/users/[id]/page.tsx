import { getUser, banUser } from '@/lib/firestore';
import { notFound } from 'next/navigation';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { AlertTriangle, UserMinus, ShieldAlert, Star } from 'lucide-react';
import { revalidatePath } from 'next/cache';
import Image from 'next/image';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({ params }: { params: { id: string } }) {
    const user = await getUser(params.id);

    if (!user) {
        notFound();
    }

    async function handleBan() {
        'use server';
        await banUser(params.id);
        revalidatePath(`/dashboard/users/${params.id}`);
        revalidatePath('/dashboard/users');
    }

    const strikes = user.strikes || {};
    const totalStrikes = (strikes.lateCancellations || 0) + (strikes.damage_incidents || 0) + (strikes.disputed_deposits || 0);
    const isBanned = user.status === 'banned';

    return (
        <div className="space-y-6 max-w-5xl mx-auto">
            <div className="flex justify-between items-start">
                <div className="flex items-center gap-4">
                    <div className="w-16 h-16 rounded-full bg-gray-200 overflow-hidden relative">
                        {user.profilePhoto ? (
                            <Image src={user.profilePhoto} alt={user.fullName} fill className="object-cover" />
                        ) : (
                            <div className="w-full h-full flex items-center justify-center text-xl font-bold text-gray-500">
                                {user.fullName?.[0]?.toUpperCase() || '?'}
                            </div>
                        )}
                    </div>
                    <div>
                        <h1 className="text-3xl font-bold flex items-center gap-2">
                            {user.fullName}
                            <Badge variant={isBanned ? 'destructive' : 'default'}>
                                {user.status.toUpperCase()}
                            </Badge>
                        </h1>
                        <p className="text-muted-foreground">{user.email} • {user.phoneNumber || 'No phone'}</p>
                    </div>
                </div>
                
                {!isBanned && totalStrikes >= 3 && (
                    <div className="flex items-center gap-3 bg-red-50 border border-red-200 text-red-700 px-4 py-2 rounded-lg">
                        <AlertTriangle className="w-5 h-5" />
                        <span className="font-medium">User has {totalStrikes} strikes!</span>
                        <form action={handleBan}>
                            <Button type="submit" variant="destructive" size="sm" className="ml-2">
                                <UserMinus className="w-4 h-4 mr-2" /> Ban User
                            </Button>
                        </form>
                    </div>
                )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Reputation Panel */}
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Star className="w-5 h-5 text-yellow-500" />
                            Reputation Metrics
                        </CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-6">
                        <div>
                            <h3 className="text-sm font-medium text-muted-foreground mb-2">Renter Profile</h3>
                            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                                <div>
                                    <div className="text-2xl font-bold">{user.renterRating?.toFixed(1) || 'N/A'}</div>
                                    <div className="text-xs text-muted-foreground">Average Rating</div>
                                </div>
                                <div className="text-right">
                                    <div className="text-2xl font-bold">{user.renterTrips || 0}</div>
                                    <div className="text-xs text-muted-foreground">Completed Trips</div>
                                </div>
                            </div>
                        </div>

                        <div>
                            <h3 className="text-sm font-medium text-muted-foreground mb-2">Host Profile</h3>
                            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                                <div>
                                    <div className="text-2xl font-bold">{user.hostRating?.toFixed(1) || 'N/A'}</div>
                                    <div className="text-xs text-muted-foreground">Average Rating</div>
                                </div>
                                <div className="text-right">
                                    <div className="text-2xl font-bold">{user.hostTrips || 0}</div>
                                    <div className="text-xs text-muted-foreground">Completed Trips</div>
                                </div>
                            </div>
                        </div>
                    </CardContent>
                </Card>

                {/* Strikes Panel */}
                <Card className={totalStrikes >= 3 ? 'border-red-500 shadow-sm shadow-red-200' : ''}>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2 text-red-600">
                            <ShieldAlert className="w-5 h-5" />
                            Policy Strikes
                        </CardTitle>
                        <CardDescription>
                            Three or more strikes result in an account review and potential ban.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-4">
                            <div className="flex justify-between items-center pb-2 border-b">
                                <span>Late Cancellations</span>
                                <Badge variant="secondary" className="text-lg">{strikes.lateCancellations || 0}</Badge>
                            </div>
                            <div className="flex justify-between items-center pb-2 border-b">
                                <span>Damage Incidents</span>
                                <Badge variant="secondary" className="text-lg">{strikes.damage_incidents || 0}</Badge>
                            </div>
                            <div className="flex justify-between items-center pb-2 border-b">
                                <span>Disputed Deposits (Host)</span>
                                <Badge variant="secondary" className="text-lg">{strikes.disputed_deposits || 0}</Badge>
                            </div>
                            <div className="flex justify-between items-center pt-2">
                                <span className="font-bold">Total Strikes</span>
                                <Badge variant={totalStrikes >= 3 ? 'destructive' : 'default'} className="text-xl">
                                    {totalStrikes}
                                </Badge>
                            </div>
                        </div>
                    </CardContent>
                </Card>
                
                {/* Advanced Admin Actions */}
                <Card className="md:col-span-2">
                    <CardHeader>
                        <CardTitle>Admin Actions</CardTitle>
                    </CardHeader>
                    <CardContent className="flex gap-4">
                         {!isBanned && (
                             <form action={handleBan}>
                                <Button type="submit" variant="outline" className="text-red-600 hover:text-white hover:bg-red-600">
                                    <UserMinus className="w-4 h-4 mr-2" /> Ban User Manually
                                </Button>
                             </form>
                         )}
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
