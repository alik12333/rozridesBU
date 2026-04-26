'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { LayoutDashboard, Users, BadgeCheck, Car, LogOut, ShieldPlus, ClipboardList, AlertTriangle, Star } from 'lucide-react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { useRoleGuard } from '@/lib/hooks/useRoleGuard';
import NotificationBell from '@/components/NotificationBell';
import { auth } from '@/lib/firebase-client';

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const { user, isSuperAdmin, loading } = useRoleGuard();
    const router = useRouter();
    const pathname = usePathname();

    const handleLogout = async () => {
        await auth.signOut();
        router.push('/login');
    };

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="text-center">
                    <div className="w-16 h-16 border-4 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
                    <p className="text-muted-foreground">Loading...</p>
                </div>
            </div>
        );
    }

    const navItems = [
        { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
        { href: '/dashboard/users', label: 'Users', icon: Users },
        { href: '/dashboard/cnic', label: 'CNIC Verification', icon: BadgeCheck },
        { href: '/dashboard/listings', label: 'Car Listings', icon: Car },
        { href: '/dashboard/bookings', label: 'Bookings', icon: ClipboardList },
        { href: '/dashboard/claims', label: 'Damage Claims', icon: AlertTriangle },
        { href: '/dashboard/reviews', label: 'Reviews', icon: Star },
    ];

    if (isSuperAdmin) {
        navItems.push({ href: '/dashboard/admins', label: 'Admins', icon: ShieldPlus });
    }

    return (
        <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
            {/* Sidebar */}
            <aside className="fixed left-0 top-0 h-full w-64 bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 flex flex-col">
                {/* Logo */}
                <div className="p-6 border-b border-gray-200 dark:border-gray-700">
                    <div className="flex items-center space-x-3">
                        <div className="w-10 h-10 bg-primary rounded-full flex items-center justify-center">
                            <span className="text-xl font-bold text-white">R</span>
                        </div>
                        <div>
                            <h2 className="text-xl font-bold">RozRides</h2>
                            <p className="text-xs text-muted-foreground">Admin Panel</p>
                        </div>
                    </div>
                </div>

                {/* Navigation */}
                <nav className="flex-1 p-4 space-y-2">
                    {navItems.map((item) => {
                        const Icon = item.icon;
                        const isActive = pathname === item.href;
                        return (
                            <Link key={item.href} href={item.href}>
                                <div
                                    className={`flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${isActive
                                        ? 'bg-primary text-white'
                                        : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
                                        }`}
                                >
                                    <Icon className="w-5 h-5" />
                                    <span className="font-medium">{item.label}</span>
                                </div>
                            </Link>
                        );
                    })}
                </nav>

                {/* Logout */}
                <div className="p-4 border-t border-gray-200 dark:border-gray-700">
                    <Button
                        variant="ghost"
                        className="w-full justify-start text-red-600 hover:text-red-700 hover:bg-red-50"
                        onClick={handleLogout}
                    >
                        <LogOut className="w-5 h-5 mr-3" />
                        Logout
                    </Button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="ml-64 flex-1 flex flex-col min-h-screen">
                {/* Top Navigation Bar */}
                <header className="h-16 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between px-8 sticky top-0 z-10">
                    <h1 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
                        {navItems.find((item) => item.href === pathname)?.label || 'Dashboard'}
                    </h1>
                    <div className="flex items-center space-x-4">
                        <NotificationBell />
                        <div className="flex items-center space-x-2">
                            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                                {user?.email}
                            </span>
                        </div>
                    </div>
                </header>

                <div className="p-8">{children}</div>
            </main>
        </div>
    );
}
