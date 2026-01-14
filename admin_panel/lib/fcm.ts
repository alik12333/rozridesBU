import admin from './firebase-admin';

export interface NotificationPayload {
    title: string;
    body: string;
    data?: Record<string, string>;
}

export async function sendNotificationToUser(
    userId: string,
    payload: NotificationPayload
): Promise<boolean> {
    try {
        // Get user's FCM token from Firestore
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (!fcmToken) {
            console.warn(`No FCM token found for user ${userId}`);
            return false;
        }

        // Send notification
        const message = {
            notification: {
                title: payload.title,
                body: payload.body,
            },
            data: payload.data || {},
            token: fcmToken,
        };

        await admin.messaging().send(message);
        console.log(`✅ Notification sent to user ${userId}`);
        return true;
    } catch (error) {
        console.error(`❌ Error sending notification to user ${userId}:`, error);
        return false;
    }
}

export async function sendCNICApprovalNotification(userId: string, approved: boolean) {
    return sendNotificationToUser(userId, {
        title: approved ? 'CNIC Verified ✅' : 'CNIC Rejected ❌',
        body: approved
            ? 'Your CNIC has been verified successfully!'
            : 'Your CNIC verification was rejected. Please contact support.',
        data: {
            type: 'cnic_verification',
            status: approved ? 'approved' : 'rejected',
        },
    });
}

export async function sendListingApprovalNotification(
    userId: string,
    carName: string,
    approved: boolean
) {
    return sendNotificationToUser(userId, {
        title: approved ? 'Listing Approved ✅' : 'Listing Rejected ❌',
        body: approved
            ? `Your listing "${carName}" has been approved and is now live!`
            : `Your listing "${carName}" was rejected. Please review and resubmit.`,
        data: {
            type: 'listing_approval',
            status: approved ? 'approved' : 'rejected',
        },
    });
}
