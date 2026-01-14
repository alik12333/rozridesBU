import { NextResponse } from 'next/server';
import { updateListingStatus } from '@/lib/firestore';
import { sendListingApprovalNotification } from '@/lib/fcm';
import { adminDb } from '@/lib/firebase-admin';

export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        const listingId = params.id;

        // Get listing details for notification
        const listingDoc = await adminDb.collection('listings').doc(listingId).get();
        const listing = listingDoc.data();

        if (!listing) {
            return NextResponse.json({ error: 'Listing not found' }, { status: 404 });
        }

        await updateListingStatus(listingId, 'rejected');

        // Send notification to owner
        await sendListingApprovalNotification(
            listing.ownerId,
            listing.carName,
            false
        );

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error rejecting listing:', error);
        return NextResponse.json({ error: 'Failed to reject listing' }, { status: 500 });
    }
}
