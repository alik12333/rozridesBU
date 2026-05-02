import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial);
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
      payload: message.data['bookingId'],
    );
  }

  // ── Tap handling ─────────────────────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    // TODO: Navigate to the booking detail screen using the bookingId in
    // message.data['bookingId'] once a navigator key is set up.
    debugPrint(
        '[NotifService] Notification tapped: ${message.data}');
  }
}

/// Top-level handler for background messages — required by FCM.
/// Must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotifService] Background message: ${message.messageId}');
  // No UI work here — the OS will display the notification automatically.
}
