import admin from 'firebase-admin';

if (!admin.apps.length) {
    try {
        // Load credentials from environment variables (secure)
        const projectId = process.env.FIREBASE_PROJECT_ID;
        const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
        const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

        // Validate required environment variables
        if (!projectId || !clientEmail || !privateKey) {
            throw new Error(
                'Missing required Firebase Admin environment variables. ' +
                'Please set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY in .env.local'
            );
        }

        admin.initializeApp({
            credential: admin.credential.cert({
                projectId,
                clientEmail,
                privateKey,
            }),
        });

        console.log('✅ Firebase Admin initialized with environment variables');
    } catch (error) {
        console.error('❌ Firebase Admin initialization error:', error);
        throw error;
    }
}

export const adminAuth = admin.auth();
export const adminDb = admin.firestore();
export const adminStorage = admin.storage();

export default admin;
