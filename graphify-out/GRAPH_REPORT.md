# Graph Report - rozridesBU  (2026-05-01)

## Corpus Check
- 121 files · ~218,400 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 908 nodes · 1103 edges · 31 communities detected
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 42 edges
2. `GET()` - 22 edges
3. `package:cloud_firestore/cloud_firestore.dart` - 22 edges
4. `package:provider/provider.dart` - 21 edges
5. `package:google_fonts/google_fonts.dart` - 19 edges
6. `../../providers/auth_provider.dart` - 18 edges
7. `POST()` - 15 edges
8. `../models/booking_model.dart` - 13 edges
9. `package:intl/intl.dart` - 12 edges
10. `../../services/booking_service.dart` - 11 edges

## Surprising Connections (you probably didn't know these)
- `GET()` --calls--> `getAllBookings()`  [INFERRED]
  admin_panel/app/api/claims/route.ts → admin_panel/lib/firestore.ts
- `GET()` --calls--> `getBookingTimeline()`  [INFERRED]
  admin_panel/app/api/claims/route.ts → admin_panel/lib/firestore.ts
- `GET()` --calls--> `getAllListings()`  [INFERRED]
  admin_panel/app/api/claims/route.ts → admin_panel/lib/firestore.ts
- `GET()` --calls--> `makeAdmin()`  [INFERRED]
  admin_panel/app/api/claims/route.ts → admin_panel/scripts/make-admin.js
- `GET()` --calls--> `getUser()`  [INFERRED]
  admin_panel/app/api/claims/route.ts → admin_panel/lib/firestore.ts

