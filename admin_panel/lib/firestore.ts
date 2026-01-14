import { adminDb } from './firebase-admin';
import admin from 'firebase-admin';

export interface User {
    id: string;
    fullName: string;
    email: string;
    phoneNumber: string;
    profilePhoto?: string | null;
    cnic?: {
        number: string;
        frontImage?: string;
        backImage?: string;
        verificationStatus: 'pending' | 'approved' | 'rejected';
    } | null;
    location?: string | null;
    createdAt: Date;
    updatedAt: Date;
    status: string;
    roles: {
        isRenter: boolean;
        isOwner: boolean;
    };
    fcmToken?: string;
}

export interface Listing {
    id: string;
    ownerId: string;
    ownerName: string;
    ownerPhone: string;
    carName: string;
    brand: string;
    model: string;
    year: number;
    pricePerDay: number;
    engineSize: string;
    mileage: number;
    fuelType: string;
    transmission: string;
    description: string;
    withDriver: boolean;
    hasInsurance: boolean;
    images: string[];
    status: 'pending' | 'approved' | 'rejected';
    createdAt: Date;
    updatedAt: Date;
    city?: string;
    area?: string;
}

// Fetch all users
export async function getAllUsers(): Promise<User[]> {
    try {
        const snapshot = await adminDb.collection('users').orderBy('createdAt', 'desc').get();
        return snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate() || new Date(),
            updatedAt: doc.data().updatedAt?.toDate() || new Date(),
        })) as User[];
    } catch (error) {
        console.error('Error fetching users:', error);
        return [];
    }
}

// Fetch all listings
export async function getAllListings(): Promise<Listing[]> {
    try {
        const snapshot = await adminDb.collection('listings').orderBy('createdAt', 'desc').get();
        return snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate() || new Date(),
            updatedAt: doc.data().updatedAt?.toDate() || new Date(),
        })) as Listing[];
    } catch (error) {
        console.error('Error fetching listings:', error);
        return [];
    }
}

// Add a notification to a user's notification collection
export async function addNotification(
    userId: string,
    notification: {
        title: string;
        message: string;
        type: 'info' | 'success' | 'warning' | 'error';
    }
): Promise<void> {
    try {
        await adminDb.collection('users').doc(userId).collection('notifications').add({
            ...notification,
            isUnread: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
        console.error('Error adding notification:', error);
    }
}

// Update CNIC verification status
export async function updateCNICStatus(
    userId: string,
    status: 'approved' | 'rejected'
): Promise<void> {
    await adminDb.collection('users').doc(userId).update({
        'cnic.verificationStatus': status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notification
    const title = status === 'approved' ? 'Profile Verified' : 'Profile Verification Failed';
    const message = status === 'approved'
        ? 'Your specific verification has been approved. You can now list and rent cars.'
        : 'Your profile verification was rejected. Please check your details and try again.';
    const type = status === 'approved' ? 'success' : 'error';

    await addNotification(userId, { title, message, type });
}

// Update listing status
export async function updateListingStatus(
    listingId: string,
    status: 'approved' | 'rejected'
): Promise<void> {
    const listingRef = adminDb.collection('listings').doc(listingId);

    // Get listing to find owner
    const doc = await listingRef.get();
    if (!doc.exists) return;

    const listingData = doc.data() as Listing;
    const ownerId = listingData.ownerId;

    await listingRef.update({
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (ownerId) {
        const title = status === 'approved' ? 'Listing Approved' : 'Listing Rejected';
        const message = status === 'approved'
            ? `Your listing for ${listingData.year} ${listingData.brand} ${listingData.model} has been approved.`
            : `Your listing for ${listingData.year} ${listingData.brand} ${listingData.model} was rejected.`;
        const type = status === 'approved' ? 'success' : 'error';

        await addNotification(ownerId, { title, message, type });
    }
}

// Get dashboard stats
export async function getDashboardStats() {
    try {
        const [usersSnapshot, listingsSnapshot] = await Promise.all([
            adminDb.collection('users').get(),
            adminDb.collection('listings').get(),
        ]);

        const users = usersSnapshot.docs.map(doc => doc.data());
        const listings = listingsSnapshot.docs.map(doc => doc.data());

        return {
            totalUsers: users.length,
            totalListings: listings.length,
            pendingListings: listings.filter(l => l.status === 'pending').length,
            approvedListings: listings.filter(l => l.status === 'approved').length,
            rejectedListings: listings.filter(l => l.status === 'rejected').length,
            verifiedUsers: users.filter(u => u.cnic?.verificationStatus === 'approved').length,
            pendingCNIC: users.filter(u => u.cnic?.verificationStatus === 'pending').length,
            rejectedCNIC: users.filter(u => u.cnic?.verificationStatus === 'rejected').length,
        };
    } catch (error) {
        console.error('Error fetching dashboard stats:', error);
        return {
            totalUsers: 0,
            totalListings: 0,
            pendingListings: 0,
            approvedListings: 0,
            rejectedListings: 0,
            verifiedUsers: 0,
            pendingCNIC: 0,
            rejectedCNIC: 0,
        };
    }
}
