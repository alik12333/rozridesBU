import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // To access navigatorKey
import '../models/booking_model.dart';
import '../screens/booking/booking_detail_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/host/incoming_requests_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/renter/my_bookings_screen.dart';
import '../screens/reviews/submit_review_screen.dart';
import '../screens/trip/active_trip_screen.dart';

/// Singleton service that handles FCM token registration, permission requests,
/// and foreground push notification display using flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'rozrides_channel';
  static const _channelName = 'RozRides Notifications';
  static const _channelDesc = 'Booking updates and alerts from RozRides';

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // ── 1. Request permission ─────────────────────────────────────────────
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[NotifService] Permission: ${settings.authorizationStatus}');

    // ── 2. Init flutter_local_notifications ───────────────────────────────
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // already handled by FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _handleNotificationNavigation(data);
          } catch (e) {
            debugPrint('[NotifService] Payload parse error: $e');
          }
        }
      },
    );

    // Android notification channel (required for Android 8+)
    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.high,
            ),
          );
    }

    // ── 3. Save FCM token for current user ────────────────────────────────
    await _saveFcmToken();

    // ── 4. Listen for token refresh ───────────────────────────────────────
    _fcm.onTokenRefresh.listen(_saveToken);

    // ── 5. Show local notification when app is in FOREGROUND ─────────────
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // ── 6. Handle notification taps (background / terminated) ─────────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationNavigation(message.data);
    });

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      // Small delay to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationNavigation(initial.data);
      });
    }
  }

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> _saveFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('[NotifService] Token fetch error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotifService] FCM token saved for $uid');
    } catch (e) {
      debugPrint('[NotifService] Token save error: $e');
    }
  }

  /// Call when a user logs in to ensure their token is fresh.
  Future<void> onUserLogin() async {
    await _saveFcmToken();
  }

  // ── Foreground notification display ─────────────────────────────────────────

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // ── Tap handling & Navigation ────────────────────────────────────────────────

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] as String?;
    final bookingId = data['bookingId'] as String?;
    final conversationId = data['conversationId'] as String?;

    debugPrint('[NotifService] Navigating for type: $type');

    switch (type) {
      case 'new_booking_request':
        _nav(const IncomingRequestsScreen());
        break;

      case 'booking_confirmed':
      case 'booking_rejected':
      case 'booking_cancelled':
      case 'handover_complete':
      case 'return_proposed':
      case 'trip_completed':
      case 'trip_flagged':
      case 'dispute_decided':
      case 'trip_auto_resolved':
        if (bookingId != null) {
          _nav(BookingDetailScreen(bookingId: bookingId));
        }
        break;

      case 'booking_expired':
        _nav(const MyBookingsScreen());
        break;

      case 'trip_started':
        if (bookingId != null) {
          _nav(ActiveTripScreen(bookingId: bookingId));
        }
        break;

      case 'review_prompt':
        if (bookingId != null) {
          // Need full booking model for review screen
          _showLoading();
          try {
            final doc = await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get();
            _hideLoading();
            if (doc.exists) {
              final booking = BookingModel.fromMap(doc.data()!, doc.id);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final isRenter = uid == booking.renterId;
              _nav(SubmitReviewScreen(
                booking: booking,
                reviewType: isRenter ? 'renter_to_host' : 'host_to_renter',
              ));
            }
          } catch (e) {
            _hideLoading();
          }
        }
        break;

      case 'new_message':
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (conversationId != null && uid != null) {
          _nav(ChatScreen(conversationId: conversationId, currentUserId: uid));
        }
        break;

      case 'CNIC_verification_pending':
        _nav(const ProfileScreen());
        break;

      case 'listing_pending':
        _nav(const MyListingsScreen());
        break;

      default:
        debugPrint('[NotifService] Unknown notification type: $type');
    }
  }

  void _nav(Widget screen) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showLoading() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoading() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}

/// Top-level handler for background messages — required by FCM.
/// Must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotifService] Background message: ${message.messageId}');
  // No UI work here — the OS will display the notification automatically.
}
