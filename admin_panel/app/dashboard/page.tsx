import { getDashboardStats } from '@/lib/firestore';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, Car, CheckCircle, Clock, BadgeCheck, Activity, AlertTriangle } from 'lucide-react';
import RecentActivityFeed from '@/components/RecentActivityFeed';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
    const stats = await getDashboardStats();

    const statCards = [
        {
            title: 'Total Users',
            value: stats.totalUsers,
            icon: Users,
            color: 'text-blue-600',
            bgColor: 'bg-blue-100',
        },
        {
            title: 'Total Listings',
            value: stats.totalListings,
            icon: Car,
            color: 'text-purple-600',
            bgColor: 'bg-purple-100',
        },
        {
            title: 'Pending Listings',
            value: stats.pendingListings,
            icon: Clock,
            color: 'text-yellow-600',
            bgColor: 'bg-yellow-100',
        },
        {
            title: 'Approved Listings',
            value: stats.approvedListings,
            icon: CheckCircle,
            color: 'text-green-600',
            bgColor: 'bg-green-100',
        },
        {
            title: 'Verified Users',
            value: stats.verifiedUsers,
            icon: BadgeCheck,
            color: 'text-emerald-600',
            bgColor: 'bg-emerald-100',
        },
        {
            title: 'Live Trips',
            value: stats.activeTrips,
            icon: Activity,
            color: 'text-indigo-600',
            bgColor: 'bg-indigo-100',
        },
        {
            title: 'Open Disputes',
            value: stats.openDisputes,
            icon: AlertTriangle,
            color: stats.openDisputes > 0 ? 'text-white' : 'text-orange-600',
            bgColor: stats.openDisputes > 0 ? 'bg-red-600' : 'bg-orange-100',
            isCritical: stats.openDisputes > 0,
        },
        {
            title: 'Pending CNIC',
            value: stats.pendingCNIC,
            icon: Clock,
            color: stats.pendingCNIC > 0 ? 'text-white' : 'text-orange-600',
            bgColor: stats.pendingCNIC > 0 ? 'bg-red-500' : 'bg-orange-100',
            isCritical: stats.pendingCNIC > 0,
        },
    ];

    return (
        <div className="space-y-8">
            <div>
                <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
                <p className="text-muted-foreground">Welcome to RozRides Admin Panel</p>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {statCards.map((stat) => {
                    const Icon = stat.icon;
                    return (
                        <Card key={stat.title} className={`hover:shadow-lg transition-shadow ${stat.isCritical ? 'border-red-500 shadow-sm shadow-red-200' : ''}`}>
                            <CardHeader className="flex flex-row items-center justify-between pb-2">
                                <CardTitle className={`text-sm font-medium ${stat.isCritical ? 'text-red-700' : 'text-muted-foreground'}`}>
                                    {stat.title}
                                </CardTitle>
                                <div className={`p-2 rounded-full ${stat.bgColor}`}>
                                    <Icon className={`w-5 h-5 ${stat.color}`} />
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className={`text-3xl font-bold ${stat.isCritical ? 'text-red-700' : ''}`}>
                                    {stat.value}
                                </div>
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Quick Actions */}
                <Card className="lg:col-span-2">
                    <CardHeader>
                        <CardTitle>Quick Actions</CardTitle>
                    </CardHeader>
                    <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <a
                            href="/dashboard/users"
                            className="p-4 border rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                        >
                            <Users className="w-8 h-8 mb-2 text-blue-600" />
                            <h3 className="font-semibold">Manage Users</h3>
                            <p className="text-sm text-muted-foreground">View and manage all users</p>
                        </a>
                        <a
                            href="/dashboard/cnic"
                            className="p-4 border rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                        >
                            <BadgeCheck className="w-8 h-8 mb-2 text-emerald-600" />
                            <h3 className="font-semibold">CNIC Verification</h3>
                            <p className="text-sm text-muted-foreground">Approve or reject CNICs</p>
                        </a>
                        <a
                            href="/dashboard/listings"
                            className="p-4 border rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                        >
                            <Car className="w-8 h-8 mb-2 text-purple-600" />
                            <h3 className="font-semibold">Car Listings</h3>
                            <p className="text-sm text-muted-foreground">Manage car listings</p>
                        </a>
                        <a
                            href="/dashboard/claims"
                            className="p-4 border rounded-lg hover:bg-red-50 transition-colors"
                        >
                            <AlertTriangle className="w-8 h-8 mb-2 text-red-600" />
                            <h3 className="font-semibold text-red-700">Dispute Resolution</h3>
                            <p className="text-sm text-red-600/80">Manage {stats.openDisputes} open claims</p>
                        </a>
                    </CardContent>
                </Card>

                {/* Recent Activity Feed */}
                <div>
                    <RecentActivityFeed />
                </div>
            </div>
        </div>
    );
}
