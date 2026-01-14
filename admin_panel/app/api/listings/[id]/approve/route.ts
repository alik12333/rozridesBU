import { NextResponse } from 'next/server';
import { updateListingStatus, getAllListings } from '@/lib/firestore';
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

        await updateListingStatus(listingId, 'approved');

        // Send notification to owner
        await sendListingApprovalNotification(
            listing.ownerId,
            listing.carName,
            true
        );

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error approving listing:', error);
        return NextResponse.json({ error: 'Failed to approve listing' }, { status: 500 });
    }
}
