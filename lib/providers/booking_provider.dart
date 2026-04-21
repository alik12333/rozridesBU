import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

enum BookingActionStatus { idle, loading, success, error }

class BookingProvider extends ChangeNotifier {
  final BookingService _service = BookingService();

  // ─── State ──────────────────────────────────────────────────────────────
  List<BookingModel> _hostPendingBookings = [];
  List<BookingModel> _renterBookings      = [];
  BookingActionStatus actionStatus        = BookingActionStatus.idle;
  String? errorMessage;
  String? _activeHostId;
  String? _activeRenterId;

  List<BookingModel> get hostPendingBookings => _hostPendingBookings;
  List<BookingModel> get renterBookings      => _renterBookings;

  // Renter bookings grouped by status
  List<BookingModel> get pendingBookings   =>
      _renterBookings.where((b) => b.status == 'pending').toList();
  List<BookingModel> get confirmedBookings =>
      _renterBookings.where((b) => b.status == 'confirmed').toList();
  List<BookingModel> get activeBookings    =>
      _renterBookings.where((b) => b.status == 'active').toList();
  List<BookingModel> get completedBookings =>
      _renterBookings.where((b) => b.status == 'completed').toList();
  List<BookingModel> get cancelledBookings =>
      _renterBookings.where((b) => b.status == 'cancelled' || b.status == 'rejected' || b.status == 'expired').toList();

  // ─── Stream subscriptions ───────────────────────────────────────────────
  StreamSubscription<List<BookingModel>>? _hostSub;
  StreamSubscription<List<BookingModel>>? _renterSub;

  // ─── Start listening ─────────────────────────────────────────────────────

  void listenToHostBookings(String hostId) {
    if (_activeHostId == hostId) return;
    _activeHostId = hostId;

    _hostSub?.cancel();
    _hostSub = _service.getHostPendingBookings(hostId).listen((bookings) async {
      // Lazy expiry: mark any expired pending bookings
      for (final b in bookings) {
        if (b.isExpired) {
          await _service.expireBooking(b);
        }
      }
      _hostPendingBookings =
          bookings.where((b) => !b.isExpired).toList();
      notifyListeners();
    });
  }

  void listenToRenterBookings(String renterId) {
    if (_activeRenterId == renterId) return;
    _activeRenterId = renterId;

    _renterSub?.cancel();
    _renterSub = _service.getRenterBookings(renterId).listen((bookings) async {
      // Lazy expiry
      for (final b in bookings) {
        if (b.isExpired) {
          await _service.expireBooking(b);
        }
      }
      _renterBookings = bookings;
      notifyListeners();
    });
  }

  void stopListening() {
    _hostSub?.cancel();
    _renterSub?.cancel();
    _activeHostId = null;
    _activeRenterId = null;
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<bool> acceptBooking(BookingModel booking) async {
    return _runAction(() => _service.acceptBooking(booking));
  }

  Future<bool> declineBooking(BookingModel booking, String reason) async {
    return _runAction(() => _service.declineBooking(booking, reason));
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
      errorMessage = e.toString();
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
