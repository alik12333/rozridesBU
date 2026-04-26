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
        isAdmin?: boolean;
    };
    fcmToken?: string;
    // Reputation & Strikes
    renterRating?: number;
    renterTrips?: number;
    hostRating?: number;
    hostTrips?: number;
    strikes?: {
        lateCancellations?: number;
        damage_incidents?: number;
        disputed_deposits?: number;
    };
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

// Fetch a single user
export async function getUser(userId: string): Promise<User | null> {
    try {
        const doc = await adminDb.collection('users').doc(userId).get();
        if (!doc.exists) return null;
        
        return {
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data()?.createdAt?.toDate() || new Date(),
            updatedAt: doc.data()?.updatedAt?.toDate() || new Date(),
        } as User;
    } catch (error) {
        console.error('Error fetching user:', error);
        return null;
    }
}

// Ban User
export async function banUser(userId: string): Promise<void> {
    try {
        await adminDb.collection('users').doc(userId).update({
            status: 'banned',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        await addNotification(userId, {
            title: 'Account Banned',
            message: 'Your account has been banned due to multiple policy violations.',
            type: 'error'
        });
    } catch (error) {
        console.error('Error banning user:', error);
        throw error;
    }
}

// Fetch all admins
export async function getAdmins(): Promise<User[]> {
    try {
        const snapshot = await adminDb.collection('users')
            .where('role', 'in', ['admin', 'super_admin'])
            .get();
            
        // Legacy support
        const legacySnapshot = await adminDb.collection('users')
            .where('roles.isAdmin', '==', true)
            .get();

        const allDocs = new Map();
        [...snapshot.docs, ...legacySnapshot.docs].forEach(doc => {
            allDocs.set(doc.id, doc);
        });

        return Array.from(allDocs.values()).map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate() || new Date(),
            updatedAt: doc.data().updatedAt?.toDate() || new Date(),
        })) as User[];
    } catch (error) {
        console.error('Error fetching admins:', error);
        return [];
    }
}

// Revoke admin access
export async function revokeAdmin(userId: string): Promise<void> {
    try {
        await adminDb.collection('users').doc(userId).update({
            role: 'user',
            'roles.isAdmin': false
        });
    } catch (error) {
        console.error('Error revoking admin access:', error);
        throw error;
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
        const [usersSnapshot, listingsSnapshot, bookingsSnapshot, claimsSnapshot] = await Promise.all([
            adminDb.collection('users').get(),
            adminDb.collection('listings').get(),
            adminDb.collection('bookings').get(),
            adminDb.collection('damageClaims').get(),
        ]);

        const users = usersSnapshot.docs.map(doc => doc.data());
        const listings = listingsSnapshot.docs.map(doc => doc.data());
        const bookings = bookingsSnapshot.docs.map(doc => doc.data());
        const claims = claimsSnapshot.docs.map(doc => doc.data());

        return {
            totalUsers: users.length,
            totalListings: listings.length,
            pendingListings: listings.filter(l => l.status === 'pending').length,
            approvedListings: listings.filter(l => l.status === 'approved').length,
            rejectedListings: listings.filter(l => l.status === 'rejected').length,
            verifiedUsers: users.filter(u => u.cnic?.verificationStatus === 'approved').length,
            pendingCNIC: users.filter(u => u.cnic?.verificationStatus === 'pending').length,
            rejectedCNIC: users.filter(u => u.cnic?.verificationStatus === 'rejected').length,
            activeTrips: bookings.filter(b => b.status === 'active').length,
            openDisputes: claims.filter(c => c.status === 'open').length,
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
            activeTrips: 0,
            openDisputes: 0,
        };
    }
}

// ──────────────────────── BOOKINGS & TIMELINE ─────────────────────────────

export interface BookingTimelineEvent {
    id: string;
    status: string;
    note: string;
    triggeredBy: string;
    timestamp: Date;
}

export interface Booking {
    id: string;
    carId: string;
    hostId: string;
    renterId: string;
    renterName: string;
    carName: string;
    startDate: Date;
    endDate: Date;
    totalDays: number;
    pricePerDay: number;
    totalAmount: number;
    securityDeposit: number;
    status: 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled' | 'rejected' | 'expired' | 'disputed';
    cancellationReason?: string;
    declineReason?: string;
    createdAt: Date;
    updatedAt: Date;
    expiresAt: Date;
    // Loaded artificially in the query hook for UI display
    hostName?: string;
}

