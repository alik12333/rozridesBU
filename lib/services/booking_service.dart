import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/booking_model.dart';
import '../models/inspection_model.dart';
import '../models/pricing_breakdown_model.dart';

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

      // Create conversation document for future chat (Phase 10)
      final conversationRef = _firestore.collection('conversations').doc(bookingId);
      tx.set(conversationRef, {
        'bookingId': bookingId,
        'hostId': hostId,
        'renterId': renterId,
        'carName': carName,
        'lastMessage': null,
        'lastMessageAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // ── Post-transaction: auto-decline overlapping bookings ─────────────
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<BookingModel>> getBookingsForHost(String hostId) {
    return _firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<BookingModel>> getPendingRequestsForHost(String hostId) {
    return _firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromMap(d.data(), d.id))
            .toList());
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
      await _firestore
          .collection('conversations')
          .doc(bookingId)
          .collection('messages')
          .add({
        'type': 'system',
        'text': '🚗 Trip started on ${_fmt(now)}. '
            'Security deposit of PKR ${deposit.toStringAsFixed(0)} confirmed received. '
            'Safe travels!',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ────────────────────────── UTILITIES ───────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
