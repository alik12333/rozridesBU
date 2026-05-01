import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';
import { FieldValue } from 'firebase-admin/firestore';

interface ResolveBody {
    bookingId: string;
    resolvedInFavorOf: 'host' | 'renter' | 'split' | 'extra';
    finalDeductionAmount: number;
    extraChargeAmount?: number;
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
    const {
        bookingId,
        resolvedInFavorOf,
        finalDeductionAmount,
        extraChargeAmount = 0,
        adminNotes,
        hostId,
        renterId,
        depositAmount = 0,
    } = body;

    if (!resolvedInFavorOf || finalDeductionAmount === undefined) {
        return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Validate 'extra' decision requires a positive extraChargeAmount
    if (resolvedInFavorOf === 'extra' && (!extraChargeAmount || extraChargeAmount <= 0)) {
        return NextResponse.json({ error: 'extraChargeAmount must be a positive number for extra decision' }, { status: 400 });
    }

    try {
        const claimRef = adminDb.collection('damageClaims').doc(claimId);
        const bookingRef = adminDb.collection('bookings').doc(bookingId);
        const bookingSnap = await bookingRef.get();

        if (!bookingSnap.exists) {
            return NextResponse.json({ error: 'Booking not found' }, { status: 404 });
        }

        const now = FieldValue.serverTimestamp();
        const batch = adminDb.batch();

        // 1. Update Claim to "decided" (NOT resolved yet)
        batch.update(claimRef, {
            status: 'decided',
            adminDecision: resolvedInFavorOf,
            resolvedInFavorOf,           // legacy field, kept for compatibility
            finalDeductionAmount,
            extraChargeAmount: resolvedInFavorOf === 'extra' ? extraChargeAmount : 0,
            requiresExtraPayment: resolvedInFavorOf === 'extra',
            adminNotes: adminNotes ?? null,
            hostConfirmed: false,
            renterConfirmed: false,
            hostConfirmedAt: null,
            renterConfirmedAt: null,
        });

        // 2. Booking stays "flagged" — do NOT change booking status yet.
        //    The trip closes only when both parties confirm.

        // 3. Timeline event
        const timelineRef = bookingRef.collection('timeline').doc();
        batch.set(timelineRef, {
            status: 'decided',
            note: `Admin posted decision: "${resolvedInFavorOf}". Awaiting confirmation from both parties.`,
            triggeredBy: 'admin',
            timestamp: now,
        });

        // 4. Build notification messages
        const depStr = `PKR ${depositAmount.toLocaleString()}`;
        const finStr = `PKR ${finalDeductionAmount.toLocaleString()}`;
        const retStr = `PKR ${(depositAmount - finalDeductionAmount).toLocaleString()}`;
        const extStr = `PKR ${extraChargeAmount.toLocaleString()}`;

        let hostMsg = '';
        let renterMsg = '';

        if (resolvedInFavorOf === 'renter') {
            hostMsg = `Admin Decision: Return ${depStr} to the renter in cash, then confirm in the app.`;
            renterMsg = `Admin Decision: Host must return ${depStr} to you. Confirm once received.`;
        } else if (resolvedInFavorOf === 'host') {
            hostMsg = `Admin Decision: Keep ${finStr}. Return ${retStr} to renter. Confirm in the app once done.`;
            renterMsg = `Admin Decision: Host keeps ${finStr}. You receive ${retStr}. Confirm once received.`;
        } else if (resolvedInFavorOf === 'split') {
            hostMsg = `Admin Decision: Keep ${finStr} (custom split). Return rest to renter. Confirm in app once done.`;
            renterMsg = `Admin Decision: Host keeps ${finStr}. You receive ${retStr}. Confirm once received.`;
        } else if (resolvedInFavorOf === 'extra') {
            hostMsg = `Admin Decision: Keep full ${depStr} deposit AND collect ${extStr} extra from renter. Confirm in app once renter pays.`;
            renterMsg = `Admin Decision: You owe ${extStr} extra to the host on top of losing your full deposit. Pay in cash and confirm in the app.`;
        }

        const title = 'Admin Decision Posted';

        // 5. Notify host
        const hostNotifRef = adminDb.collection('users').doc(hostId).collection('notifications').doc();
        batch.set(hostNotifRef, {
            type: 'dispute_decided',
            title,
            body: hostMsg,
            bookingId,
            isRead: false,
            isUnread: true,
            createdAt: now,
        });

        // 6. Notify renter
        const renterNotifRef = adminDb.collection('users').doc(renterId).collection('notifications').doc();
        batch.set(renterNotifRef, {
            type: 'dispute_decided',
            title,
            body: renterMsg,
            bookingId,
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
