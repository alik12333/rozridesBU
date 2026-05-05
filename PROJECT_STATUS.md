# RozRides Project Status Report
**Date:** May 4, 2026

---

## 1. PROJECT OVERVIEW
- **Mobile App:** Flutter (Dart) - Car rental platform
- **Admin Panel:** Next.js 14 (TypeScript) - Moderation & dispute management
- **Backend:** Firebase (Auth, Firestore, Storage, Messaging)

---

## 2. KEY COLLECTIONS & DATA MODEL

### Users
- fullName, email, phoneNumber, profilePhoto
- CNIC: {number, frontImage, backImage, verificationStatus: pending|approved|rejected}
- Roles: {isOwner, isAdmin}
- Ratings: renterRating, hostRating (with review counts)

### Listings
- Car details: carName, brand, model, year, pricePerDay, engineSize, mileage
- Status: draft|pending|approved|rejected|inactive
- Location: city, area, GeoPoint, geohash (for geo-queries)
- bookedDateRanges, averageRating, ratingBreakdown

### Bookings (Complete Lifecycle)
- Status flow: pending (24h) → confirmed → active → completed/cancelled/rejected/expired
- Tracks: carId, hostId, renterId, startDate, endDate, pricing, messages
- cashPayments: {depositPaid, rentPaid, depositRefunded, damageDeduction}
- reviewStatus: {renterSubmitted, hostSubmitted}
- preHandoverCompleted, postHandoverCompleted, proposedSettlement

### Inspections
- PreTripInspection: depositCollected, fuelLevel, odometerReading, items (5 areas with photos), signatures
- PostTripInspection: returnConfirmedAt, fuelLevel, odometerReading, newDamageAreas, kmDriven
- Photos uploaded to Storage: inspections/{bookingId}/{pre|post}_trip/{area}_{timestamp}.jpg

### Reviews
- type: renter_to_host | host_to_renter
- overallRating (1-5), comment (min 10 chars)
- isPublic: false until both submit OR 7 days pass
- Aggregates: car/user ratings updated when published

### Damage Claims (Dispute System)
- Status: open → admin_reviewing → decided → resolved
- adminDecision: host|renter|split|extra
- Both parties must confirm settlement before claim resolves
- Supports extra charges beyond deposit

### Conversations & Messages
- conversationId: "{carId}_{renterId}"
- Linked to booking after acceptance
- System messages posted at key events
- Unread counts tracked separately for host/renter

---

## 3. SERVICES SUMMARY

### AuthService
- signUp/signIn with email
- createUserProfile (uploads CNIC images)
- updateUserProfile, resetPassword

### BookingService (Core)
- createBookingRequest → pending booking
- acceptBooking → confirmed + auto-decline overlapping
- declineBooking, cancelBooking, expireBooking
- completePreHandover (host finishes inspection, deposits paid)
- renterStartTrip (status → active)
- proposeSettlement + completeTrip (settlement flow)
- flagTrip (renter disputes) → creates damageClaim
- confirmDisputeSettlement (both parties confirm)
- submitReview, _publishReviewsAndUpdateAggregates, _updateCarRatingAggregate, _updateUserRatingAggregate
- Streams: getBookingsForHost/Renter, streamBooking, streamTimeline, streamClaimForBooking

### ChatService
- getOrCreateConversation, linkBookingToConversation
- sendMessage, postSystemMessage, resetUnreadCount
- Stream: getConversationsForUser, getMessages

### ListingService
- createListing (uploads images, creates geo field)
- getUserListings, getAllListings
- deleteListing, updateListingStatus
- migrateListingGeoField (for geoflutterfire_plus)

### NotificationService
- initialize (FCM setup, local notifications)
- saveFcmToken, onUserLogin
- foreground notification display
- TODO: notification tap navigation

---

## 4. SCREENS (Mobile App)

**Auth:** LoginScreen, SignupScreen, SplashScreen, ForgotPasswordScreen

**Browse:** HomeScreen, SearchScreen, MapSearchScreen, CarDetailScreen

**Listings:** MyListingsScreen, AddListingScreen, ListingSuccessScreen

**Bookings (Renter):** MyBookingsScreen, BookingDetailScreen, BookingSummaryScreen, BookingConfirmedScreen

**Bookings (Host):** HostBookingsScreen, IncomingRequestsScreen, RequestDetailScreen

