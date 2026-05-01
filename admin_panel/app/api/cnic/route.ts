import { NextResponse } from 'next/server';
import { getAllUsers } from '@/lib/firestore';

export const dynamic = 'force-dynamic';

export async function GET() {
    try {
        const users = await getAllUsers();

        // Filter users who have CNIC data
        const cnicData = users
            .filter((user) => user.cnic && user.cnic.number)
            .map((user) => ({
                id: user.id,
                fullName: user.fullName,
                email: user.email,
                cnic: user.cnic,
            }));

        return NextResponse.json(cnicData);
    } catch (error) {
        console.error('Error fetching CNIC data:', error);
        return NextResponse.json({ error: 'Failed to fetch CNIC data' }, { status: 500 });
    }
}
