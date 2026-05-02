# RozRides Project Guidelines 🚗

This document contains foundations, architecture rules, and engineering standards for the RozRides platform.

## 🏗️ Architecture Overview

RozRides is a peer-to-peer car rental platform comprising:
- **Mobile App**: Built with Flutter (iOS/Android). Uses the **Provider** pattern for state management.
- **Admin Panel**: Built with Next.js 14 (App Router) and Tailwind CSS.
- **Backend**: Powered by Firebase (Firestore, Storage, Auth, Cloud Messaging).

---

## 🎨 Design DNA & UI Standards

Consistency is critical for the RozRides brand. Follow these standards for all new UI components:

### 1. Typography & Colors
- **Font**: Always prefer **GoogleFonts.outfit** for headers and primary labels. Use **Inter** for long-form body text.
- **Primary Color**: `#7C3AED` (Vibrant Purple).
- **Secondary Colors**: 
  - Success/Approved: `#10B981` (Emerald Green).
  - Warning/Pending: `#F59E0B` (Amber).
  - Error/Rejected: `#EF4444` (Red).
- **Background**: Use `#F7F8FC` for screen backgrounds to provide a soft contrast against white cards.

### 2. UI Patterns
- **Explicit Navigation**: Always include an explicit `BackButton(color: Colors.black)` in the `AppBar` leading property. Do not rely solely on system back gestures.
- **Card-Based Layouts**: Use rounded containers (`borderRadius: 24` or `28`) with soft shadows (`blurRadius: 20`, low opacity black) to group related information.
- **Interactive Feedback**: Add subtle animations (e.g., `AnimatedContainer`, `AnimatedScale`) to buttons and selectors.

---

## 💻 Engineering Standards (Mobile)

### 1. Data Modeling
- Every collection must have a corresponding model class in `lib/models/`.
- Models must implement `fromMap(Map<String, dynamic> map, String id)` and `toMap()`.
- Use **denormalization** strategically (e.g., storing `carName` and `carPhoto` in a `BookingModel`) to minimize read costs.

### 2. Service Layer
- Business logic and Firebase SDK calls must be encapsulated in `lib/services/`.
- UI should only interact with **Providers**, which in turn call the **Services**.
- Always check `mounted` status before calling `Navigator` or `ScaffoldMessenger` after an `await` block.

---

## 🔐 Security & Data Privacy

### 1. Sensitive Data
- Certain vehicle details, like **Car Number**, are restricted. These must be marked as `Private` in UI labels and only accessible to administrators via the Admin Panel.
- Public search results must never expose precise location pins until a booking is confirmed. Use a 500m radius circle or general area labels.

### 2. Admin Oversight
- All high-privilege operations (Listing Approval, Dispute Resolution, User Banning) must be performed via the **Admin Panel** using the `firebase-admin` SDK.

---

## 🛠️ Workflows

### 1. The Booking Lifecycle
1.  **Request**: Renter submits request.
2.  **Confirmation**: Host accepts; auto-declines overlapping pending requests.
3.  **Handover**: Host performs Pre-Trip photo inspection; renter starts trip.
4.  **Return**: Host performs Post-Trip inspection; proposes cash settlement.
5.  **Completion**: Renter confirms settlement; trip closes.

### 2. Dispute Resolution
- If a renter disagrees with a deduction, the trip is **Flagged**.
- Admins review inspection photos and chat history in the dashboard to issue a final decision.
- All settlements are handled in **Cash** at handover/return.

---

## 📦 Deployment
- **Admin Panel**: Deployed on Vercel. Ensure `npm run lint` and `npx tsc --noEmit` pass locally before pushing to `main`.
- **Mobile**: Flutter build should maintain 0 analysis issues.
