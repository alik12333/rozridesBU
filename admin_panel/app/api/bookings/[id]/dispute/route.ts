import { NextResponse } from 'next/server';
import { markBookingDisputed } from '@/lib/firestore';

export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        await markBookingDisputed(params.id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error marking booking as disputed:', error);
        return NextResponse.json({ error: 'Failed to mark as disputed' }, { status: 500 });
    }
}
