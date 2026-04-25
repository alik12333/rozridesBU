import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String bookingId;
  const RequestDetailScreen({super.key, required this.bookingId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final BookingService _service = BookingService();
  late final Stream<BookingModel?> _bookingStream;
  Map<String, dynamic>? _renterData;
  int _renterCompletedTrips = 0;
  bool _renterDataLoading = true;
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

  Future<void> _loadRenterData(String renterId) async {
    if (_renterDataLoading == false) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(renterId)
          .get();

      // Count completed trips as renter
      final tripsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('renterId', isEqualTo: renterId)
          .where('status', isEqualTo: 'completed')
          .get();

      if (mounted) {
        setState(() {
          _renterData = userDoc.data();
          _renterCompletedTrips = tripsSnap.docs.length;
          _renterDataLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _renterDataLoading = false);
    }
  }

  void _showDeclineSheet(BookingModel booking) {
    String? selectedReason;
    final TextEditingController customController = TextEditingController();
    const reasons = [
      'Car unavailable on these dates',
      'Car needs maintenance',
      'Renter profile incomplete',
      'I found a better booking',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isOther = selectedReason == 'Other';
            final canConfirm = selectedReason != null &&
                (selectedReason != 'Other' ||
                    customController.text.trim().isNotEmpty);
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    Text('Why are you declining?',
                        style: GoogleFonts.outfit(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Select a reason — it will be shared with the renter',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 16),
                    ...reasons.map((r) => RadioListTile<String>(
                          title: Text(r),
                          value: r,
                          groupValue: selectedReason,
                          activeColor: const Color(0xFF7C3AED),
                          onChanged: (v) =>
                              setSheetState(() => selectedReason = v),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customController,
                        maxLength: 200,
                        maxLines: 2,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Please explain...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canConfirm
                              ? Colors.red.shade600
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: canConfirm
                            ? () async {
                                Navigator.pop(ctx);
                                final reason = selectedReason == 'Other'
                                    ? customController.text.trim()
                                    : selectedReason!;
                                final ok = await context
                                    .read<BookingProvider>()
                                    .declineBooking(booking, reason);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Booking declined.'
                                          : 'Error declining booking'),
                                      backgroundColor: ok ? Colors.orange : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  if (ok) Navigator.pop(context);
                                }
                              }
                            : null,
                        child: const Text('Confirm Decline',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAcceptSheet(BookingModel booking) {
    final fmt = DateFormat('MMM d, yyyy');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Accept this booking?',
                          style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _infoRow(Icons.person_outline, booking.renterName),
                      const SizedBox(height: 6),
                      _infoRow(Icons.directions_car_outlined, booking.carName),
                      const SizedBox(height: 6),
                      _infoRow(
                        Icons.calendar_today_outlined,
                        '${fmt.format(booking.startDate)} → ${fmt.format(booking.endDate)}',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Collect PKR ${booking.securityDeposit.toStringAsFixed(0)} at pickup, '
                                'and PKR ${booking.totalRent.toStringAsFixed(0)} at return.',
                                style: TextStyle(
                                    color: Colors.amber.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setSheet(() => isLoading = true);
                                Navigator.pop(ctx);
                                final ok = await context
                                    .read<BookingProvider>()
                                    .acceptBooking(booking.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? '✅ Booking accepted!'
                                          : context
                                                  .read<BookingProvider>()
                                                  .errorMessage ??
                                              'Error'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  if (ok) Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Yes, Accept',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BookingModel?>(
      stream: _bookingStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Booking Request')),
            body: const Center(child: Text('Booking not found')),
          );
        }

        final booking = snap.data!;

        // Load renter data once
        if (_renterDataLoading) _loadRenterData(booking.renterId);

        final remaining =
            booking.expiresAt.difference(DateTime.now());
        final isExpiringSoon =
            remaining.inHours < 4 && remaining > Duration.zero;
        final fmt = DateFormat('MMM d, yyyy');
        final fmtCreated = DateFormat('MMM d, yyyy');

        final cnicStatus = _renterData?['cnic']?['verificationStatus'] ?? 'pending';
        final isCnicApproved = cnicStatus == 'approved';
        final memberSince = _renterData?['createdAt'] != null
            ? fmtCreated.format(
                (_renterData!['createdAt'] as Timestamp).toDate())
            : null;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            title: Text('Booking Request',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Renter Profile ───────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Renter Profile',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildRenterAvatar(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.renterName.isNotEmpty
                                      ? booking.renterName
                                      : 'Renter',
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                _CnicStatusBadge(isApproved: isCnicApproved),
                                if (memberSince != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Member since $memberSince',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12)),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '$_renterCompletedTrips completed trip${_renterCompletedTrips != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Section 2: Booking Details ──────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Details',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _detailRow(Icons.directions_car_outlined,
                          'Car', booking.carName),
                      _detailRow(Icons.location_on_outlined,
                          'Location', booking.carLocation),
                      _detailRow(Icons.login_rounded,
                          'Pickup', fmt.format(booking.startDate)),
                      _detailRow(Icons.logout_rounded,
                          'Return', fmt.format(booking.endDate)),
                      _detailRow(
                        Icons.calendar_today_outlined,
                        'Duration',
                        '${booking.totalDays} day${booking.totalDays > 1 ? 's' : ''}',
                      ),
                      // Expiry
                      if (booking.status == 'pending') ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 18,
                                color: isExpiringSoon
                                    ? Colors.red
                                    : Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Expires: ${_expiryText(remaining)}',
                              style: TextStyle(
                                color: isExpiringSoon
                                    ? Colors.red
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Section 3: Your Cash Income ─────────────────────────
                _sectionCard(
                  color: Colors.green.shade50,
                  borderColor: Colors.green.shade200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Cash Income',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800)),
                      const SizedBox(height: 14),
                      _cashRow(
                        'At pickup: Collect security deposit',
                        'PKR ${booking.securityDeposit.toStringAsFixed(0)}',
                        subtitle: '(you return this at end)',
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 10),
                      _cashRow(
                        'At return: Collect car rental',
                        'PKR ${booking.totalRent.toStringAsFixed(0)}',
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 10),
                      _cashRow(
                        'At return: Refund deposit back',
                        '− PKR ${booking.securityDeposit.toStringAsFixed(0)}',
                        subtitle: '(if no damage)',
                        color: Colors.red.shade600,
                      ),
                      const Divider(height: 24),
                      _cashRow(
                        'Your net income',
                        'PKR ${booking.totalRent.toStringAsFixed(0)}',
                        isBold: true,
                        color: Colors.green.shade800,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Section 4: Renter's Message ─────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Renter\'s Message',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (booking.messageToHost.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: const BorderSide(
                                  color: Color(0xFF7C3AED), width: 3),
                              top: BorderSide(color: Colors.grey.shade200),
                              right: BorderSide(color: Colors.grey.shade200),
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Text(
                            booking.messageToHost,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5),
                          ),
                        )
                      else
                        Text(
                          'No message from renter.',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Buttons ──────────────────────────────────────────────
          bottomNavigationBar: booking.status != 'pending'
              ? null
              : Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showDeclineSheet(booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('DECLINE REQUEST',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _showAcceptSheet(booking),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('ACCEPT REQUEST',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildRenterAvatar() {
    final photoUrl = _renterData?['profilePhoto'] as String?;
    final initials = _renterData?['fullName'] != null
        ? (_renterData!['fullName'] as String)
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
      backgroundImage:
          (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Text(initials,
              style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 20))
          : null,
    );
  }

  Widget _sectionCard({
    required Widget child,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null
            ? Border.all(color: borderColor)
            : null,
        boxShadow: [
          if (color == null)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _cashRow(
    String label,
    String amount, {
    String? subtitle,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isBold ? FontWeight.bold : FontWeight.normal)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
        Text(amount,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isBold ? 16 : 14)),
      ],
    );
  }

  String _expiryText(Duration remaining) {
    if (remaining <= Duration.zero) return 'Expired';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─── CNIC Status Badge ─────────────────────────────────────────────────────────

class _CnicStatusBadge extends StatelessWidget {
  final bool isApproved;
  const _CnicStatusBadge({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isApproved
                ? Colors.green.shade300
                : Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 13,
            color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 5),
          Text(
            isApproved ? 'CNIC Verified' : 'Unverified',
            style: TextStyle(
              color:
                  isApproved ? Colors.green.shade700 : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
