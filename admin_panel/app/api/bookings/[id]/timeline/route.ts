import { NextResponse } from 'next/server';
import { getBookingTimeline } from '@/lib/firestore';

export const dynamic = 'force-dynamic';

export async function GET(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        const timeline = await getBookingTimeline(params.id);
        return NextResponse.json(timeline);
    } catch (error) {
        console.error('Error fetching booking timeline:', error);
        return NextResponse.json({ error: 'Failed to fetch timeline' }, { status: 500 });
    }
}