**Trip:** ActiveTripScreen, PreTripInspectionScreen, PostTripInspectionScreen, CashSettlementScreen, TripFlaggedScreen

**Reviews:** SubmitReviewScreen, AllReviewsScreen

**Chat:** ConversationsListScreen, ChatScreen

**Other:** ProfileScreen, NotificationsScreen

---

## 5. BOOKING LIFECYCLE

1. **pending** (24h auto-expire)
   - Renter submits request with message & pricing breakdown
   - Host gets notification
   
2. **confirmed** (after host accepts)
   - Date range added to car.bookedDateRanges
   - Overlapping pending bookings auto-declined
   - Chat conversation created/linked
   
3. **active** (after renter starts)
   - Host completes preHandover → deposits recorded
   - Renter presses "Start Trip" → tripStartedAt set
   
4. **completed** (two paths)
   - Path A: Host proposes settlement → renter confirms → completeTrip()
   - Path B: Host directly completes trip
   
5. **flagged** (if dispute)
   - Renter calls flagTrip() → creates damageClaim (status=open)
   - Admin reviews & posts decision → claim.status=decided
   - Both parties confirm → claim.status=resolved, booking.status=completed
   
6. **cancelled/rejected/expired**
   - Date range removed from car
   - Notifications sent
   - If host cancels: strike count incremented

**Timeline:** All transitions logged in bookings/{bookingId}/timeline

---

## 6. DISPUTE SYSTEM (Dispute 2.0)

**Admin Resolutions:**
1. **Host** - Host keeps claimed amount
2. **Renter** - Full refund
3. **Split** - Custom amount (0 to deposit)
4. **Extra** - Full deposit + renter owes extra beyond deposit

**Confirmation Gate:**
- Admin posts decision → claim.status=decided
- Host confirms: hostConfirmed=true, hostConfirmedAt
- Renter confirms: renterConfirmed=true, renterConfirmedAt
- Both confirmed → claim.status=resolved, booking.status=completed

---

## 7. REVIEW SYSTEM

- Submitted after trip completion
- isPublic=false initially (blind review)
- Published when: both submit OR 7 days pass
- Auto-updates car/user rating aggregates
- ratingBreakdown: {'1': count, '2': count, ...}

---

## 8. CHAT SYSTEM

- Pre-booking chat: conversationId="{carId}_{renterId}"
- Links to booking on acceptance (adds bookingId, bookingStatus)
- System messages at: booking confirmed, trip started, return proposed, trip completed, dispute decided
- Unread counts tracked separately (host/renter)
- TODO: Read-only lock after completion not enforced

---

## 9. ADMIN PANEL (Next.js)

**Pages:**
- Dashboard: Stats (users, listings, disputes, CNIC pending)
- Bookings: View timeline, force cancel
- Claims: Review pre/post photos, chat history, post admin decision (host|renter|split|extra)
- CNIC: Approve/reject verifications
- Listings: Approve/reject car listings
- Users, Reviews, Admins management

**API Routes:**
- GET /api/bookings, /api/claims, /api/cnic, /api/listings
- POST /api/bookings/{id}/dispute, /api/bookings/{id}/force-cancel
- POST /api/claims/{claimId}/resolve (posts decision: status→decided)
- POST /api/claims/{claimId}/force-close (override dispute)
- POST /api/cnic/{id}/approve, /api/cnic/{id}/reject
- POST /api/listings/{id}/approve, /api/listings/{id}/reject

---

## 10. PROVIDERS (State Management)

**AuthProvider**
- currentUser, status (idle|loading|error)
- Auto-signs out admins (isAdmin check)
- signUp/signIn/signOut, resetPassword, loadUserProfile

**BookingProvider**
- hostPendingBookings, hostAllBookings, renterBookings
- Grouped accessors: pending, confirmed, active, completed, cancelled, flagged
- listenToHostBookings, listenToRenterBookings (real-time streams)
- Auto-expires bookings

**ChatProvider**
- conversations list, totalUnreadCount
- listenToConversations (real-time)

---

## 11. FIRESTORE SECURITY RULES

