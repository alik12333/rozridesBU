import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

enum BookingActionStatus { idle, loading, success, error }

class BookingProvider extends ChangeNotifier {
  final BookingService _service = BookingService();

  // ─── State ──────────────────────────────────────────────────────────────
  List<BookingModel> _hostPendingBookings = [];
  List<BookingModel> _hostAllBookings     = [];
  List<BookingModel> _renterBookings      = [];
  BookingActionStatus actionStatus        = BookingActionStatus.idle;
  String? errorMessage;
  String? _activeHostId;
  String? _activeRenterId;

  List<BookingModel> get hostPendingBookings => _hostPendingBookings;
  List<BookingModel> get hostAllBookings     => _hostAllBookings;
  List<BookingModel> get renterBookings      => _renterBookings;

  // ─── Renter bookings grouped by status ──────────────────────────────────
  List<BookingModel> get pendingBookings =>
      _renterBookings.where((b) => b.status == 'pending').toList();
  List<BookingModel> get confirmedBookings =>
      _renterBookings.where((b) => b.status == 'confirmed').toList();
  List<BookingModel> get activeBookings =>
      _renterBookings.where((b) => b.status == 'active').toList();
  List<BookingModel> get completedBookings =>
      _renterBookings.where((b) => b.status == 'completed').toList();
  List<BookingModel> get cancelledBookings =>
      _renterBookings
          .where((b) =>
              b.status == 'cancelled' ||
              b.status == 'rejected' ||
              b.status == 'expired')
          .toList();

  // Renter tab groupings per spec (Upcoming, Active, Past)
  List<BookingModel> get upcomingBookings =>
      _renterBookings
          .where((b) => b.status == 'pending' || b.status == 'confirmed')
          .toList();

  List<BookingModel> get pastBookings =>
      _renterBookings
          .where((b) =>
              b.status == 'completed' ||
              b.status == 'cancelled' ||
              b.status == 'rejected' ||
              b.status == 'expired')
          .toList();

  // ─── Host bookings grouped by status ────────────────────────────────────
  List<BookingModel> get hostConfirmedBookings =>
      _hostAllBookings.where((b) => b.status == 'confirmed').toList();
  List<BookingModel> get hostActiveBookings =>
      _hostAllBookings.where((b) => b.status == 'active').toList();
  List<BookingModel> get hostPastBookings =>
      _hostAllBookings
          .where((b) =>
              b.status == 'completed' ||
              b.status == 'cancelled' ||
              b.status == 'rejected' ||
              b.status == 'expired')
          .toList();

  // ─── Stream subscriptions ───────────────────────────────────────────────
  StreamSubscription<List<BookingModel>>? _hostPendingSub;
  StreamSubscription<List<BookingModel>>? _hostAllSub;
  StreamSubscription<List<BookingModel>>? _renterSub;

  // ─── Start listening ─────────────────────────────────────────────────────

  void listenToHostBookings(String hostId) {
    if (_activeHostId == hostId) return;
    _activeHostId = hostId;

    // Listen to pending bookings (for badge count)
    _hostPendingSub?.cancel();
    _hostPendingSub =
        _service.getPendingRequestsForHost(hostId).listen((bookings) async {
      for (final b in bookings) {
        if (b.isExpired) {
          await _service.expireBooking(b);
        }
      }
      _hostPendingBookings = bookings.where((b) => !b.isExpired).toList();
      notifyListeners();
    });

    // Listen to all host bookings (for HostBookingsScreen)
    _hostAllSub?.cancel();
    _hostAllSub = _service.getBookingsForHost(hostId).listen((bookings) {
      _hostAllBookings = bookings;
      notifyListeners();
    }, onError: (e) {
      debugPrint('ERROR IN hostAllSub: $e');
    });
  }

  void listenToRenterBookings(String renterId) {
    if (_activeRenterId == renterId) return;
    _activeRenterId = renterId;

    _renterSub?.cancel();
    _renterSub = _service.getRenterBookings(renterId).listen((bookings) async {
      for (final b in bookings) {
        if (b.isExpired) {
          await _service.expireBooking(b);
        }
      }
      _renterBookings = bookings;
      notifyListeners();
    }, onError: (e) {
      debugPrint('ERROR IN renterSub: $e');
    });
  }

  void stopListening() {
    _hostPendingSub?.cancel();
    _hostAllSub?.cancel();
    _renterSub?.cancel();
    _activeHostId = null;
    _activeRenterId = null;
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<bool> acceptBooking(String bookingId) async {
    return _runAction(() => _service.acceptBooking(bookingId));
  }

  Future<bool> declineBooking(BookingModel booking, String reason) async {
    return _runAction(() => _service.declineBooking(booking, reason));
  }

  Future<bool> cancelBooking({
    required String bookingId,
    required String reason,
    required String cancelledBy,
  }) async {
    return _runAction(
      () => _service.cancelBooking(
        bookingId: bookingId,
        reason: reason,
        cancelledBy: cancelledBy,
      ),
    );
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    actionStatus = BookingActionStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      actionStatus = BookingActionStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      actionStatus = BookingActionStatus.error;
      notifyListeners();
      return false;
    }
  }

  void resetActionStatus() {
    actionStatus = BookingActionStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
