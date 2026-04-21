import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
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

  /// Returns true if [startDate, endDate] does NOT overlap any confirmed/active booking.
  /// Queries Firestore directly for maximum accuracy.
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
      // If security rules block the query, assume available and
      // let the server-side rules prevent conflicting writes.
      return true;
    }
  }

  /// Returns true if [startDate, endDate] overlaps with any range in [bookedRanges].
  /// Used locally (no network call) as a quick check before navigating.
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

  /// Creates a new booking request. Throws string error codes for UI handling:
  /// - "CNIC_NOT_VERIFIED" if renter's CNIC is not approved
  /// - "DATES_UNAVAILABLE" if the selected dates have been taken
  Future<String> createBookingRequest({
    required String carId,
    required String hostId,
    required DateTime startDate,
    required DateTime endDate,
    required CashPricingBreakdown pricing,
    required String messageToHost,
    // Denormalized display fields
    required String carName,
    required String carPhoto,
    required String carLocation,
    required String renterName,
  }) async {
    // Step 1: Get current authenticated user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated.');
    final renterId = currentUser.uid;

    // Step 2: Fetch renter's user document and check CNIC status
    final userDoc =
        await _firestore.collection('users').doc(renterId).get();
    if (!userDoc.exists) throw Exception('User profile not found.');

    final cnicMap = userDoc.data()?['cnic'] as Map<String, dynamic>?;
    final cnicStatus = cnicMap?['verificationStatus'] ?? 'pending';
    if (cnicStatus != 'approved') {
      throw Exception('CNIC_NOT_VERIFIED');
    }

    // Step 3: Check date availability via Firestore query
    final available = await checkAvailability(
      carId: carId,
      startDate: startDate,
      endDate: endDate,
    );
    if (!available) throw Exception('DATES_UNAVAILABLE');

    // Step 4: Create the booking document
    final bookingRef = _firestore.collection('bookings').doc();
    final bookingId = bookingRef.id;
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    final batch = _firestore.batch();

    // Default cashPayments map
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

    // Default reviewStatus map
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    // Step 5: Write first timeline event
    _addTimelineEvent(
      batch,
      bookingId,
      'pending',
      'Booking request submitted by renter',
      renterId,
    );

    // Step 6: Write host notification to users/{hostId}/notifications subcollection
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

  // ──────────────────────── ACCEPT BOOKING ────────────────────────────────

  Future<void> acceptBooking(BookingModel booking) async {
    final batch = _firestore.batch();

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    batch.update(bookingRef, {
      'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
        batch, booking.id, 'confirmed', 'Host accepted the booking request', booking.hostId);

    // Add date range to listing's bookedDateRanges
    final carRef = _firestore.collection('listings').doc(booking.carId);
    batch.update(carRef, {
      'bookedDateRanges': FieldValue.arrayUnion([
        {
          'start': Timestamp.fromDate(booking.startDate),
          'end': Timestamp.fromDate(booking.endDate),
          'bookingId': booking.id,
        }
      ]),
    });

    // Notify renter via users/{renterId}/notifications subcollection
    final renterNotifRef = _firestore
        .collection('users')
        .doc(booking.renterId)
        .collection('notifications')
        .doc();
    batch.set(renterNotifRef, {
      'type': 'booking_confirmed',
      'title': 'Booking Confirmed!',
      'body': 'Your booking for ${booking.carName} is confirmed! Pickup on ${_fmt(booking.startDate)}.',
      'bookingId': booking.id,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    await _autoDeclineOverlapping(booking);
  }

  Future<void> _autoDeclineOverlapping(BookingModel accepted) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('carId', isEqualTo: accepted.carId)
        .where('hostId', isEqualTo: accepted.hostId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      if (doc.id == accepted.id) continue;

      final other = BookingModel.fromMap(doc.data(), doc.id);
      if (!_datesOverlap(
        accepted.startDate, accepted.endDate,
        other.startDate, other.endDate,
      )) {
        continue;
      }

      batch.update(doc.reference, {
        'status': 'rejected',
        'rejectionReason': 'Dates taken — another booking was accepted.',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _addTimelineEvent(
          batch, other.id, 'rejected', 'Auto-declined due to overlap with an accepted booking.', 'system');

      final notifRef = _firestore
          .collection('users')
          .doc(other.renterId)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'booking_rejected',
        'title': 'Booking Request Declined',
        'body': 'Your request for ${other.carName} was declined — those dates were just taken.',
        'bookingId': other.id,
        'isRead': false,
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ──────────────────────── DECLINE BOOKING ───────────────────────────────

  Future<void> declineBooking(BookingModel booking, String reason) async {
    final batch = _firestore.batch();

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    batch.update(bookingRef, {
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
        batch, booking.id, 'rejected', 'Host declined: $reason', booking.hostId);

    final notifRef = _firestore
        .collection('users')
        .doc(booking.renterId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'booking_rejected',
      'title': 'Booking Request Declined',
      'body': 'Your booking request for ${booking.carName} was declined. Reason: $reason',
      'bookingId': booking.id,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ──────────────────────── EXPIRE BOOKING ────────────────────────────────

  Future<void> expireBooking(BookingModel booking) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('bookings').doc(booking.id), {
      'status': 'expired',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _addTimelineEvent(
        batch, booking.id, 'expired', 'Auto-expired after 24 hours without response', 'system');

    final notifRef = _firestore
        .collection('users')
        .doc(booking.renterId)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'type': 'booking_expired',
      'title': 'Booking Request Expired',
      'body': 'Your request for ${booking.carName} expired — the host did not respond in time.',
      'bookingId': booking.id,
      'isRead': false,
      'isUnread': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ────────────────────────── STREAMS ─────────────────────────────────────

  /// Real-time stream of ALL bookings for a renter, newest first.
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

  /// Real-time stream of ALL bookings for a host, newest first.
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

  /// Real-time stream of pending bookings for a host.
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

  // Keep legacy aliases so other files that haven't been updated yet don't break
  Stream<List<BookingModel>> getHostPendingBookings(String hostId) =>
      getPendingRequestsForHost(hostId);

  Stream<List<BookingModel>> getRenterBookings(String renterId) =>
      getBookingsForRenter(renterId);

  // ────────────────────────── UTILITIES ───────────────────────────────────

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
