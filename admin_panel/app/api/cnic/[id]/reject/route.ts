import { NextResponse } from 'next/server';
import { updateCNICStatus } from '@/lib/firestore';
import { sendCNICApprovalNotification } from '@/lib/fcm';

export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        const userId = params.id;

        await updateCNICStatus(userId, 'rejected');

        // Send notification
        await sendCNICApprovalNotification(userId, false);

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error rejecting CNIC:', error);
        return NextResponse.json({ 
            error: 'Failed to reject CNIC', 
            details: error instanceof Error ? error.message : String(error) 
        }, { status: 500 });
    }
}
