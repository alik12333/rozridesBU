import { adminDb } from '@/lib/firebase-admin';
import { NextResponse } from 'next/server';

export async function GET() {
    try {
        const claimsSnap = await adminDb.collection('damageClaims')
            .orderBy('createdAt', 'desc')
            .limit(200)
            .get();

        const claims = await Promise.all(
            claimsSnap.docs.map(async (doc) => {
                const data = doc.data();

                // Fetch renter name
                let renterName = data.renterId ?? 'Unknown';
                let hostName = data.hostId ?? 'Unknown';
                try {
                    const renterSnap = await adminDb.collection('users').doc(data.renterId).get();
                    if (renterSnap.exists) renterName = renterSnap.data()?.fullName ?? renterName;
                    const hostSnap = await adminDb.collection('users').doc(data.hostId).get();
                    if (hostSnap.exists) hostName = hostSnap.data()?.fullName ?? hostName;
                } catch (_) {}

                return {
                    id: doc.id,
                    bookingId: data.bookingId,
                    carId: data.carId,
                    hostId: data.hostId,
                    renterId: data.renterId,
                    renterName,
                    hostName,
                    description: data.description,
                    hostClaimedDeduction: data.hostClaimedDeduction ?? 0,
                    renterAgreedDeduction: data.renterAgreedDeduction ?? 0,
                    status: data.status ?? 'open',
                    adminNotes: data.adminNotes ?? null,
                    mutualAmount: data.mutualAmount ?? null,
                    preInspectionRef: data.preInspectionRef,
                    postInspectionRef: data.postInspectionRef,
                    resolvedAt: data.resolvedAt?.toDate?.()?.toISOString() ?? null,
                    resolvedBy: data.resolvedBy ?? null,
                    createdAt: data.createdAt?.toDate?.()?.toISOString() ?? new Date().toISOString(),
                };
            })
        );

        return NextResponse.json(claims);
    } catch (error) {
        console.error('Error fetching claims:', error);
        return NextResponse.json({ error: 'Failed to fetch claims' }, { status: 500 });
    }
}
