import { getDashboardStats } from '@/lib/firestore';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, Car, CheckCircle, XCircle, Clock, BadgeCheck } from 'lucide-react';

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
            title: 'Pending CNIC',
            value: stats.pendingCNIC,
            icon: Clock,
            color: 'text-orange-600',
            bgColor: 'bg-orange-100',
        },
    ];

    return (
        <div className="space-y-8">
            <div>
                <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
                <p className="text-muted-foreground">Welcome to RozRides Admin Panel</p>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {statCards.map((stat) => {
                    const Icon = stat.icon;
                    return (
                        <Card key={stat.title} className="hover:shadow-lg transition-shadow">
                            <CardHeader className="flex flex-row items-center justify-between pb-2">
                                <CardTitle className="text-sm font-medium text-muted-foreground">
                                    {stat.title}
                                </CardTitle>
                                <div className={`p-2 rounded-full ${stat.bgColor}`}>
                                    <Icon className={`w-5 h-5 ${stat.color}`} />
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="text-3xl font-bold">{stat.value}</div>
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            {/* Quick Actions */}
            <Card>
                <CardHeader>
                    <CardTitle>Quick Actions</CardTitle>
                </CardHeader>
                <CardContent className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
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
                    <div className="p-4 border rounded-lg bg-gray-50 dark:bg-gray-800">
                        <Clock className="w-8 h-8 mb-2 text-yellow-600" />
                        <h3 className="font-semibold">Pending Approvals</h3>
                        <p className="text-sm text-muted-foreground">
                            {stats.pendingListings + stats.pendingCNIC} items pending
                        </p>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
