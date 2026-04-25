import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';
import { FieldValue } from 'firebase-admin/firestore';

interface ResolveBody {
    resolution: 'resolved_for_host' | 'resolved_for_renter' | 'resolved_mutually';
    adminNotes?: string;
    mutualAmount?: number;
    adminId?: string;
}

export async function POST(
    request: Request,
    { params }: { params: { claimId: string } }
) {
    const { claimId } = params;
    const body: ResolveBody = await request.json();
    const { resolution, adminNotes, mutualAmount, adminId } = body;

    if (!resolution) {
        return NextResponse.json({ error: 'resolution is required' }, { status: 400 });
    }

    try {
        const claimRef = adminDb.collection('damageClaims').doc(claimId);
        const claimSnap = await claimRef.get();

        if (!claimSnap.exists) {
            return NextResponse.json({ error: 'Claim not found' }, { status: 404 });
        }

        const claim = claimSnap.data()!;
        const now = FieldValue.serverTimestamp();
        const batch = adminDb.batch();

        // 1. Update claim status
        batch.update(claimRef, {
            status: resolution,
            adminNotes: adminNotes ?? null,
            mutualAmount: mutualAmount ?? null,
            resolvedAt: now,
            resolvedBy: adminId ?? 'admin',
        });

        // 2. If booking was disputed, revert to completed
        const bookingRef = adminDb.collection('bookings').doc(claim.bookingId);
        const bookingSnap = await bookingRef.get();
        if (bookingSnap.exists && bookingSnap.data()?.status === 'disputed') {
            batch.update(bookingRef, {
                status: 'completed',
                updatedAt: now,
            });

            // Timeline event
            const timelineRef = bookingRef.collection('timeline').doc();
            batch.set(timelineRef, {
                status: 'completed',
                note: `Dispute resolved by admin. Resolution: ${resolution.replace(/_/g, ' ')}.${adminNotes ? ` Notes: ${adminNotes}` : ''}`,
                triggeredBy: adminId ?? 'admin',
                timestamp: now,
            });
        }

        // 3. Resolve message per outcome
        const renterMessage =
            resolution === 'resolved_for_host'
                ? 'The admin has reviewed your dispute and resolved it in favor of the host. The agreed deduction will be applied.'
                : resolution === 'resolved_for_renter'
                ? 'The admin has reviewed your dispute and resolved it in your favor. No additional deduction will be applied.'
                : `The admin has resolved the dispute mutually. A deduction of PKR ${mutualAmount ?? 0} has been agreed upon.`;

        const hostMessage =
            resolution === 'resolved_for_host'
                ? 'The admin has reviewed the dispute and resolved it in your favor. Your claimed deduction has been upheld.'
                : resolution === 'resolved_for_renter'
                ? 'The admin has reviewed the dispute and resolved it in favor of the renter.'
                : `The admin has resolved the dispute mutually. A deduction of PKR ${mutualAmount ?? 0} has been agreed upon.`;

        // 4. Notify renter
        const renterNotifRef = adminDb
            .collection('users')
            .doc(claim.renterId)
            .collection('notifications')
            .doc();
        batch.set(renterNotifRef, {
            type: 'dispute_resolved',
            title: 'Dispute Resolved',
            body: renterMessage,
            bookingId: claim.bookingId,
            isRead: false,
            isUnread: true,
            createdAt: now,
        });

        // 5. Notify host
        const hostNotifRef = adminDb
            .collection('users')
            .doc(claim.hostId)
            .collection('notifications')
            .doc();
        batch.set(hostNotifRef, {
            type: 'dispute_resolved',
            title: 'Dispute Resolved',
            body: hostMessage,
            bookingId: claim.bookingId,
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