- **isAdmin()**: role IN [admin, super_admin] OR roles.isAdmin==true
- **users/**: read by self, update rating-only fields
- **listings/**: read by all authenticated, update by owner/admin/rating fields
- **bookings/**: role-based field updates (renter/host can only touch their fields)
- **damageClaims/**: host/renter can only confirm, admin can decide
- **reviews/**: create by reviewer, update isPublic by admin
- **scheduledNotifications/**: Cloud Functions only

---

## 12. NOTIFICATIONS

**Types Created:**
- new_booking_request, booking_confirmed, booking_rejected, booking_cancelled, booking_expired
- handover_complete, trip_started, return_proposed, trip_completed, trip_flagged
- dispute_decided, review_prompt (scheduled 2h after trip)
- CNIC_verification_pending, listing_pending

**Methods:**
- Direct writes to users/{userId}/notifications/{id}
- FCM push (if user has token)
- Scheduled notifications (via Cloud Functions)

**TODO:** Notification tap navigation not implemented

---

## 13. STORAGE STRUCTURE

- users/{userId}/cnic/{front|back}.jpg
- listings/{listingId}/image_{0..n}.jpg
- inspections/{bookingId}/{pre|post}_trip/{area}_{timestamp}.jpg

---

## 14. VALIDATION

**UI Level:**
- Review comment: min 10 chars
- Date range: endDate >= startDate
- Rating: 1-5 (dropdown)
- Fuel level: constrained options

**Service Level:**
- CNIC verification: must be 'approved' to book
- Duplicate review check
- Date availability check
- Admin validation for 'extra' decision (requires positive extraChargeAmount)

**Gaps:**
- phoneNumber format not validated
- CNIC format not validated
- Listing fields not validated in service

---

## 15. KNOWN ISSUES & TODOS

| Issue | Status | Impact |
|-------|--------|--------|
| Notification tap navigation | TODO | Can't deep link to bookings |
| Read-only chat after completion | Partial | isActive flag exists but not enforced |
| Force close disputes | Partial | Endpoint exists, logic unclear |
| Cloud Functions | Assumed | Scheduled notifications, review auto-publish |
| Widget tests | Not done | No test coverage |
| Custom claims for admins | Deferred | Current: boolean flag in Firestore |

**Debug Code:** Multiple debugPrint() statements in production (acceptable but should wrap in kDebugMode)

---

## 16. DEPENDENCIES

### Flutter (pubspec.yaml)
- Firebase: core 4.2.1, auth 6.1.2, firestore 6.1.0, storage 13.0.4, messaging 16.0.4
- State: provider 6.1.1
- UI: google_fonts, image_picker, cached_network_image, table_calendar
- Geo: geolocator, geoflutterfire_plus, geocoding
- Notifications: flutter_local_notifications

### Next.js (package.json)
- next 14.2.0, react 18.3.0, typescript 5.4.5
- Firebase: firebase 10.12.0, firebase-admin 12.1.0
- UI: Radix UI, shadcn/ui, lucide-react, recharts
- Utilities: date-fns, tailwindcss

---

## 17. COMPLETED vs INCOMPLETE

✅ **Fully Implemented:**
- User auth + role system
- Complete booking lifecycle
- Pre/post inspections with photos
- Chat & messaging
- Review system (blind reviews + aggregates)
- Damage disputes (Dispute 2.0) with confirmation gate
- Admin panel with moderation tools
- Geo-location search
- Cash payment tracking
- Real-time streams

⚠️ **Partially Implemented:**
- Push notification routing (endpoint done, UI todo)
- Read-only chat locks (flag exists, not enforced)
- Force-close disputes (API exists, logic unclear)

❌ **Not Implemented:**
- Widget tests
- Custom Firebase claims (admin roles)
- Chat read-only enforcement

---

## 18. QUICK REFERENCE

**Key Files:**
- Models: `lib/models/*.dart` (10 files)
- Services: `lib/services/*.dart` (5 files)
- Screens: `lib/screens/**/*.dart` (28 files)
- Admin API: `admin_panel/app/api/**/*.ts` (15+ routes)

**Firestore Collections:** users, listings, bookings, reviews, damageClaims, conversations, adminAlerts, scheduledNotifications

**Main Workflows:**
1. Sign up → Create profile (CNIC optional)
2. Browse listings → Inquire (create conversation)
3. Book → Confirm (host accepts)
4. Handover → Start trip → Return → Settle
5. If disputed → Admin reviews → Posts decision → Both confirm
6. Review → Auto-publish when both done OR after 7 days