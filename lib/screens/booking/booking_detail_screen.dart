import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../../utils/booking_status_utils.dart';
import '../trip/active_trip_screen.dart';
import '../trip/pre_trip_inspection_screen.dart';
import 'cancellation_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final BookingService _service = BookingService();
  Map<String, dynamic>? _otherPartyData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
      stream: _service.streamBooking(widget.bookingId),
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
    final List<Widget> buttons = [];

    if (isHost) {
      if (booking.status == 'confirmed') {
        final canStart = !DateTime.now().isBefore(
            booking.startDate.subtract(const Duration(hours: 2)));
        buttons.add(_actionBtn(
          label: canStart
              ? 'Start Handover'
              : 'Available on ${_fmt(booking.startDate)}',
          color: canStart ? const Color(0xFF16A34A) : Colors.grey.shade400,
          onPressed: canStart
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PreTripInspectionScreen(booking: booking),
                    ),
                  )
              : null,
        ));
      }
      if (booking.status == 'active') {
        buttons.add(_actionBtn(
          label: '🚗 View Active Trip',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveTripScreen(bookingId: booking.id),
            ),
          ),
        ));
        buttons.add(_actionBtn(
          label: 'Complete Return',
          color: Colors.blue.shade700,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Return flow coming in Phase 7'))),
        ));
      }
    } else {
      if (booking.status == 'active') {
        buttons.add(_actionBtn(
          label: '🚗 View Active Trip',
          color: const Color(0xFF7C3AED),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveTripScreen(bookingId: booking.id),
            ),
          ),
        ));
      }
      if (booking.status == 'pending') {
        buttons.add(_actionBtn(
          label: 'Cancel Request',
          color: Colors.red.shade600,
          outlined: true,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CancellationScreen(bookingId: booking.id, cancelledBy: 'renter'))),
        ));
      }
      if (booking.status == 'confirmed') {
        buttons.add(_actionBtn(
          label: 'Cancel Booking',
          color: Colors.red.shade600,
          outlined: true,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CancellationScreen(bookingId: booking.id, cancelledBy: 'renter'))),
        ));
      }
      if (booking.status == 'completed' && booking.reviewStatus['renterSubmitted'] != true) {
        buttons.add(_actionBtn(
          label: 'Leave a Review',
          color: const Color(0xFF7C3AED),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reviews coming in Phase 9'))),
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
