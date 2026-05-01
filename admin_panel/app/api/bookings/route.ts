import { NextResponse } from 'next/server';
import { getAllBookings } from '@/lib/firestore';

export const dynamic = 'force-dynamic';

export async function GET() {
    try {
        const bookings = await getAllBookings();
        return NextResponse.json(bookings);
    } catch (error) {
        console.error('Error fetching bookings:', error);
        return NextResponse.json({ error: 'Failed to fetch bookings' }, { status: 500 });
    }
}