## Communities

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (64): ../car_detail_screen.dart, chat_screen.dart, core/theme/app_theme.dart, firebase_options.dart, ../models/notification_model.dart, package:provider/provider.dart, ../../providers/auth_provider.dart, ../../providers/chat_provider.dart (+56 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (62): host/incoming_requests_screen.dart, host/location_picker_screen.dart, listing_success_screen.dart, login_screen.dart, my_listings_screen.dart, package:flutter/services.dart, package:image_picker/image_picker.dart, AddListingScreen (+54 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (58): ../models/review_model.dart, package:google_fonts/google_fonts.dart, package:intl/intl.dart, ../../providers/booking_provider.dart, ../renter/my_bookings_screen.dart, ../../services/booking_service.dart, AppTheme, BookingConfirmedScreen (+50 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (51): ../booking/booking_detail_screen.dart, cancellation_screen.dart, request_detail_screen.dart, ../reviews/submit_review_screen.dart, ../trip/active_trip_screen.dart, ../trip/cash_settlement_screen.dart, ../trip/post_trip_inspection_screen.dart, ../trip/pre_trip_inspection_screen.dart (+43 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (29): sendCNICApprovalNotification(), sendListingApprovalNotification(), sendNotificationToUser(), addNotification(), banUser(), deleteReview(), dismissReviewFlag(), forceCancelBooking() (+21 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (46): chat_service.dart, ../models/booking_model.dart, ../models/damage_claim_model.dart, ../models/inspection_model.dart, ../models/post_inspection_model.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, trip_flagged_screen.dart (+38 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (47): add_listing_screen.dart, chat/conversations_list_screen.dart, home_screen.dart, host/host_bookings_screen.dart, notifications_screen.dart, profile_screen.dart, search/map_search_screen.dart, _AppDrawer (+39 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (33): inspection_model.dart, package:cloud_firestore/cloud_firestore.dart, package:table_calendar/table_calendar.dart, BookingModel, copyWith, ConversationModel, MessageModel, otherPartyNameFor (+25 more)

### Community 8 - "Community 8"
Cohesion: 0.05
Nodes (36): dart:async, dart:io, ../models/conversation_model.dart, ../models/user_model.dart, package:firebase_auth/firebase_auth.dart, package:firebase_storage/firebase_storage.dart, package:geoflutterfire_plus/geoflutterfire_plus.dart, ../services/auth_service.dart (+28 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (35): main_navigation.dart, ../models/listing_model.dart, package:cached_network_image/cached_network_image.dart, package:flutter/material.dart, ../services/listing_service.dart, ListingProvider, loadAllListings, loadMyListings (+27 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (39): dart:ui, package:geocoding/geocoding.dart, package:geolocator/geolocator.dart, package:google_maps_flutter/google_maps_flutter.dart, ../search_screen.dart, build, Center, _confirmLocation (+31 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (35): dart:math, signup_screen.dart, BorderSide, build, Color, _DarkField, dispose, _FieldLabel (+27 more)

### Community 12 - "Community 12"
Cohesion: 0.06
Nodes (34): post_trip_inspection_screen.dart, _actionBtn, ActiveTripScreen, _ActiveTripScreenState, build, _buildCountdown, _card, _carPlaceholder (+26 more)

### Community 13 - "Community 13"
Cohesion: 0.06
Nodes (30): cash_settlement_screen.dart, _areaStep, _back, build, _card, Container, _damageChip, dispose (+22 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (28): booking/booking_summary_screen.dart, chat/chat_screen.dart, package:url_launcher/url_launcher.dart, reviews/all_reviews_screen.dart, build, _buildTimelineStep, CarDetailScreen, _CarDetailScreenState (+20 more)

### Community 15 - "Community 15"
Cohesion: 0.07
Nodes (28): _back, build, _buildPhotoStep, _buildProgressBar, _buildStep1, _buildStep7, _buildSummary, _card (+20 more)

### Community 16 - "Community 16"
Cohesion: 0.07
Nodes (26): build, _buildAvatar, _buildEmptyState, Center, CircleAvatar, _CnicBadge, Column, Container (+18 more)

### Community 17 - "Community 17"
Cohesion: 0.08
Nodes (24): _BookingCard, _BookingCardState, build, _buildActions, Center, Container, _countdownChip, _dateChip (+16 more)

### Community 18 - "Community 18"
Cohesion: 0.08
Nodes (22): booking_confirmed_screen.dart, ../models/pricing_breakdown_model.dart, BookingSummaryScreen, _BookingSummaryScreenState, build, _dateRow, dispose, Divider (+14 more)

### Community 19 - "Community 19"
Cohesion: 0.12
Nodes (16): build, _buildBody, Card, Column, Container, dispose, Icon, initState (+8 more)

### Community 20 - "Community 20"
Cohesion: 0.26
Nodes (10): fetchBookings(), fetchCNICData(), fetchListings(), fetchTimeline(), getStatusBadge(), handleApprove(), handleForceCancel(), handleMarkDisputed() (+2 more)

### Community 21 - "Community 21"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 22 - "Community 22"
Cohesion: 0.4
Nodes (4): CNIC, Location, Roles, UserModel

### Community 24 - "Community 24"
Cohesion: 0.5
Nodes (2): DashboardLayout(), useRoleGuard()

### Community 25 - "Community 25"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 26 - "Community 26"
Cohesion: 0.5
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 27 - "Community 27"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 28 - "Community 28"
Cohesion: 0.67
Nodes (2): package:flutter_test/flutter_test.dart, main

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (1): AppConstants

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (1): CashPricingBreakdown

## Knowledge Gaps
- **678 isolated node(s):** `main`, `package:flutter_test/flutter_test.dart`, `-registerWithRegistry`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `MainActivity` (+673 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 21`** (5 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (4 nodes): `layout.tsx`, `useRoleGuard.ts`, `DashboardLayout()`, `useRoleGuard()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (4 nodes): `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 26`** (4 nodes): `AppDelegate`, `.application()`, `FlutterAppDelegate`, `AppDelegate.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 27`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (3 nodes): `package:flutter_test/flutter_test.dart`, `widget_test.dart`, `main`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `app_constants.dart`, `AppConstants`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `pricing_breakdown_model.dart`, `CashPricingBreakdown`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 9` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.317) - this node is a cross-community bridge._
- **Why does `package:cloud_firestore/cloud_firestore.dart` connect `Community 7` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 5`, `Community 8`, `Community 9`, `Community 10`, `Community 12`, `Community 16`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Why does `package:provider/provider.dart` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 6`, `Community 11`, `Community 12`, `Community 14`, `Community 16`, `Community 17`, `Community 18`, `Community 19`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 16 inferred relationships involving `GET()` (e.g. with `handleRevoke()` and `handleDismiss()`) actually correct?**
  _`GET()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **What connects `main`, `package:flutter_test/flutter_test.dart`, `-registerWithRegistry` to the rest of the system?**
  _678 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._