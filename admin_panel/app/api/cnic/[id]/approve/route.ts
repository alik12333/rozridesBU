import { NextResponse } from 'next/server';
import { updateCNICStatus } from '@/lib/firestore';
import { sendCNICApprovalNotification } from '@/lib/fcm';

export async function POST(
    request: Request,
    { params }: { params: { id: string } }
) {
    try {
        const userId = params.id;

        await updateCNICStatus(userId, 'approved');

        // Send notification
        await sendCNICApprovalNotification(userId, true);

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error('Error approving CNIC:', error);
        return NextResponse.json({ 
            error: 'Failed to approve CNIC', 
            details: error instanceof Error ? error.message : String(error) 
        }, { status: 500 });
    }
}
