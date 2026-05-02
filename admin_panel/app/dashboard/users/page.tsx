import { getAllUsers } from '@/lib/firestore';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

export const dynamic = 'force-dynamic';

export default async function UsersPage() {
    const users = await getAllUsers();

    const getStatusBadge = (status: string): "success" | "secondary" | "destructive" | "default" => {
        const variants: Record<string, "success" | "secondary" | "destructive" | "default"> = {
            active: 'success',
            inactive: 'secondary',
            suspended: 'destructive',
        };
        return variants[status] || 'secondary';
    };

    const getCNICBadge = (status?: string) => {
        if (!status) return <Badge variant="secondary">No CNIC</Badge>;
        const variants: Record<string, "success" | "warning" | "destructive" | "default"> = {
            approved: 'success',
            pending: 'warning',
            rejected: 'destructive',
        };
        return <Badge variant={variants[status] || 'default'}>{status.toUpperCase()}</Badge>;
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-4xl font-bold mb-2">User Management</h1>
                <p className="text-muted-foreground">View and manage all registered users</p>
            </div>

            <Card>
                <CardHeader>
                    <CardTitle>All Users ({users.length})</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="rounded-md border">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Name</TableHead>
                                    <TableHead>Email</TableHead>
                                    <TableHead>Phone</TableHead>
                                    <TableHead>CNIC Status</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead>Joined</TableHead>
                                    <TableHead className="text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {users.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={6} className="text-center text-muted-foreground">
                                            No users found
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    users.map((user) => (
                                        <TableRow key={user.id}>
                                            <TableCell className="font-medium">{user.fullName}</TableCell>
                                            <TableCell>{user.email}</TableCell>
                                            <TableCell>{user.phoneNumber}</TableCell>
                                            <TableCell>{getCNICBadge(user.cnic?.verificationStatus)}</TableCell>
                                            <TableCell>
                                                <Badge variant={getStatusBadge(user.status)}>
                                                    {user.status.toUpperCase()}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-muted-foreground">
                                                {new Date(user.createdAt).toLocaleDateString()}
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <a href={`/dashboard/users/${user.id}`} className="text-primary hover:underline font-medium text-sm">
                                                    View Details
                                                </a>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
