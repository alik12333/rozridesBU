# RozRides Admin Panel - Setup Instructions

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd admin_panel
npm install
```

### 2. Configure Environment Variables

Copy the example file and fill in your Firebase credentials:
```bash
copy .env.local.example .env.local
```

Get your Firebase config from:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings > General
4. Scroll to "Your apps" and select/create a web app
5. Copy the config values to `.env.local`

### 3. Create Admin User

You need to create an admin user in Firebase:

1. Go to Firebase Console > Authentication
2. Add a new user with email/password
3. Copy the user's UID
4. Go to Firestore Database
5. Create a new collection called `admins`
6. Add a document with the UID as the document ID
7. Add a field: `email: "your-admin@email.com"`

### 4. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

If you don't have Firebase CLI:
```bash
npm install -g firebase-tools
firebase login
firebase init firestore
firebase deploy --only firestore:rules
```

### 5. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## 📋 Features

✅ **Admin Authentication** - Secure login with Firebase Auth  
✅ **Dashboard** - Statistics and quick actions  
✅ **User Management** - View all users and their status  
✅ **CNIC Verification** - Approve/reject CNIC documents with image preview  
✅ **Listing Management** - Approve/reject car listings  
✅ **Push Notifications** - Automatic FCM notifications on approval/rejection  
✅ **Responsive Design** - Works on desktop and mobile  
✅ **Type-Safe** - Full TypeScript support  

## 🔒 Security

- Only authenticated admins can access the panel
- Firestore rules enforce admin-only updates to verification statuses
- Service account key is gitignored

## 🛠️ Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: TailwindCSS
- **UI Components**: ShadCN UI
- **Backend**: Firebase Admin SDK
- **Auth**: Firebase Authentication
- **Database**: Cloud Firestore
- **Notifications**: Firebase Cloud Messaging

## 📁 Project Structure

```
admin_panel/
├── app/
│   ├── api/              # API routes
│   ├── dashboard/        # Dashboard pages
│   ├── login/            # Login page
│   └── layout.tsx        # Root layout
├── components/
│   └── ui/               # ShadCN UI components
├── lib/
│   ├── firebase-admin.ts # Firebase Admin SDK
│   ├── firebase-client.ts# Firebase Client SDK
│   ├── firestore.ts      # Database utilities
│   ├── fcm.ts            # Notification utilities
│   └── utils.ts          # Helper functions
├── firestore.rules       # Security rules
└── serviceAccountKey.json# Firebase service account
```

## 🧪 Testing

1. **Login**: Use your admin credentials
2. **Dashboard**: Verify statistics are displayed
3. **Users**: Check user list loads
4. **CNIC**: Approve/reject a CNIC and verify notification
5. **Listings**: Approve/reject a listing and verify notification

## 🚢 Production Deployment

```bash
npm run build
npm start
```

Or deploy to Vercel:
```bash
vercel deploy
```

## 📝 Notes

- The `serviceAccountKey.json` file is already configured
- Make sure to add your admin UID to the `admins` collection in Firestore
- FCM notifications require users to have `fcmToken` field in their Firestore document
