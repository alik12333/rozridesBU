'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '@/lib/firebase-client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

export default function LoginPage() {
    const router = useRouter();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            // Map exactly 'admin' to 'admin@rozrides.com'
            const loginEmail = email.trim().toLowerCase() === 'admin' 
                ? 'admin@rozrides.com' 
                : email.trim();

            const userCredential = await signInWithEmailAndPassword(auth, loginEmail, password);

            // Allow initial admin setup or check claims
            // For now, we fetch the user profile to check the role
            // TODO: In production, custom claims are better, but this works for now
            // We need to fetch the document from Firestore Client side
            // Ideally we should use a server action or custom claim, but let's read the doc

            // Note: We can't use the admin SDK here (client side). 
            // We need to read the user document. 
            // Assuming the security rules allow a user to read their own document.

            // To be safe and simple, we are adding a check here. 
            // However, `signInWithEmailAndPassword` is successful at this point.
            // If we want to blocking non-admins, we might need a blocking function (Cloud Functions) 
            // or just logout immediately.

            // Let's do the client-side check.
            const { doc, getDoc } = await import('firebase/firestore');
            const { db } = await import('@/lib/firebase-client');

            const userDoc = await getDoc(doc(db, 'users', userCredential.user.uid));

            if (userDoc.exists()) {
                const userData = userDoc.data();
                const userRole = userData.role;
                const isLegacyAdmin = userData.roles?.isAdmin;

                if (userRole !== 'super_admin' && userRole !== 'admin' && !isLegacyAdmin) {
                    await auth.signOut();
                    throw new Error('Access Denied: You do not have administrator privileges.');
                }
            } else {
                // Handle edge case where user exists in Auth but not in Firestore (e.g. manually created in console without doc)
                // For safety, deny.
                await auth.signOut();
                throw new Error('Access Denied: User profile not found.');
            }

            router.push('/dashboard');
        } catch (err: unknown) {
            setError(err instanceof Error ? err.message : 'Invalid credentials');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-purple-100 dark:from-gray-900 dark:to-gray-800 p-4">
            <Card className="w-full max-w-md shadow-2xl">
                <CardHeader className="space-y-1 text-center">
                    <div className="flex justify-center mb-4">
                        <div className="w-16 h-16 bg-primary rounded-full flex items-center justify-center">
                            <span className="text-3xl font-bold text-white">R</span>
                        </div>
                    </div>
                    <CardTitle className="text-3xl font-bold">RozRides</CardTitle>
                    <CardDescription className="text-lg">Admin Portal</CardDescription>
                </CardHeader>
                <CardContent>
                    <form onSubmit={handleLogin} className="space-y-4">
                        <div className="space-y-2">
                            <Label htmlFor="email">Email or Username</Label>
                            <Input
                                id="email"
                                type="text"
                                placeholder="admin or admin@rozrides.com"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                                disabled={loading}
                            />
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="password">Password</Label>
                            <Input
                                id="password"
                                type="password"
                                placeholder="Enter your password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                disabled={loading}
                            />
                        </div>
                        {error && (
                            <div className="text-sm text-destructive bg-destructive/10 p-3 rounded-md">
                                {error}
                            </div>
                        )}
                        <Button type="submit" className="w-full" disabled={loading}>
                            {loading ? 'Signing in...' : 'Sign In'}
                        </Button>
                    </form>
                </CardContent>
            </Card>
        </div>
    );
}
