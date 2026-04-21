import { NextResponse } from 'next/server';
import { forceCancelBooking } from '@/lib/firestore';

export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        const body = await request.json();
        const { reason } = body;
        
        if (!reason) {
            return NextResponse.json({ error: 'Reason is required' }, { status: 400 });
        }

        await forceCancelBooking(params.id, reason);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error force-cancelling booking:', error);
        return NextResponse.json({ error: 'Failed to cancel booking' }, { status: 500 });
    }
}
