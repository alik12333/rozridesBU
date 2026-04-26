import { getAdmins, revokeAdmin } from '@/lib/firestore';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ShieldAlert, Trash2 } from 'lucide-react';
import { revalidatePath } from 'next/cache';
import AddAdminModal from '@/components/AddAdminModal';

export const dynamic = 'force-dynamic';

export default async function AdminsPage() {
    const admins = await getAdmins();

    // Server Action for revoking admin
    async function handleRevoke(formData: FormData) {
        'use server';
        const adminId = formData.get('adminId') as string;
        if (adminId) {
            await revokeAdmin(adminId);
            revalidatePath('/dashboard/admins');
        }
    }

    return (
        <div className="space-y-6">
            <div className="flex justify-between items-center">
                <div>
                    <h1 className="text-4xl font-bold mb-2">Admin Management</h1>
                    <p className="text-muted-foreground">Manage platform administrators (Super Admin only)</p>
                </div>
                <AddAdminModal />
            </div>

            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <ShieldAlert className="w-5 h-5 text-primary" />
                        Active Administrators ({admins.length})
                    </CardTitle>
                    <CardDescription>
                        Users in this list have access to the admin dashboard. Be extremely careful who you grant access to.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="rounded-md border">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Name</TableHead>
                                    <TableHead>Email</TableHead>
                                    <TableHead>Role</TableHead>
                                    <TableHead>Added Date</TableHead>
                                    <TableHead className="text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {admins.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={5} className="text-center text-muted-foreground">
                                            No admins found
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    admins.map((user) => {
                                        const roleLabel = user.roles?.isAdmin ? 'admin' : (user as any).role || 'admin';
                                        return (
                                            <TableRow key={user.id}>
                                                <TableCell className="font-medium">{user.fullName || 'Admin User'}</TableCell>
                                                <TableCell>{user.email}</TableCell>
                                                <TableCell>
                                                    <Badge variant={roleLabel === 'super_admin' ? 'default' : 'secondary'}>
                                                        {roleLabel.toUpperCase()}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-muted-foreground">
                                                    {new Date(user.createdAt).toLocaleDateString()}
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    {roleLabel !== 'super_admin' && (
                                                        <form action={handleRevoke}>
                                                            <input type="hidden" name="adminId" value={user.id} />
                                                            <Button variant="ghost" size="sm" type="submit" className="text-red-600 hover:text-red-700 hover:bg-red-50">
                                                                <Trash2 className="w-4 h-4 mr-2" /> Revoke
                                                            </Button>
                                                        </form>
                                                    )}
                                                </TableCell>
                                            </TableRow>
                                        );
                                    })
                                )}
                            </TableBody>
                        </Table>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}
