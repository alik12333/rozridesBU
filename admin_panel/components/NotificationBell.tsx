'use client';

import { useEffect, useState } from 'react';
import { collection, query, where, orderBy, onSnapshot, updateDoc, doc } from 'firebase/firestore';
import { db } from '@/lib/firebase-client';
import { Bell } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import { useRouter } from 'next/navigation';

export default function NotificationBell() {
    const [alerts, setAlerts] = useState<any[]>([]);
    const router = useRouter();

    useEffect(() => {
        const q = query(
            collection(db, 'adminAlerts'),
            where('isRead', '==', false),
            orderBy('createdAt', 'desc')
        );

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const newAlerts = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));
            setAlerts(newAlerts);
        });

        return () => unsubscribe();
    }, []);

    const handleAlertClick = async (alert: any) => {
        // Mark as read
        try {
            await updateDoc(doc(db, 'adminAlerts', alert.id), {
                isRead: true
            });
        } catch (e) {
            console.error('Error updating alert', e);
        }

        // Navigate based on alert type
        if (alert.type === 'dispute') {
            router.push('/dashboard/claims');
        } else if (alert.type === 'booking') {
            router.push('/dashboard/bookings');
        } else if (alert.type === 'user') {
            router.push('/dashboard/users');
        } else {
            router.push('/dashboard');
        }
    };

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="relative">
                    <Bell className="w-5 h-5" />
                    {alerts.length > 0 && (
                        <span className="absolute top-0 right-0 w-2.5 h-2.5 bg-red-600 rounded-full border-2 border-white dark:border-gray-900"></span>
                    )}
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-80">
                <DropdownMenuLabel>Notifications</DropdownMenuLabel>
                <DropdownMenuSeparator />
                {alerts.length === 0 ? (
                    <div className="p-4 text-center text-sm text-gray-500">
                        No new alerts
                    </div>
                ) : (
                    alerts.map((alert) => (
                        <DropdownMenuItem 
                            key={alert.id} 
                            onClick={() => handleAlertClick(alert)}
                            className="flex flex-col items-start p-3 cursor-pointer"
                        >
                            <span className="font-semibold text-sm">{alert.title}</span>
                            <span className="text-xs text-gray-500 line-clamp-2">{alert.body}</span>
                        </DropdownMenuItem>
                    ))
                )}
            </DropdownMenuContent>
        </DropdownMenu>
    );
}
