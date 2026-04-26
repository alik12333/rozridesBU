import { NextRequest, NextResponse } from 'next/server';
import { adminAuth, adminDb } from '@/lib/firebase-admin';

export async function GET(req: NextRequest) {
    // Only allow this in development for security, or secure it with a secret key
    if (process.env.NODE_ENV !== 'development' && req.nextUrl.searchParams.get('key') !== process.env.SEED_SECRET) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    try {
        const email = 'admin@rozrides.com';
        const password = '123456';
        let userRecord;

        try {
            userRecord = await adminAuth.getUserByEmail(email);
            console.log('User already exists in Auth');
        } catch (error: any) {
            if (error.code === 'auth/user-not-found') {
                userRecord = await adminAuth.createUser({
                    email,
                    password,
                    displayName: 'Super Admin',
                });
                console.log('Created user in Auth');
            } else {
                throw error;
            }
        }

        // Create or update Firestore document
        await adminDb.collection('users').doc(userRecord.uid).set({
            fullName: 'Super Admin',
            email,
            role: 'super_admin',
            createdAt: new Date(),
            updatedAt: new Date(),
            status: 'active',
        }, { merge: true });

        return NextResponse.json({ 
            message: 'Super Admin seeded successfully', 
            uid: userRecord.uid,
            email 
        });

    } catch (error: any) {
        console.error('Error seeding admin:', error);
        return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
    }
}
