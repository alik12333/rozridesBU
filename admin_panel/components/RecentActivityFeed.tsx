'use client';

import { useEffect, useState } from 'react';
import { collectionGroup, query, orderBy, limit, onSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Activity } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

interface ActivityItem {
    id: string;
    status: string;
    note: string;
    timestamp: Date;
}

export default function RecentActivityFeed() {
    const [activities, setActivities] = useState<ActivityItem[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Requires a composite index for collectionGroup 'timeline' with timestamp DESC
        const q = query(
            collectionGroup(db, 'timeline'),
            orderBy('timestamp', 'desc'),
            limit(10)
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const feed = snapshot.docs.map(doc => {
                const data = doc.data();
                return {
                    id: doc.id,
                    ...data,
                    timestamp: data.timestamp?.toDate() || new Date()
                };
            });
            setActivities(feed);
            setLoading(false);
        }, (error) => {
            console.error("Error fetching timeline:", error);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    if (loading) {
        return (
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Activity className="w-5 h-5 text-primary" />
                        Recent Activity Feed
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex justify-center p-4">
                        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin"></div>
                    </div>
                </CardContent>
            </Card>
        );
    }

    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <Activity className="w-5 h-5 text-primary" />
                    Recent Activity Feed
                </CardTitle>
            </CardHeader>
            <CardContent>
                <div className="space-y-6">
                    {activities.length === 0 ? (
                        <p className="text-muted-foreground text-sm text-center">No recent activity</p>
                    ) : (
                        activities.map((activity, index) => (
                            <div key={activity.id + index} className="flex gap-4">
                                <div className="mt-1">
                                    <div className="w-2 h-2 mt-1.5 rounded-full bg-primary" />
                                </div>
                                <div className="flex-1 space-y-1">
                                    <p className="text-sm font-medium leading-none">
                                        {activity.status.toUpperCase()}
                                    </p>
                                    <p className="text-sm text-muted-foreground line-clamp-2">
                                        {activity.note}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        {formatDistanceToNow(activity.timestamp, { addSuffix: true })}
                                    </p>
                                </div>
                            </div>
                        ))
                    )}
                </div>
            </CardContent>
        </Card>
    );
}