// Fetch all bookings
export async function getAllBookings(): Promise<Booking[]> {
    try {
        const snapshot = await adminDb.collection('bookings').orderBy('createdAt', 'desc').get();
        return snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                startDate: data.startDate?.toDate() || new Date(),
                endDate: data.endDate?.toDate() || new Date(),
                createdAt: data.createdAt?.toDate() || new Date(),
                updatedAt: data.updatedAt?.toDate() || new Date(),
                expiresAt: data.expiresAt?.toDate() || new Date(),
            };
        }) as Booking[];
    } catch (error) {
        console.error('Error fetching bookings:', error);
        return [];
    }
}

// Fetch timeline events for a specific booking
export async function getBookingTimeline(bookingId: string): Promise<BookingTimelineEvent[]> {
    try {
        const snapshot = await adminDb
            .collection('bookings')
            .doc(bookingId)
            .collection('timeline')
            .orderBy('timestamp', 'desc')
            .get();
            
        return snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                ...data,
                timestamp: data.timestamp?.toDate() || new Date(),
            };
        }) as BookingTimelineEvent[];
    } catch (error) {
        console.error(`Error fetching timeline for booking ${bookingId}:`, error);
        return [];
    }
}

// Admin: Force-cancel a booking
export async function forceCancelBooking(bookingId: string, reason: string): Promise<void> {
    const bookingRef = adminDb.collection('bookings').doc(bookingId);
    const doc = await bookingRef.get();
    if (!doc.exists) throw new Error('Booking not found');
    const booking = doc.data();
    
    const batch = adminDb.batch();

    // 1. Update Booking
    batch.update(bookingRef, {
        status: 'cancelled',
        cancellationReason: `[ADMIN] ${reason}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Timeline string
    const timelineRef = bookingRef.collection('timeline').doc();
    batch.set(timelineRef, {
        status: 'cancelled',
        note: `Admin force-cancelled booking. Reason: ${reason}`,
        triggeredBy: 'admin',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 3. Optional: Add a notification for host and renter
    if (booking?.hostId) {
        await addNotification(booking.hostId, {
            title: 'Booking Force-Cancelled',
            message: `Admin cancelled the booking for ${booking.carName}. Reason: ${reason}`,
            type: 'error'
        });
    }
    if (booking?.renterId) {
         await addNotification(booking.renterId, {
            title: 'Booking Force-Cancelled',
            message: `Admin cancelled your booking for ${booking.carName}. Reason: ${reason}`,
            type: 'error'
        });
    }
}

// Admin: Mark booking as disputed
export async function markBookingDisputed(bookingId: string): Promise<void> {
     const bookingRef = adminDb.collection('bookings').doc(bookingId);
    
    const batch = adminDb.batch();

    batch.update(bookingRef, {
        status: 'disputed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const timelineRef = bookingRef.collection('timeline').doc();
    batch.set(timelineRef, {
        status: 'disputed',
        note: `Admin marked this booking as Disputed for investigation.`,
        triggeredBy: 'admin',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
}

// ──────────────────────── REVIEWS MODERATION ─────────────────────────────

export interface Review {
    id: string;
    bookingId: string;
    carId?: string;
    reviewerId: string;
    reviewerName: string;
    revieweeId: string;
    type: string;
    overallRating: number;
    comment: string;
    isPublic: boolean;
    flagged?: boolean;
    createdAt: Date;
}

export async function getFlaggedReviews(): Promise<Review[]> {
    try {
        const snapshot = await adminDb.collection('reviews')
            .where('flagged', '==', true)
            .orderBy('createdAt', 'desc')
            .get();
        return snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            createdAt: doc.data().createdAt?.toDate() || new Date(),
        })) as Review[];
    } catch (error) {
        console.error('Error fetching flagged reviews:', error);
        return [];
    }
}

export async function dismissReviewFlag(reviewId: string): Promise<void> {
    await adminDb.collection('reviews').doc(reviewId).update({
        flagged: false,
    });
}

export async function deleteReview(reviewId: string): Promise<void> {
    const batch = adminDb.batch();
    
    // 1. Delete the review
    const reviewRef = adminDb.collection('reviews').doc(reviewId);
    batch.delete(reviewRef);

    // Note: The recalculation of aggregate scores for users/cars should ideally
    // be handled via a Firebase Cloud Function (e.g. onReviewDeleted trigger).
    // For now, we are just deleting the document.

    await batch.commit();
}
