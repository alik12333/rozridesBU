import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * POST /api/claims/[claimId]/force-close
 *
 * Admin override: closes a flagged trip without waiting for both parties to confirm.
 * Only usable when claim is in "decided" state and one/both parties have not confirmed.
 */
export async function POST(
    request: Request,
    { params }: { params: { claimId: string } }
) {
    const { claimId } = params;
    const body = await request.json();
    const { bookingId, adminReason } = body as { bookingId: string; adminReason?: string };

    if (!bookingId) {
        return NextResponse.json({ error: 'bookingId is required' }, { status: 400 });
    }

    try {
        const claimRef = adminDb.collection('damageClaims').doc(claimId);
        const bookingRef = adminDb.collection('bookings').doc(bookingId);

        const [claimSnap, bookingSnap] = await Promise.all([claimRef.get(), bookingRef.get()]);

        if (!claimSnap.exists) {
            return NextResponse.json({ error: 'Claim not found' }, { status: 404 });
        }
        if (!bookingSnap.exists) {
            return NextResponse.json({ error: 'Booking not found' }, { status: 404 });
        }

        const claimData = claimSnap.data()!;
        const bookingData = bookingSnap.data()!;

        if (claimData.status !== 'decided') {
            return NextResponse.json({ error: 'Claim must be in "decided" state to force close' }, { status: 400 });
        }

        const now = FieldValue.serverTimestamp();
        const batch = adminDb.batch();
        const reason = adminReason ?? 'Admin manually closed the trip.';

        // 1. Mark claim resolved
        batch.update(claimRef, {
            status: 'resolved',
            resolvedAt: now,
            forceClosedByAdmin: true,
            forceCloseReason: reason,
        });

        // 2. Mark booking completed
        batch.update(bookingRef, {
            status: 'completed',
            updatedAt: now,
        });

        // 3. Remove blocked date range from car
        const { carId, startDate, endDate } = bookingData;
        if (carId && startDate && endDate) {
            const carRef = adminDb.collection('listings').doc(carId);
            batch.update(carRef, {
                bookedDateRanges: FieldValue.arrayRemove({
                    start: startDate,
                    end: endDate,
                    bookingId,
                }),
            });
        }

        // 4. Timeline entry
        const timelineRef = bookingRef.collection('timeline').doc();
        batch.set(timelineRef, {
            status: 'completed',
            note: `Admin force-closed this trip. ${reason}`,
            triggeredBy: 'admin',
            timestamp: now,
        });

        // 5. Notify both parties
        const { hostId, renterId } = claimData;
        const notifPayload = {
            type: 'trip_force_closed',
            title: 'Trip Closed by Admin',
            body: `RozRides has manually closed this trip. ${reason}`,
            bookingId,
            isRead: false,
            isUnread: true,
            createdAt: now,
        };

        if (hostId) {
            const hostNotif = adminDb.collection('users').doc(hostId).collection('notifications').doc();
            batch.set(hostNotif, notifPayload);
        }
        if (renterId) {
            const renterNotif = adminDb.collection('users').doc(renterId).collection('notifications').doc();
            batch.set(renterNotif, notifPayload);
        }

        await batch.commit();

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error force-closing claim:', error);
        return NextResponse.json({ error: 'Failed to force close claim' }, { status: 500 });
    }
}
