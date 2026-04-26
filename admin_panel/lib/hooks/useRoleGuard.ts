import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { onAuthStateChanged, User } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase-client';

export type UserRole = 'super_admin' | 'admin' | 'user' | null;

interface RoleGuardResult {
    user: User | null;
    role: UserRole;
    loading: boolean;
    isSuperAdmin: boolean;
    isAdmin: boolean;
}

export function useRoleGuard(): RoleGuardResult {
    const router = useRouter();
    const [user, setUser] = useState<User | null>(null);
    const [role, setRole] = useState<UserRole>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
            if (!currentUser) {
                router.push('/login');
                setLoading(false);
                return;
            }

            setUser(currentUser);

            try {
                // Fetch user document from Firestore to get their role
                const userDocRef = doc(db, 'users', currentUser.uid);
                const userDoc = await getDoc(userDocRef);

                if (userDoc.exists()) {
                    const data = userDoc.data();
                    const userRole = data.role as UserRole;
                    // Also check legacy roles.isAdmin if data.role is missing
                    const isLegacyAdmin = data.roles?.isAdmin;

                    if (userRole === 'super_admin' || userRole === 'admin' || isLegacyAdmin) {
                        setRole(userRole || 'admin'); // Default to admin if legacy
                        setLoading(false);
                    } else {
                        // Unauthorized
                        await auth.signOut();
                        router.push('/login?error=Unauthorized');
                    }
                } else {
                    // No document found
                    await auth.signOut();
                    router.push('/login?error=No+Account+Found');
                }
            } catch (error) {
                console.error('Error fetching user role:', error);
                await auth.signOut();
                router.push('/login?error=Server+Error');
            }
        });

        return () => unsubscribe();
    }, [router]);

    return {
        user,
        role,
        loading,
        isSuperAdmin: role === 'super_admin',
        isAdmin: role === 'super_admin' || role === 'admin'
    };
}
