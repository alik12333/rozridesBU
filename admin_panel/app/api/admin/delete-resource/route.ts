import { NextRequest, NextResponse } from 'next/server';
import { adminDb } from '@/lib/firebase-admin';

export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const { resourceId, resourceType, adminId } = body;

        if (!resourceId || !resourceType || !adminId) {
            return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
        }

        // Verify that the requester is indeed a super_admin
        const adminDoc = await adminDb.collection('users').doc(adminId).get();
        if (!adminDoc.exists || adminDoc.data()?.role !== 'super_admin') {
            return NextResponse.json({ error: 'Unauthorized: Super Admin access required' }, { status: 403 });
        }

        const collectionName = resourceType === 'car' ? 'listings' : 'bookings';
        
        // Check if resource exists
        const resourceRef = adminDb.collection(collectionName).doc(resourceId);
        const resourceDoc = await resourceRef.get();
        
        if (!resourceDoc.exists) {
            return NextResponse.json({ error: `${resourceType} not found` }, { status: 404 });
        }

        // Perform deletion
        await resourceRef.delete();

        console.log(`[SUPER-ADMIN] ${adminId} deleted ${resourceType}: ${resourceId}`);

        return NextResponse.json({ success: true, message: `${resourceType} deleted successfully` });

    } catch (error: any) {
        console.error('Error in delete-resource API:', error);
        return NextResponse.json({ error: 'Internal server error', details: error.message }, { status: 500 });
    }
}
