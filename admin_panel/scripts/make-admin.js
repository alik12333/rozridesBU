const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// 1. Manually load .env.local
const envPath = path.resolve(__dirname, '../.env.local');
if (fs.existsSync(envPath)) {
    const envConfig = fs.readFileSync(envPath, 'utf8');
    envConfig.split('\n').forEach(line => {
        const [key, value] = line.split('=');
        if (key && value) {
            process.env[key.trim()] = value.trim();
        }
    });
}

// 2. Initialize Firebase Admin
if (!admin.apps.length) {
    try {
        const privateKey = process.env.FIREBASE_PRIVATE_KEY
            ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
            : undefined;

        if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIREBASE_CLIENT_EMAIL || !privateKey) {
            console.error('❌ Missing required environment variables (FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY)');
            console.error('Make sure .env.local exists in the project root.');
            process.exit(1);
        }

        admin.initializeApp({
            credential: admin.credential.cert({
                projectId: process.env.FIREBASE_PROJECT_ID,
                clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                privateKey: privateKey,
            }),
        });
        console.log('✅ Firebase Admin initialized');
    } catch (error) {
        console.error('❌ Initialization error:', error);
        process.exit(1);
    }
}

const db = admin.firestore();
const auth = admin.auth();

// 3. Main function
async function makeAdmin(email) {
    if (!email) {
        console.error('Usage: node scripts/make-admin.js <email>');
        process.exit(1);
    }

    try {
        console.log(`🔍 Looking for user with email: ${email}...`);
        const userRecord = await auth.getUserByEmail(email);
        const uid = userRecord.uid;
        console.log(`✅ Found user: ${uid}`);

        const userRef = db.collection('users').doc(uid);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
            console.log('⚠️ Firestore document does not exist. Creating basic admin profile...');
            await userRef.set({
                email: email,
                roles: {
                    isAdmin: true,
                    isOwner: false,
                    isRenter: false
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'active'
            });
        } else {
            console.log('🔄 Updating existing user profile...');
            await userRef.update({
                'roles.isAdmin': true,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        console.log(`
🎉 SUCCESS! 
User ${email} is now an ADMIN.
You can now login to the Admin Panel.
`);
        process.exit(0);

    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

// Run
const emailArg = process.argv[2];
makeAdmin(emailArg);
