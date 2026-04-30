import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../models/post_inspection_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../../utils/booking_status_utils.dart';
import '../trip/active_trip_screen.dart';
import '../trip/cash_settlement_screen.dart';
import '../trip/post_trip_inspection_screen.dart';
import '../trip/pre_trip_inspection_screen.dart';
import '../reviews/submit_review_screen.dart';
import 'cancellation_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final BookingService _service = BookingService();
  late final Stream<BookingModel?> _bookingStream;
  Map<String, dynamic>? _otherPartyData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bookingStream = _service.streamBooking(widget.bookingId);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOtherParty(String uid) async {
    if (_otherPartyData != null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted && doc.exists) setState(() => _otherPartyData = doc.data());
    } catch (_) {}
  }

  Future<void> _navigateToReturn(BuildContext context, BookingModel booking) async {
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
      content: Text('Loading inspection data…'),
      duration: Duration(seconds: 2),
    ));
    final pre = await _service.fetchPreTripInspection(booking.id);
    if (!context.mounted) return;
    if (pre == null) {
      snack.showSnackBar(const SnackBar(
        content: Text('Pre-trip inspection not found. Cannot start return.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostTripInspectionScreen(
          booking: booking,
          preInspection: pre,
        ),
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('MMM d, yyyy').format(d);
  String _fmtFull(DateTime d) => DateFormat('MMM d, yyyy • h:mm a').format(d);
  String _pkr(double v) => 'PKR ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  String _countdownText(Duration r) {
    if (r <= Duration.zero) return 'Expired';
    return '${r.inHours}h ${r.inMinutes % 60}m left';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    return StreamBuilder<BookingModel?>(
      stream: _bookingStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Booking')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final booking = snap.data!;
        final isHost = currentUser?.id == booking.hostId;
        final otherPartyId = isHost ? booking.renterId : booking.hostId;
        _loadOtherParty(otherPartyId);

        final remaining = booking.expiresAt.difference(DateTime.now());
        final statusColor = getStatusColor(booking.status);
        final cnicStatus = _otherPartyData?['cnic']?['verificationStatus'] ?? 'pending';

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            title: Text('Booking #${booking.id.substring(0, 8).toUpperCase()}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Banner ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: statusColor.withValues(alpha: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getStatusLabel(booking.status),
                          style: GoogleFonts.outfit(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        booking.status == 'pending'
                            ? 'Expires in ${_countdownText(remaining)}'
                            : getStatusDescription(booking.status),
                        style: TextStyle(color: statusColor.withValues(alpha: 0.8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Section 1: Car Details ────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Car Details'),
                    const SizedBox(height: 12),
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: booking.carPhoto.isNotEmpty
                            ? Image.network(booking.carPhoto, width: 80, height: 65, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _carPlaceholder())
                            : _carPlaceholder(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.carName,
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(child: Text(booking.carLocation,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      )),
                    ]),
                  ],
                )),
                const SizedBox(height: 12),

                // ── Section 2: Trip Dates ────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Trip Dates'),
                    const SizedBox(height: 12),
                    _detailRow(Icons.login_rounded, 'Pickup', _fmt(booking.startDate)),
                    _detailRow(Icons.logout_rounded, 'Return', _fmt(booking.endDate)),
                    _detailRow(Icons.calendar_today_outlined, 'Duration',
                        '${booking.totalDays} day${booking.totalDays > 1 ? 's' : ''}'),
                  ],
                )),
                const SizedBox(height: 12),

                // ── Section 3: Other Party ───────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(isHost ? 'Renter' : 'Host'),
                    const SizedBox(height: 12),
                    Row(children: [
                      _avatarWidget(_otherPartyData),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _otherPartyData?['fullName'] ??
                                (isHost ? booking.renterName : 'Host'),
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (isHost) ...[
                            const SizedBox(height: 4),
                            _cnicBadge(cnicStatus == 'approved'),
                          ],
                        ],
                      )),
                    ]),
                  ],
                )),
                const SizedBox(height: 12),

                // ── Section 4: Cash Schedule ─────────────────────────────
                _cashScheduleCard(booking),
                const SizedBox(height: 12),

                // ── Section 5: Timeline ──────────────────────────────────
                _timelineSection(),
                const SizedBox(height: 12),

                // ── Section 6: Booking Reference ─────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Booking Reference'),
                    const SizedBox(height: 8),
                    Text('ID: ${booking.id}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    Text('Created: ${_fmtFull(booking.createdAt)}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                )),
              ],
            ),
          ),
          bottomNavigationBar: _buildActions(context, booking, isHost),
        );
      },
    );
  }

  Widget _cashScheduleCard(BookingModel booking) {
    final cp = booking.cashPayments;
    final depositPaid = cp['depositPaidToHost'] == true;
    final rentPaid = cp['rentPaidToHost'] == true;
    final depositRefunded = cp['depositRefundedToRenter'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Cash Schedule'),
          const SizedBox(height: 14),
          _cashItem('At pickup: Security deposit', _pkr(booking.securityDeposit), depositPaid),
          _cashItem('At return: Car rental payment', _pkr(booking.totalRent), rentPaid),
          if (booking.status == 'flagged')
            _cashItem('At return: Deposit refund', '⏳ Pending admin decision', false)
          else
            _cashItem('At return: Deposit refund to renter', _pkr(booking.securityDeposit), depositRefunded),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net rental income', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              Text(_pkr(booking.totalRent),
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: Colors.green.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cashItem(String label, String amount, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Colors.green.shade100 : Colors.grey.shade100,
              border: Border.all(color: done ? Colors.green.shade400 : Colors.grey.shade300),
            ),
            child: Icon(
              done ? Icons.check : Icons.circle_outlined,
              size: 14,
              color: done ? Colors.green.shade600 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13,
                  color: done ? Colors.green.shade600 : Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _timelineSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamTimeline(widget.bookingId),
      builder: (context, snap) {
        final events = snap.data ?? [];
        if (events.isEmpty) return const SizedBox.shrink();
        return _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Timeline'),
            const SizedBox(height: 14),
            ...events.map((e) {
              final status = e['status'] as String? ?? '';
              final note = e['note'] as String? ?? '';
              final ts = e['timestamp'] as Timestamp?;
              final date = ts != null ? DateFormat('MMM d \'at\' h:mm a').format(ts.toDate()) : '';
              final color = getStatusColor(status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      Container(width: 12, height: 12,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                      Container(width: 2, height: 32, color: Colors.grey.shade200),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(getStatusLabel(status),
                            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                        Text(note, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        Text(date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ],
                    )),
                  ],
                ),
              );
            }),
          ],
        ));
      },
    );
  }

  Widget? _buildActions(BuildContext context, BookingModel booking, bool isHost) {
    if (booking.status == 'flagged') {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel, color: Colors.purple.shade600),
              const SizedBox(height: 8),
              Text(
                'This trip is under review. RozRides admin will notify you of the outcome within 24 hours.\n\nDo not exchange any cash until you receive the admin\'s decision.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.purple.shade900, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> buttons = [];

    if (isHost) {
      // ── confirmed: show Start Handover OR waiting-for-renter state ─────
      if (booking.status == 'confirmed') {
        if (booking.preHandoverCompleted) {
          // Host done — waiting for renter to press Start Trip
          buttons.add(_waitingBanner(
            icon: Icons.hourglass_top_rounded,
            title: 'Handover Complete',
            message: 'Waiting for the renter to start the trip on their device.',
          ));
        } else {
          final canStart = !DateTime.now().isBefore(
              booking.startDate.subtract(const Duration(hours: 2)));
          buttons.add(_actionBtn(
            label: canStart ? 'Start Handover' : 'Available on ${_fmt(booking.startDate)}',
            color: canStart ? const Color(0xFF16A34A) : Colors.grey.shade400,
            onPressed: canStart
                ? () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PreTripInspectionScreen(booking: booking),
                    ))
                : null,
          ));
        }
      }

      // ── active: view trip OR complete return OR waiting for renter ──────
      if (booking.status == 'active') {
        buttons.add(_actionBtn(
          label: '🚗 View Active Trip',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ActiveTripScreen(bookingId: booking.id),
          )),
        ));
        if (booking.postHandoverCompleted) {
          // Host submitted return — waiting for renter
          buttons.add(_waitingBanner(
            icon: Icons.hourglass_top_rounded,
            title: 'Return Submitted',
            message: 'Waiting for the renter to review and confirm the settlement.',
          ));
        } else {
          buttons.add(_actionBtn(
            label: 'Complete Return',
            color: Colors.blue.shade700,
            onPressed: () => _navigateToReturn(context, booking),
          ));
        }
      }

      // ── completed: host review button ────────────────────────────────────
      if (booking.status == 'completed' &&
          booking.reviewStatus['hostSubmitted'] != true) {
        buttons.add(_actionBtn(
          label: 'Review Renter ⭐',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SubmitReviewScreen(booking: booking, reviewType: 'host_to_renter'),
          )),
        ));
      }
    } else {
      // ────────────────────────── RENTER ACTIONS ───────────────────────────

      // ── confirmed + preHandoverCompleted: show START TRIP ────────────────
      if (booking.status == 'confirmed' && booking.preHandoverCompleted) {
        buttons.add(_actionBtn(
          label: '🚗 START TRIP',
          color: const Color(0xFF16A34A),
          onPressed: () => _renterStartTrip(context, booking),
        ));
      } else if (booking.status == 'confirmed') {
        // Handover not done yet
        buttons.add(_waitingBanner(
          icon: Icons.access_time_rounded,
          title: 'Awaiting Handover',
          message: 'The host will initiate the handover process on their device.',
        ));
        buttons.add(_actionBtn(
          label: 'Cancel Booking',
          color: Colors.red.shade600,
          outlined: true,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CancellationScreen(bookingId: booking.id, cancelledBy: 'renter'))),
        ));
      }

      // ── active: view trip OR review & end trip ───────────────────────────
      if (booking.status == 'active') {
        buttons.add(_actionBtn(
          label: '🚗 View Active Trip',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => ActiveTripScreen(bookingId: booking.id),
          )),
        ));
        if (booking.postHandoverCompleted) {
          buttons.add(_actionBtn(
            label: '🏁 REVIEW & END TRIP',
            color: const Color(0xFF16A34A),
            onPressed: () => _renterReviewReturn(context, booking),
          ));
        }
      }

      // ── pending: cancel request ──────────────────────────────────────────
      if (booking.status == 'pending') {
        buttons.add(_actionBtn(
          label: 'Cancel Request',
          color: Colors.red.shade600,
          outlined: true,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CancellationScreen(bookingId: booking.id, cancelledBy: 'renter'))),
        ));
      }

      // ── completed: renter review button ─────────────────────────────────
      if (booking.status == 'completed' &&
          booking.reviewStatus['renterSubmitted'] != true) {
        buttons.add(_actionBtn(
          label: 'Leave a Review ⭐',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SubmitReviewScreen(booking: booking, reviewType: 'renter_to_host'),
          )),
        ));
      }
    }

    if (buttons.isEmpty) return null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: buttons.map((b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: b)).toList(),
      ),
    );
  }

  /// Renter presses START TRIP after host completes handover.
  Future<void> _renterStartTrip(BuildContext ctx, BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Start Your Trip?'),
        content: const Text('By starting the trip you confirm that the car has been handed over to you and the deposit has been paid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            child: const Text('Start Trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    try {
      await _service.renterStartTrip(booking.id);
      if (ctx.mounted) {
        Navigator.pushReplacement(ctx, MaterialPageRoute(
          builder: (_) => ActiveTripScreen(bookingId: booking.id),
        ));
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('🚗 Trip started! Drive safe.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Renter presses REVIEW & END TRIP after host submits return.
  Future<void> _renterReviewReturn(BuildContext ctx, BookingModel booking) async {
    final snack = ScaffoldMessenger.of(ctx);
    snack.showSnackBar(const SnackBar(
      content: Text('Loading return inspection data…'),
      duration: Duration(seconds: 2),
    ));

    // Load pre-trip inspection
    final pre = await _service.fetchPreTripInspection(booking.id);
    if (!ctx.mounted) return;
    if (pre == null) {
      snack.showSnackBar(const SnackBar(
        content: Text('Could not load inspection data.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Load post-trip inspection from Firestore
    PostTripInspection? postInspection;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .collection('inspections')
          .doc('post_trip')
          .get();
      if (doc.exists) {
        postInspection = PostTripInspection.fromMap(doc.data()!);
      }
    } catch (_) {}

    if (!ctx.mounted) return;
    if (postInspection == null) {
      snack.showSnackBar(const SnackBar(
        content: Text('Return inspection data not ready yet.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Build a comparison result
    final comparison = compareInspections(pre, postInspection);

    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => CashSettlementScreen(
        booking: booking,
        comparison: comparison,
        postInspection: postInspection!,
        hostMode: false,
      ),
    ));
  }

  Widget _waitingBanner({required IconData icon, required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.purple.shade400, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(message, style: TextStyle(color: Colors.purple.shade700, fontSize: 12, height: 1.4)),
          ],
        )),
      ]),
    );
  }

  Widget _actionBtn({required String label, required Color color, VoidCallback? onPressed, bool outlined = false}) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: child,
      );

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold));

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 17, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
      );

  Widget _avatarWidget(Map<String, dynamic>? data) {
    final photo = data?['profilePhoto'] as String?;
    final name = data?['fullName'] as String? ?? '';
    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
      backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
      child: (photo == null || photo.isEmpty)
          ? Text(initials.isEmpty ? '?' : initials,
              style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 18))
          : null,
    );
  }

  Widget _cnicBadge(bool verified) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: verified ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: verified ? Colors.green.shade300 : Colors.red.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(verified ? Icons.verified_user : Icons.warning_amber_rounded,
              size: 12, color: verified ? Colors.green.shade700 : Colors.red.shade700),
          const SizedBox(width: 4),
          Text(verified ? 'CNIC Verified' : 'Unverified',
              style: TextStyle(
                  color: verified ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _carPlaceholder() => Container(
        width: 80, height: 65,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.directions_car, color: Colors.grey.shade400, size: 32),
      );
}
