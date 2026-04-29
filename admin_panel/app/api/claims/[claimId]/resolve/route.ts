import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';
import { FieldValue } from 'firebase-admin/firestore';

interface ResolveBody {
    bookingId: string;
    resolvedInFavorOf: 'host' | 'renter' | 'split';
    finalDeductionAmount: number;
    adminNotes?: string;
    hostId: string;
    renterId: string;
    depositAmount?: number;
}

export async function POST(
    request: Request,
    { params }: { params: { claimId: string } }
) {
    const { claimId } = params;
    const body: ResolveBody = await request.json();
    const { bookingId, resolvedInFavorOf, finalDeductionAmount, adminNotes, hostId, renterId, depositAmount } = body;

    if (!resolvedInFavorOf || finalDeductionAmount === undefined) {
        return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    try {
        const claimRef = adminDb.collection('damageClaims').doc(claimId);
        const bookingRef = adminDb.collection('bookings').doc(bookingId);
        const bookingSnap = await bookingRef.get();
        
        if (!bookingSnap.exists) {
            return NextResponse.json({ error: 'Booking not found' }, { status: 404 });
        }
        
        const bookingData = bookingSnap.data()!;
        const now = FieldValue.serverTimestamp();

        const batch = adminDb.batch();

        // 1. Update Claim
        batch.update(claimRef, {
            status: 'resolved',
            resolvedInFavorOf,
            finalDeductionAmount,
            adminNotes: adminNotes ?? null,
            resolvedAt: now,
        });

        // 2. Update Booking Status (from 'flagged' to 'completed')
        batch.update(bookingRef, {
            status: 'completed',
            updatedAt: now,
        });

        // 2b. Remove date range from car schedule
        if (bookingData.carId && bookingData.startDate && bookingData.endDate) {
            const carRef = adminDb.collection('listings').doc(bookingData.carId);
            batch.update(carRef, {
                bookedDateRanges: FieldValue.arrayRemove({
                    start: bookingData.startDate,
                    end: bookingData.endDate,
                    bookingId: bookingId
                })
            });
        }

        // 3. Timeline event
        const timelineRef = bookingRef.collection('timeline').doc();
        batch.set(timelineRef, {
            status: 'completed',
            note: `Admin has resolved this flagged trip. Final deduction: PKR ${finalDeductionAmount}. ${adminNotes || ''}`,
            timestamp: now,
        });

        // 4. Determine notifications
        let renterMessage = '';
        let hostMessage = '';
        const title = 'Trip Review Finalized';

        if (resolvedInFavorOf === 'host') {
            renterMessage = `RozRides has completed the review of your trip. The decision is in favor of the host. A deduction of PKR ${finalDeductionAmount} has been applied. Please complete your cash exchange.`;
            hostMessage = `RozRides has completed the review of the trip. The decision is in your favor. You are authorized to keep a deduction of PKR ${finalDeductionAmount}.`;
        } else if (resolvedInFavorOf === 'renter') {
            renterMessage = `RozRides has completed the review of your trip. The decision is in your favor. Your full deposit must be returned. Please complete your cash exchange.`;
            hostMessage = `RozRides has completed the review of the trip. The decision is in favor of the renter. You must return the full deposit to the renter.`;
        } else {
            renterMessage = `RozRides has resolved the flagged trip with a split decision. The host will keep PKR ${finalDeductionAmount} from the deposit. Please complete your cash exchange.`;
            hostMessage = `RozRides has resolved the flagged trip with a split decision. You are authorized to keep PKR ${finalDeductionAmount} from the deposit.`;
        }

        // 5. Notify renter
        const renterNotifRef = adminDb.collection('users').doc(renterId).collection('notifications').doc();
        batch.set(renterNotifRef, {
            type: 'trip_resolved',
            title,
            body: renterMessage,
            bookingId: bookingId,
            isRead: false,
            isUnread: true,
            createdAt: now,
        });

        // 6. Notify host
        const hostNotifRef = adminDb.collection('users').doc(hostId).collection('notifications').doc();
        batch.set(hostNotifRef, {
            type: 'trip_resolved',
            title,
            body: hostMessage,
            bookingId: bookingId,
            isRead: false,
            isUnread: true,
            createdAt: now,
        });

        await batch.commit();

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error resolving claim:', error);
        return NextResponse.json({ error: 'Failed to resolve claim' }, { status: 500 });
    }
}
