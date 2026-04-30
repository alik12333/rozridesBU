
import { NextRequest, NextResponse } from 'next/server';
import { adminAuth, adminDb } from '@/lib/firebase-admin';

export async function POST(req: NextRequest) {
    try {
        // 1. Verify the caller is an authenticated admin
        const authHeader = req.headers.get('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const token = authHeader.split('Bearer ')[1];
        const decodedToken = await adminAuth.verifyIdToken(token);

        // Check if the caller is an admin in Firestore
        const callerDoc = await adminDb.collection('users').doc(decodedToken.uid).get();
        const data = callerDoc.data();
        
        const isLegacyAdmin = data?.role === 'admin' || data?.role === 'super_admin';
        const isNewAdmin = data?.roles?.isAdmin === true;

        if (!callerDoc.exists || (!isLegacyAdmin && !isNewAdmin)) {
            return NextResponse.json({ error: 'Forbidden: You must be an admin to perform this action' }, { status: 403 });
        }

        // 2. Parse body
        const { email, password, fullName } = await req.json();

        if (!email || !password || !fullName) {
            return NextResponse.json({ error: 'Missing fields' }, { status: 400 });
        }

        // 3. Create verify user in Firebase Auth
        const userRecord = await adminAuth.createUser({
            email,
            password,
            displayName: fullName,
        });

        // 4. Create user document in Firestore with Admin Role
        await adminDb.collection('users').doc(userRecord.uid).set({
            fullName,
            email,
            phoneNumber: '', // Optional for admin
            createdAt: new Date(),
            updatedAt: new Date(),
            status: 'active',
            roles: {
                isRenter: false,
                isOwner: false,
                isAdmin: true,
            },
            fcmToken: null,
            location: null,
            cnic: null
        });

        return NextResponse.json({ message: 'Admin created successfully', uid: userRecord.uid });

    } catch (error: any) {
        console.error('Error creating admin:', error);
        return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 });
    }
}
