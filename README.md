# RozRides 🚗

**RozRides** is a comprehensive, peer-to-peer car rental platform tailored for Pakistan. It seamlessly connects car owners (hosts) with individuals looking to rent vehicles, providing a robust ecosystem for browsing, booking, messaging, and managing rentals.

## 🌟 Key Features

### For Renters
* **Map-Based Search & Discovery:** Find available cars nearby using interactive maps (powered by Google Maps & Geolocator).
* **Detailed Listings:** View car details, high-quality images, pricing breakdowns, and host reviews.
* **Seamless Booking:** Easy booking flow with real-time availability and transparent pricing (including cash settlements).
* **Trip Management:** Comprehensive trip lifecycle management including Pre-Trip and Post-Trip inspections, damage claims, and cancellations.
* **In-App Messaging:** Communicate directly with hosts securely within the app.
* **Reviews & Ratings:** Leave feedback after completing trips to build community trust.

### For Hosts (Car Owners)
* **Easy Listing Management:** Add new vehicles, set locations, and manage availability.
* **Booking Dashboard:** Review incoming requests, accept/decline bookings, and track upcoming reservations.
* **Asset Protection:** Mandatory pre-trip and post-trip photo inspections, along with integrated damage claims and flag systems.
* **Earnings Management:** Track bookings and cash settlements easily.

### Admin Panel (Web)
* **User & Listing Management:** Full overview of users, CNIC verifications, and vehicle listings.
* **Dispute Resolution:** Handle flagged trips, damage claims, and booking cancellations.
* **Platform Health:** Tools to monitor activity, approve/reject user roles, and ban misbehaving accounts.

## 🛠 Tech Stack

**Mobile Application:**
* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **State Management:** Provider
* **Backend as a Service (BaaS):** Firebase (Auth, Cloud Firestore, Cloud Storage)
* **Mapping & Location:** Google Maps Flutter, Geolocator, Geoflutterfire Plus
* **Design:** Custom AppTheme with Google Fonts

**Admin Web Portal:**
* **Framework:** Next.js (TypeScript/React)
* **Backend Integration:** Firebase Admin SDK (via serverless API routes)

## 🗺 System Architecture (Graphify Insights)
Based on our project graph analysis:
* **Core Abstractions:** The app relies heavily on a solid foundation of Providers (`AuthProvider`, `BookingProvider`, `ChatProvider`) and Services (`AuthService`, `BookingService`, `ListingService`) connecting directly to `Cloud Firestore`.
* **Booking Lifecycle:** The `BookingModel` is the central hub, intersecting with `PreTripInspection`, `PostTripInspection`, `DamageClaim`, and `Review` flows.
* **Modular Communities:** Features are well-segmented into functional communities such as *Search/Location*, *Chat/Messaging*, *Host Dashboard*, and *Admin Utilities*.

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
* [Node.js](https://nodejs.org/) (for running the Admin Panel)
* Android Studio or Xcode (for emulation/compilation)
* A Firebase project configured with Auth, Firestore, and Storage.

### Installation (Mobile App)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/alik12333/rozridesBU.git
   cd rozridesBU
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Ensure you have your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in their respective directories. You may need to run `flutterfire configure`.

4. **Run the app:**
   ```bash
   flutter run
   ```

### Installation (Admin Panel)

1. **Navigate to the admin portal directory:**
   ```bash
   cd admin_panel
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up Environment Variables:**
   Create a `.env.local` file in the `admin_panel` directory containing your Firebase service account credentials and config.

4. **Run the local development server:**
   ```bash
   npm run dev
   ```
   Access the dashboard at `http://localhost:3000` (or `3001` if configured differently).

## 📂 Project Structure

```text
rozridesBU/
├── lib/
│   ├── core/         # Theming, constants, and shared utilities
│   ├── models/       # Data classes (UserModel, BookingModel, ListingModel, etc.)
│   ├── providers/    # State management providers
│   ├── screens/      # UI screens divided by features (booking, host, trip, search, etc.)
│   └── services/     # Firebase interaction logic
├── admin_panel/      # Next.js web application for platform administration
├── test/             # Unit and widget tests
└── ios/ & android/   # Platform-specific native configurations
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:
1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📄 License
This project is proprietary. All rights reserved.

---
*Generated & maintained with ❤️ by the RozRides Team.*
