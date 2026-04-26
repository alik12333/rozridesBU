import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/booking_model.dart';
import '../models/damage_claim_model.dart';
import '../models/inspection_model.dart';
import '../models/post_inspection_model.dart';
import '../models/pricing_breakdown_model.dart';
import '../models/review_model.dart';
import 'chat_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────── HELPERS ────────────────────────────────────

  void _addTimelineEvent(
    WriteBatch batch,
    String bookingId,
    String status,
    String note,
    String triggeredBy,
  ) {
    final timelineRef = _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('timeline')
        .doc();
    batch.set(timelineRef, {
      'status': status,
      'note': note,
      'triggeredBy': triggeredBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _addTimelineEventTx(
    Transaction tx,
    String bookingId,
    String status,
    String note,
    String triggeredBy,
  ) {
    final timelineRef = _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('timeline')
        .doc();
    tx.set(timelineRef, {
      'status': status,
      'note': note,
      'triggeredBy': triggeredBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Returns true if [startDate, endDate] does NOT overlap any confirmed/active booking.
  Future<bool> checkAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('carId', isEqualTo: carId)
          .where('status', whereIn: ['confirmed', 'active'])
          .get();

      for (final doc in snapshot.docs) {
        final existingStart =
            (doc.data()['startDate'] as Timestamp).toDate();
        final existingEnd =
            (doc.data()['endDate'] as Timestamp).toDate();

        if (startDate.isBefore(existingEnd) && endDate.isAfter(existingStart)) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  bool hasConflict(
    DateTime startDate,
    DateTime endDate,
    List<Map<String, dynamic>> bookedRanges,
  ) {
    for (var range in bookedRanges) {
      final existingStart = (range['start'] as Timestamp).toDate();
      final existingEnd = (range['end'] as Timestamp).toDate();
      if (startDate.isBefore(existingEnd) && endDate.isAfter(existingStart)) {
        return true;
      }
    }
    return false;
  }

  bool _datesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  // ──────────────────────── CREATE BOOKING ────────────────────────────────

  Future<String> createBookingRequest({
    required String carId,
    required String hostId,
    required DateTime startDate,
    required DateTime endDate,
    required CashPricingBreakdown pricing,
    required String messageToHost,
    required String carName,
    required String carPhoto,
    required String carLocation,
    required String renterName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated.');
    final renterId = currentUser.uid;

    final userDoc =
        await _firestore.collection('users').doc(renterId).get();
    if (!userDoc.exists) throw Exception('User profile not found.');

    final cnicMap = userDoc.data()?['cnic'] as Map<String, dynamic>?;
    final cnicStatus = cnicMap?['verificationStatus'] ?? 'pending';
    if (cnicStatus != 'approved') {
      throw Exception('CNIC_NOT_VERIFIED');
    }

    final available = await checkAvailability(
      carId: carId,
      startDate: startDate,
      endDate: endDate,
    );
    if (!available) throw Exception('DATES_UNAVAILABLE');

    final bookingRef = _firestore.collection('bookings').doc();
    final bookingId = bookingRef.id;
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    final batch = _firestore.batch();

    final cashPayments = {
      'depositPaidToHost': false,
      'depositPaidAmount': 0,
      'depositPaidAt': null,
      'rentPaidToHost': false,
      'rentPaidAmount': 0,
      'rentPaidAt': null,
      'depositRefundedToRenter': false,
      'depositRefundedAmount': 0,
      'depositRefundedAt': null,
      'damageDeduction': 0,
    };

    final reviewStatus = {
      'renterSubmitted': false,
      'hostSubmitted': false,
    };

    batch.set(bookingRef, {
      'bookingId': bookingId,
      'carId': carId,
      'hostId': hostId,
      'renterId': renterId,
      'renterName': renterName,
      'carName': carName,
      'carPhoto': carPhoto,
      'carLocation': carLocation,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': pricing.totalDays,
      'pricePerDay': pricing.pricePerDay,
      'totalRent': pricing.totalRent,
      'securityDeposit': pricing.securityDeposit,
      'cashPayments': cashPayments,
      'status': 'pending',
      'messageToHost': messageToHost,
      'cancellationPolicy': 'flexible',
      'cancellationReason': null,
      'rejectionReason': null,
      'reviewStatus': reviewStatus,
      'tripStartedAt': null,
      'tripEndedAt': null,
      'warningNotificationSent': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    _addTimelineEvent(
      batch,
      bookingId,
      'pending',
      'Booking request submitted by renter',
      renterId,
    );

    final notifRef = _firestore
        .collection('users')
        .doc(hostId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'new_booking_request',
      'title': 'New Booking Request',
      'body': '$carName from ${_fmt(startDate)} to ${_fmt(endDate)}',
      'bookingId': bookingId,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return bookingId;
  }

  // ──────────────────────── ACCEPT BOOKING ─────────────────────────────────
  // Uses a Firestore transaction to prevent race conditions.

  Future<void> acceptBooking(String bookingId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final hostId = currentUser.uid;

    // Fetch host name for notification body
    String hostName = 'Host';
    try {
      final hostDoc = await _firestore.collection('users').doc(hostId).get();
      hostName = hostDoc.data()?['fullName'] ?? 'Host';
    } catch (_) {}

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    String renterId = '';
    String carId = '';
    String carName = '';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    double securityDeposit = 0;

    // ── Transaction ──────────────────────────────────────────────────────
    await _firestore.runTransaction((tx) async {
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw Exception('BOOKING_NOT_FOUND');

      final data = bookingSnap.data()!;
      final status = data['status'] as String? ?? '';

      if (status != 'pending') {
        throw Exception('BOOKING_NO_LONGER_PENDING');
      }

      renterId      = data['renterId'] ?? '';
      carId         = data['carId'] ?? '';
      carName       = data['carName'] ?? '';
      startDate     = (data['startDate'] as Timestamp).toDate();
      endDate       = (data['endDate'] as Timestamp).toDate();
      securityDeposit = (data['securityDeposit'] ?? 0).toDouble();

      // Check car date conflicts
      final carRef = _firestore.collection('listings').doc(carId);
      final carSnap = await tx.get(carRef);
      if (carSnap.exists) {
        final ranges = List<Map<String, dynamic>>.from(
            carSnap.data()?['bookedDateRanges'] ?? []);
        for (final range in ranges) {
          if (range['bookingId'] == bookingId) continue;
          final rStart = (range['start'] as Timestamp).toDate();
          final rEnd   = (range['end'] as Timestamp).toDate();
          if (_datesOverlap(startDate, endDate, rStart, rEnd)) {
            throw Exception('DATES_NOW_UNAVAILABLE');
          }
        }

        // Add date range to car
        tx.update(carRef, {
          'bookedDateRanges': FieldValue.arrayUnion([
            {
              'start': Timestamp.fromDate(startDate),
              'end': Timestamp.fromDate(endDate),
              'bookingId': bookingId,
            }
          ]),
        });
      }

      // Update booking status
      tx.update(bookingRef, {
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Timeline event (within transaction)
      _addTimelineEventTx(
        tx, bookingId, 'confirmed',
        'Host accepted the booking request', hostId,
      );

      // Renter notification (within transaction)
      final renterNotifRef = _firestore
          .collection('users')
          .doc(renterId)
          .collection('notifications')
          .doc();
      tx.set(renterNotifRef, {
        'type': 'booking_confirmed',
        'title': 'Booking Confirmed! 🎉',
        'body':
            '$hostName accepted your booking for $carName. Bring PKR ${securityDeposit.toStringAsFixed(0)} cash on ${_fmt(startDate)}.',
        'bookingId': bookingId,
        'isRead': false,
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove the hardcoded conversation creation since we will handle it after tx
    });

    // ── Post-transaction: Chat & Auto-decline ────────────────────────────
    try {
      final chatSvc = ChatService();
      final conv = await chatSvc.getOrCreateConversation(
        carId: carId,
        carName: carName,
        hostId: hostId,
        hostName: hostName,
      );
      await chatSvc.linkBookingToConversation(
        carId: carId,
        renterId: renterId,
        bookingId: bookingId,
        bookingStatus: 'confirmed',
      );
      final dateStr = '${_fmt(startDate)} to ${_fmt(endDate)}';
      await chatSvc.postSystemMessage(
        conversationId: conv.conversationId,
        text: 'Booking confirmed for $carName — $dateStr. You can now coordinate pickup details here.',
      );
    } catch (e) {
      debugPrint('Error creating chat: $e');
    }

    await _autoDeclineOverlapping(bookingId, carId, startDate, endDate, hostId);
  }

  Future<void> _autoDeclineOverlapping(
    String acceptedBookingId,
    String carId,
    DateTime acceptedStart,
    DateTime acceptedEnd,
    String hostId,
  ) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('carId', isEqualTo: carId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      if (doc.id == acceptedBookingId) continue;

      final data = doc.data();
      final otherStart = (data['startDate'] as Timestamp).toDate();
      final otherEnd   = (data['endDate'] as Timestamp).toDate();

      if (!_datesOverlap(acceptedStart, acceptedEnd, otherStart, otherEnd)) {
        continue;
      }

      final otherRenterId = data['renterId'] ?? '';
      final otherCarName  = data['carName']  ?? '';

      batch.update(doc.reference, {
        'status': 'rejected',
        'rejectionReason': 'HOST_CHOSE_ANOTHER_BOOKING',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _addTimelineEvent(
        batch, doc.id, 'rejected',
        'Auto-declined: host accepted another booking for the same dates.',
        'system',
      );

      final notifRef = _firestore
          .collection('users')
          .doc(otherRenterId)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'booking_rejected',
        'title': 'Booking Request Declined',
        'body':
            'Your request for $otherCarName was declined — those dates were just accepted by another renter.',
        'bookingId': doc.id,
        'isRead': false,
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ──────────────────────── DECLINE BOOKING ───────────────────────────────

  Future<void> declineBooking(BookingModel booking, String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final hostId = currentUser?.uid ?? booking.hostId;

    String hostName = 'Host';
    try {
      final hostDoc = await _firestore.collection('users').doc(hostId).get();
      hostName = hostDoc.data()?['fullName'] ?? 'Host';
    } catch (_) {}

    final batch = _firestore.batch();

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    batch.update(bookingRef, {
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
        batch, booking.id, 'rejected', 'Host declined: $reason', hostId);

    final notifRef = _firestore
        .collection('users')
        .doc(booking.renterId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'booking_rejected',
      'title': 'Booking Declined',
      'body':
          '$hostName declined your request for ${booking.carName}. Reason: $reason. Browse other available cars.',
      'bookingId': booking.id,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ──────────────────────── CANCEL BOOKING ────────────────────────────────

  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
    required String cancelledBy, // 'renter' or 'host'
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final userId = currentUser.uid;

    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final bookingSnap = await bookingRef.get();
    if (!bookingSnap.exists) throw Exception('Booking not found');

    final data    = bookingSnap.data()!;
    final status  = data['status'] as String? ?? '';
    final carId   = data['carId'] as String? ?? '';
    final hostId  = data['hostId'] as String? ?? '';
    final renterId = data['renterId'] as String? ?? '';
    final carName = data['carName'] as String? ?? '';
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate   = (data['endDate'] as Timestamp).toDate();

    final otherPartyId = cancelledBy == 'renter' ? hostId : renterId;

    // Fetch cancelling user name
    String cancellerName = 'User';
    try {
      final uDoc = await _firestore.collection('users').doc(userId).get();
      cancellerName = uDoc.data()?['fullName'] ?? 'User';
    } catch (_) {}

    final batch = _firestore.batch();

    batch.update(bookingRef, {
      'status': 'cancelled',
      'cancellationReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
      batch, bookingId, 'cancelled',
      '${cancelledBy == 'renter' ? 'Renter' : 'Host'} cancelled: $reason',
      userId,
    );

    // If was confirmed, remove date range from car
    if (status == 'confirmed') {
      final carRef = _firestore.collection('listings').doc(carId);
      batch.update(carRef, {
        'bookedDateRanges': FieldValue.arrayRemove([
          {
            'start': Timestamp.fromDate(startDate),
            'end': Timestamp.fromDate(endDate),
            'bookingId': bookingId,
          }
        ]),
      });
    }

    // Notify the other party
    final notifRef = _firestore
        .collection('users')
        .doc(otherPartyId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'booking_cancelled',
      'title': 'Booking Cancelled',
      'body': cancelledBy == 'renter'
          ? '$cancellerName cancelled the booking for $carName. Reason: $reason.'
          : '$cancellerName (host) cancelled your booking for $carName. Reason: $reason.',
      'bookingId': bookingId,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // If host cancelled → increment strike counters
    if (cancelledBy == 'host') {
      final hostRef = _firestore.collection('users').doc(hostId);
      batch.update(hostRef, {
        'hostStats.cancellationsByHost': FieldValue.increment(1),
        'hostStats.cancellationStrikeCount': FieldValue.increment(1),
      });

      // Alert admin if 3 strikes (checked outside batch after commit)
    }

    await batch.commit();

    // Check strike count after commit and alert admin if needed
    if (cancelledBy == 'host') {
      try {
        final hostSnap = await _firestore.collection('users').doc(hostId).get();
        final strikes = hostSnap.data()?['hostStats']?['cancellationStrikeCount'] ?? 0;
        if (strikes >= 3) {
          await _firestore.collection('admin_alerts').add({
            'type': 'host_cancellation_threshold',
            'hostId': hostId,
            'message': 'Host $cancellerName has reached $strikes cancellations and may require account review.',
            'createdAt': FieldValue.serverTimestamp(),
            'resolved': false,
          });
        }
      } catch (_) {}
    }

    try {
      final convId = '${carId}_$renterId';
      await ChatService().updateConversationBookingStatus(
        conversationId: convId,
        bookingStatus: 'cancelled',
      );
      await ChatService().postSystemMessage(
        conversationId: convId,
        text: '❌ This booking was cancelled. This conversation is now closed.',
      );
    } catch (_) {}
  }

  // ──────────────────────── EXPIRE BOOKING ────────────────────────────────

  Future<void> expireBooking(BookingModel booking) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('bookings').doc(booking.id), {
      'status': 'expired',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
        batch, booking.id, 'expired',
        'Auto-expired after 24 hours without response', 'system');

    final notifRef = _firestore
        .collection('users')
        .doc(booking.renterId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'booking_expired',
      'title': 'Request Expired',
      'body':
          'The host did not respond to your request for ${booking.carName} in time. Browse similar available cars.',
      'bookingId': booking.id,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ────────────────────────── STREAMS ─────────────────────────────────────

  Stream<List<BookingModel>> getBookingsForRenter(String renterId) {
    return _firestore
        .collection('bookings')
        .where('renterId', isEqualTo: renterId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList();
          // Sort in-memory — avoids composite index requirement
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BookingModel>> getBookingsForHost(String hostId) {
    return _firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList();
          // Sort in-memory — avoids composite index requirement
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BookingModel>> getPendingRequestsForHost(String hostId) {
    return _firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => BookingModel.fromMap(d.data(), d.id))
              .toList();
          // Sort in-memory — avoids composite index requirement
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream a single booking document in real-time.
  Stream<BookingModel?> streamBooking(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map((snap) =>
            snap.exists ? BookingModel.fromMap(snap.data()!, snap.id) : null);
  }

  /// Fetch timeline events for a booking (ordered by timestamp asc).
  Stream<List<Map<String, dynamic>>> streamTimeline(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('timeline')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // Keep legacy aliases
  Stream<List<BookingModel>> getHostPendingBookings(String hostId) =>
      getPendingRequestsForHost(hostId);

  Stream<List<BookingModel>> getRenterBookings(String renterId) =>
      getBookingsForRenter(renterId);

  // ──────────────────────── START TRIP ────────────────────────────────────

  Future<void> startTrip(String bookingId, PreTripInspection inspection) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final hostId = currentUser.uid;

    // 1. Upload photos to Firebase Storage first
    final updatedItems = <String, InspectionItem>{};
    for (final entry in inspection.items.entries) {
      final area = entry.key;
      final item = entry.value;
      final uploadedUrls = <String>[];
      for (int i = 0; i < item.photoUrls.length; i++) {
        final path = item.photoUrls[i];
        if (path.startsWith('http')) {
          // Already a URL, keep it
          uploadedUrls.add(path);
          continue;
        }
        try {
          final file = File(path);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final ref = FirebaseStorage.instance
              .ref('inspections/$bookingId/pre_trip/${area}_$timestamp.jpg');
          await ref.putFile(file);
          final downloadUrl = await ref.getDownloadURL();
          uploadedUrls.add(downloadUrl);
        } catch (e) {
          // Keep local path on upload failure — don't block the flow
          uploadedUrls.add(path);
        }
      }
      updatedItems[area] = item.copyWith(photoUrls: uploadedUrls);
    }

    final finalInspection = inspection.copyWith(
      items: updatedItems,
      completedAt: DateTime.now(),
    );

    // 2. Fetch booking for metadata
    final bookingSnap = await _firestore.collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) throw Exception('Booking not found');
    final data = bookingSnap.data()!;
    final carId     = data['carId'] as String? ?? '';
    final renterId  = data['renterId'] as String? ?? '';
    final carName   = data['carName']  as String? ?? '';
    final endDate   = (data['endDate'] as Timestamp).toDate();
    final deposit   = finalInspection.depositCollected;

    final batch = _firestore.batch();
    final bookingRef = _firestore.collection('bookings').doc(bookingId);

    // 3. Update booking status
    batch.update(bookingRef, {
      'status': 'active',
      'tripStartedAt': FieldValue.serverTimestamp(),
      'cashPayments.depositPaidToHost': true,
      'cashPayments.depositPaidAmount': deposit,
      'cashPayments.depositPaidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4. Write inspection doc
    final inspectionRef = bookingRef.collection('inspections').doc('pre_trip');
    batch.set(inspectionRef, finalInspection.toMap());

    // 5. Timeline event
    _addTimelineEvent(
      batch, bookingId, 'active',
      'Car handed over. Security deposit of PKR ${deposit.toStringAsFixed(0)} '
      'collected. Pre-trip inspection completed and signed by both parties.',
      hostId,
    );

    // 6. Renter notification
    if (renterId.isNotEmpty) {
      final notifRef = _firestore
          .collection('users')
          .doc(renterId)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'trip_started',
        'title': 'Trip Started 🚗',
        'body': 'Your trip for $carName is now active. Return by ${_fmt(endDate)}.',
        'bookingId': bookingId,
        'isRead': false,
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // 7. Write conversation system message (outside batch — best-effort)
    try {
      final now = DateTime.now();
      final convId = '${carId}_$renterId';
      
      await ChatService().updateConversationBookingStatus(
        conversationId: convId,
        bookingStatus: 'active',
      );
      await ChatService().postSystemMessage(
        conversationId: convId,
        text: '🚗 Trip started on ${_fmt(now)}. '
            'Security deposit of PKR ${deposit.toStringAsFixed(0)} confirmed received. '
            'Safe travels!',
      );
    } catch (_) {}
  }

  // ──────────────────────── COMPLETE TRIP ─────────────────────────────────

  Future<void> completeTrip({
    required String bookingId,
    required String carId,
    required PostTripInspection postInspection,
    required CashSettlement settlement,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final hostId = currentUser.uid;

    // 1. Upload post-trip photos
    final updatedItems = <String, InspectionItem>{};
    for (final entry in postInspection.items.entries) {
      final area = entry.key;
      final item = entry.value;
      final uploadedUrls = <String>[];
      for (int i = 0; i < item.photoUrls.length; i++) {
        final path = item.photoUrls[i];
        if (path.startsWith('http')) {
          uploadedUrls.add(path);
          continue;
        }
        try {
          final file = File(path);
          final ts = DateTime.now().millisecondsSinceEpoch;
          final ref = FirebaseStorage.instance
              .ref('inspections/$bookingId/post_trip/${area}_$ts.jpg');
          await ref.putFile(file);
          uploadedUrls.add(await ref.getDownloadURL());
        } catch (_) {
          uploadedUrls.add(path);
        }
      }
      updatedItems[area] = item.copyWith(photoUrls: uploadedUrls);
    }

    final finalPost = postInspection.copyWith(
        items: updatedItems, completedAt: DateTime.now());

    // 2. Fetch booking metadata
    final bookingSnap =
        await _firestore.collection('bookings').doc(bookingId).get();
    if (!bookingSnap.exists) throw Exception('Booking not found');
    final data = bookingSnap.data()!;
    final renterId = data['renterId'] as String? ?? '';
    final carName  = data['carName']  as String? ?? '';

    final batch = _firestore.batch();
    final bookingRef = _firestore.collection('bookings').doc(bookingId);

    // 3. Update booking to completed
    batch.update(bookingRef, {
      'status': 'completed',
      'tripEndedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'cashPayments.rentPaidToHost': true,
      'cashPayments.rentPaidAmount': settlement.rentPaid,
      'cashPayments.rentPaidAt': FieldValue.serverTimestamp(),
      'cashPayments.depositRefundedToRenter': true,
      'cashPayments.depositRefundedAmount': settlement.depositRefunded,
      'cashPayments.depositRefundedAt': FieldValue.serverTimestamp(),
      'cashPayments.damageDeduction': settlement.damageDeduction,
    });

    // 4. Write post-trip inspection
    final postRef = bookingRef.collection('inspections').doc('post_trip');
    batch.set(postRef, finalPost.toMap());

    // 5. Remove from car's bookedDateRanges
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate   = (data['endDate']   as Timestamp).toDate();
    final carRef = _firestore.collection('listings').doc(carId);
    batch.update(carRef, {
      'bookedDateRanges': FieldValue.arrayRemove([
        {
          'start': Timestamp.fromDate(startDate),
          'end':   Timestamp.fromDate(endDate),
          'bookingId': bookingId,
        }
      ]),
    });

    // 6. Timeline event
    _addTimelineEvent(
      batch,
      bookingId,
      'completed',
      'Trip completed. Rent PKR ${settlement.rentPaid.toStringAsFixed(0)} collected. '
      'Deposit PKR ${settlement.depositRefunded.toStringAsFixed(0)} refunded. '
      'Damage deduction: PKR ${settlement.damageDeduction.toStringAsFixed(0)}.',
      hostId,
    );

    // Commit main trip updates first
    await batch.commit();

    // 7. Scheduled review notifications (sendAt = now + 2h)
    // Put these in a separate try-catch so permission errors don't block trip completion
    try {
      final notifBatch = _firestore.batch();
      final sendAt = Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2)));

      if (renterId.isNotEmpty) {
        final renterNotifSched = _firestore.collection('scheduledNotifications').doc();
        notifBatch.set(renterNotifSched, {
          'targetUserId': renterId,
          'type': 'review_prompt',
          'title': 'How was your trip? ⭐',
          'body': 'Rate $carName and your host to help the RozRides community.',
          'bookingId': bookingId,
          'sendAt': sendAt,
          'sent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final hostNotifSched = _firestore.collection('scheduledNotifications').doc();
      notifBatch.set(hostNotifSched, {
        'targetUserId': hostId,
        'type': 'review_prompt',
        'title': 'Leave a review ⭐',
        'body': 'How was ${data['renterName'] ?? 'the renter'} as a renter? Leave a review to help other hosts.',
        'bookingId': bookingId,
        'sendAt': sendAt,
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await notifBatch.commit();
    } catch (_) {
      // Ignore notification schedule failure (usually due to missing Firestore rules)
    }

    // 8. System message in conversation (best-effort)
    try {
      final convId = '${carId}_$renterId';
      await ChatService().updateConversationBookingStatus(
        conversationId: convId,
        bookingStatus: 'completed',
      );
      await ChatService().postSystemMessage(
        conversationId: convId,
        text: '✅ Trip completed on ${_fmt(DateTime.now())}. '
            'All cash settled. Thanks for using RozRides!',
      );
    } catch (_) {}
  }

  // ─────────────────── STREAM PRE-TRIP INSPECTION ─────────────────────────

  Future<PreTripInspection?> fetchPreTripInspection(String bookingId) async {
    try {
      final doc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .collection('inspections')
          .doc('pre_trip')
          .get();
      if (!doc.exists) return null;
      return PreTripInspection.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────── RAISE DISPUTE ────────────────────────────

  Future<void> raiseDispute({
    required BookingModel booking,
    required String description,
    required double renterBelievesAmount,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final bookingId = booking.id;
    final preRef  = 'bookings/$bookingId/inspections/pre_trip';
    final postRef = 'bookings/$bookingId/inspections/post_trip';

    final claimRef = _firestore.collection('damageClaims').doc();
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final now = FieldValue.serverTimestamp();

    final claim = DamageClaim(
      claimId: claimRef.id,
      bookingId: bookingId,
      carId: booking.carId,
      hostId: booking.hostId,
      renterId: booking.renterId,
      raisedBy: currentUser.uid,
      description: description,
      hostClaimedDeduction: booking.cashPayments['damageDeduction']?.toDouble() ?? 0,
      renterAgreedDeduction: renterBelievesAmount,
      preInspectionRef: preRef,
      postInspectionRef: postRef,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // 1. Write damage claim
    batch.set(claimRef, claim.toMap());

    // 2. Update booking status
    batch.update(bookingRef, {
      'status': 'disputed',
      'updatedAt': now,
    });

    // 3. Timeline event
    _addTimelineEvent(
      batch, bookingId, 'disputed',
      'Dispute raised by renter. Host claimed PKR ${claim.hostClaimedDeduction.toStringAsFixed(0)}. Renter believes correct amount is PKR ${renterBelievesAmount.toStringAsFixed(0)}.',
      currentUser.uid,
    );

    // 4. Admin alert
    final adminAlertRef = _firestore.collection('adminAlerts').doc();
    batch.set(adminAlertRef, {
      'type': 'damage_dispute',
      'bookingId': bookingId,
      'claimId': claimRef.id,
      'renterName': booking.renterName,
      'hostId': booking.hostId,
      'message': 'New dispute raised for booking $bookingId. Review required.',
      'createdAt': now,
      'resolved': false,
    });

    // 5. Notify host
    final hostNotifRef = _firestore
        .collection('users')
        .doc(booking.hostId)
        .collection('notifications')
        .doc();
    batch.set(hostNotifRef, {
      'type': 'dispute_raised',
      'title': 'Renter raised a dispute',
      'body':
          'The renter has raised a dispute regarding the damage claim. RozRides admin will review and contact both parties.',
      'bookingId': bookingId,
      'isRead': false,
      'isUnread': true,
      'createdAt': now,
    });

    await batch.commit();
  }

  // ──────────────────────────── SUBMIT REVIEW ────────────────────────────

  Future<void> submitReview({
    required String bookingId,
    required String revieweeId,
    required String? carId,
    required String type, // renter_to_host | host_to_renter
    required double rating,
    required String comment,
    required String reviewerName,
    String? reviewerPhoto,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final reviewerId = currentUser.uid;

    // Check for duplicate
    final existing = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .where('reviewerId', isEqualTo: reviewerId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw Exception('ALREADY_REVIEWED');

    final reviewRef = _firestore.collection('reviews').doc();
    final bookingRef = _firestore.collection('bookings').doc(bookingId);
    final now = FieldValue.serverTimestamp();

    final review = ReviewModel(
      reviewId: reviewRef.id,
      bookingId: bookingId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      carId: carId,
      type: type,
      overallRating: rating,
      comment: comment,
      reviewerName: reviewerName,
      reviewerPhoto: reviewerPhoto,
      isPublic: false,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(reviewRef, review.toMap());

    // Update booking reviewStatus
    final statusField = type == 'renter_to_host' ? 'renterSubmitted' : 'hostSubmitted';
    batch.update(bookingRef, {
      'reviewStatus.$statusField': true,
      'updatedAt': now,
    });

    await batch.commit();

    // Check if both submitted → make both public + update aggregates
    final bookingSnap = await bookingRef.get();
    final reviewStatus =
        bookingSnap.data()?['reviewStatus'] as Map<String, dynamic>? ?? {};
    final bothSubmitted =
        reviewStatus['renterSubmitted'] == true &&
        reviewStatus['hostSubmitted'] == true;

    if (bothSubmitted) {
      await _publishReviewsAndUpdateAggregates(bookingId, carId, revieweeId, type);
    } else {
      // Schedule 7-day window to auto-publish
      final sendAt = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)));
      await _firestore.collection('scheduledNotifications').add({
        'type': 'auto_publish_reviews',
        'bookingId': bookingId,
        'sendAt': sendAt,
        'sent': false,
        'createdAt': now,
      });
    }
  }

  Future<void> _publishReviewsAndUpdateAggregates(
    String bookingId,
    String? carId,
    String revieweeId,
    String type,
  ) async {
    // Publish all reviews for this booking
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .get();
    final publishBatch = _firestore.batch();
    for (final doc in reviewsSnap.docs) {
      publishBatch.update(doc.reference, {'isPublic': true});
    }
    await publishBatch.commit();

    // Update car aggregate (renter_to_host reviews have a carId)
    if (carId != null && type == 'renter_to_host') {
      await _updateCarRatingAggregate(carId);
    }
    // Update user aggregate
    await _updateUserRatingAggregate(revieweeId, type);
  }

  Future<void> _updateCarRatingAggregate(String carId) async {
    final snap = await _firestore
        .collection('reviews')
        .where('carId', isEqualTo: carId)
        .where('isPublic', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return;
    final ratings = snap.docs
        .map((d) => (d.data()['overallRating'] as num).toDouble())
        .toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    final breakdown = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
    for (final r in ratings) {
      final key = r.round().clamp(1, 5).toString();
      breakdown[key] = (breakdown[key] ?? 0) + 1;
    }
    await _firestore.collection('listings').doc(carId).update({
      'averageRating': double.parse(avg.toStringAsFixed(1)),
      'totalReviews': ratings.length,
      'ratingBreakdown': breakdown,
    });
  }

  Future<void> _updateUserRatingAggregate(String userId, String type) async {
    final snap = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .where('isPublic', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return;
    final ratings = snap.docs
        .map((d) => (d.data()['overallRating'] as num).toDouble())
        .toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    if (type == 'renter_to_host') {
      await _firestore.collection('users').doc(userId).update({
        'hostRating': double.parse(avg.toStringAsFixed(1)),
        'hostReviewCount': ratings.length,
      });
    } else {
      await _firestore.collection('users').doc(userId).update({
        'renterRating': double.parse(avg.toStringAsFixed(1)),
        'renterReviewCount': ratings.length,
      });
    }
  }

  // Fetch public reviews for a car
  Future<List<ReviewModel>> fetchCarReviews(String carId,
      {int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('carId', isEqualTo: carId)
          .where('isPublic', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) => ReviewModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching car reviews: $e');
      return [];
    }
  }

  // Fetch public reviews written about a user
  Future<List<ReviewModel>> fetchUserReviews(String userId,
      String type, {int limit = 50}) async {
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('revieweeId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .where('isPublic', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) => ReviewModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching user reviews: $e');
      return [];
    }
  }

  // Check if current user already reviewed this booking
  Future<bool> hasReviewed(String bookingId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('reviewerId', isEqualTo: uid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ────────────────────────── UTILITIES ───────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

