import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../models/inspection_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../chat/chat_screen.dart';
import 'post_trip_inspection_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final String bookingId;
  const ActiveTripScreen({super.key, required this.bookingId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final BookingService _service = BookingService();
  Timer? _timer;
  PreTripInspection? _inspection;
  Map<String, dynamic>? _listingData;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadInspection();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
        content: Text('Pre-trip inspection not found.'),
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

  Future<void> _loadInspection() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .collection('inspections')
          .doc('pre_trip')
          .get();
      if (doc.exists && mounted) {
        setState(() => _inspection = PreTripInspection.fromMap(doc.data()!));
      }
    } catch (_) {}
  }

  Future<void> _loadListing(String carId) async {
    if (_listingData != null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(carId)
          .get();
      if (doc.exists && mounted) {
        setState(() => _listingData = doc.data());
      }
    } catch (_) {}
  }

  String _fmtFull(DateTime d) => DateFormat('MMM d, yyyy • h:mm a').format(d);
  String _pkr(double v) => 'PKR ${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Widget _buildCountdown(DateTime endDate) {
    final now = DateTime.now();
    final diff = endDate.difference(now);
    final isOverdue = diff.isNegative;

    if (isOverdue) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 10),
          Text('⚠ OVERDUE',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Please return the car now',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
        ]),
      );
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        Text('RETURN IN',
            style: GoogleFonts.outfit(
                color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _countdownUnit(days.toString(), 'DAYS'),
          const SizedBox(width: 12),
          Text(':', style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _countdownUnit(hours.toString().padLeft(2, '0'), 'HRS'),
          const SizedBox(width: 12),
          Text(':', style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _countdownUnit(mins.toString().padLeft(2, '0'), 'MINS'),
        ]),
      ]),
    );
  }

  Widget _countdownUnit(String value, String label) => Column(children: [
        Text(value,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.2)),
      ]);

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 17, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
      );

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.emergency, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Emergency Contact'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('RozRides Support Helpline:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('+92-300-ROZRIDE',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
          const SizedBox(height: 4),
          const Text('Available 24/7', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showBackDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave this screen?'),
        content: const Text(
            'Your trip is still active. You can return to this screen from your bookings list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showInspectionReport(BuildContext context) {
    if (_inspection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading inspection data...')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InspectionReportSheet(inspection: _inspection!),
    );
  }

  Widget _quickActions(
      {required bool isHost, required BookingModel booking, required String otherName}) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id ?? '';
    final conversationId = '${booking.carId}_${booking.renterId}';

    return Row(children: [
      Expanded(
          child: _actionBtn(
        icon: Icons.chat_bubble_outline,
        label: isHost ? 'Message\nRenter' : 'Message\nHost',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              currentUserId: currentUserId,
            ),
          ),
        ),
      )),
      const SizedBox(width: 10),
      Expanded(
          child: _actionBtn(
        icon: Icons.emergency_outlined,
        label: 'Emergency',
        color: Colors.red.shade600,
        onTap: _showEmergencyDialog,
      )),
      if (!isHost) ...[
        const SizedBox(width: 10),
        Expanded(
            child: _actionBtn(
          icon: Icons.assignment_outlined,
          label: 'Pre-trip\nReport',
          onTap: () => _showInspectionReport(context),
        )),
      ],
    ]);
  }

  Widget _actionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    final c = color ?? const Color(0xFF7C3AED);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    );
  }

  // ── RENTER VIEW ──────────────────────────────────────────────────────────

  Widget _renterView(BookingModel booking) {
    _loadListing(booking.carId);
    final rules = (_listingData?['description'] as String?)?.split('\n') ?? [];
    final hasRules = rules.where((r) => r.trim().isNotEmpty).isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _showBackDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title:
              Text('Your Active Trip', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _showBackDialog,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Car photo
            if (booking.carPhoto.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Image.network(booking.carPhoto,
                    width: double.infinity, height: 220, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _carPlaceholder()),
              )
            else
              _carPlaceholder(height: 220),
            const SizedBox(height: 16),

            // Car name & reg
            Text(booking.carName,
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(booking.carLocation,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            ]),
            const SizedBox(height: 20),

            // Countdown
            _buildCountdown(booking.actualEndDate),
            const SizedBox(height: 12),

            // Return info
            _card(
                child: Column(children: [
              _infoRow(Icons.event, 'Return by', _fmtFull(booking.actualEndDate)),
              _infoRow(Icons.place_outlined, 'Return to', booking.carLocation),
            ])),
            const SizedBox(height: 12),

            // Cash reminder
            _card(
              color: Colors.green.shade50,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle('When you return the car:'),
                Row(children: [
                  const Text('💵 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                      child: RichText(
                          text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                    children: [
                      const TextSpan(text: 'Pay host: '),
                      TextSpan(
                          text: _pkr(booking.totalRent),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' cash'),
                    ],
                  ))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('💵 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                      child: RichText(
                          text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                    children: [
                      const TextSpan(text: 'Receive back: '),
                      TextSpan(
                          text: _pkr(booking.securityDeposit),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' (if no damage)'),
                    ],
                  ))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // Quick actions
            _quickActions(
                isHost: false,
                booking: booking,
                otherName: 'Host'),
            const SizedBox(height: 12),

            // Trip info
            _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Trip Info'),
              if (booking.tripStartedAt != null)
                _infoRow(Icons.play_circle_outline, 'Trip started',
                    _fmtFull(booking.tripStartedAt!)),
              if (_inspection != null) ...[
                _infoRow(Icons.local_gas_station_outlined, 'Fuel at pickup',
                    _inspection!.fuelLevel),
                _infoRow(Icons.speed_outlined, 'Odometer',
                    '${_inspection!.odometerReading} km'),
              ],
            ])),

            // Car rules
            if (hasRules) ...[
              const SizedBox(height: 12),
              _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle('Car Rules'),
                ...rules
                    .where((r) => r.trim().isNotEmpty)
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                    child: Text(r.trim(),
                                        style: const TextStyle(fontSize: 13, height: 1.4))),
                              ]),
                        )),
              ])),
            ],
          ]),
        ),
      ),
    );
  }

  // ── HOST VIEW ────────────────────────────────────────────────────────────

  Widget _hostView(BookingModel booking) {
    final depositAmount =
        (booking.cashPayments['depositPaidAmount'] ?? booking.securityDeposit)
            .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Car Currently Rented',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Car photo
          if (booking.carPhoto.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Image.network(booking.carPhoto,
                  width: double.infinity, height: 200, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _carPlaceholder()),
            )
          else
            _carPlaceholder(height: 200),
          const SizedBox(height: 16),

          Text(booking.carName,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Rented to badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text('Rented to: ${booking.renterName} ✓',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),

          // Deposit status
          _card(
            color: Colors.blue.shade50,
            child: Row(children: [
              Icon(Icons.verified_outlined, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Security deposit collected',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                const SizedBox(height: 2),
                Text(_pkr(depositAmount),
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800)),
              ])),
              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 24),
            ]),
          ),
          const SizedBox(height: 12),

          // Countdown
          _buildCountdown(booking.actualEndDate),
          const SizedBox(height: 12),

          // Return info
          _card(
              child: Column(children: [
            _infoRow(Icons.event, 'Return by', _fmtFull(booking.actualEndDate)),
          ])),
          const SizedBox(height: 12),

          // Cash to collect at return
          _card(
            color: Colors.amber.shade50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Cash to collect at return:'),
              RichText(
                  text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
                children: [
                  TextSpan(
                      text: _pkr(booking.totalRent),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' from ${booking.renterName}'),
                ],
              )),
              const SizedBox(height: 6),
              RichText(
                  text: TextSpan(
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'Then refund '),
                  TextSpan(
                      text: _pkr(booking.securityDeposit),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' if no damage'),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // Quick actions
          _quickActions(
              isHost: true, booking: booking, otherName: booking.renterName),
          const SizedBox(height: 12),

          // Complete return button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Complete Return',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => _navigateToReturn(context, booking),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _carPlaceholder({double height = 180}) => Container(
        width: double.infinity,
        height: height,
        color: Colors.grey.shade200,
        child: Icon(Icons.directions_car, size: 64, color: Colors.grey.shade400),
      );

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    return StreamBuilder<BookingModel?>(
      stream: _service.streamBooking(widget.bookingId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Active Trip')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final booking = snap.data!;
        final isHost = currentUser?.id == booking.hostId;
        return isHost ? _hostView(booking) : _renterView(booking);
      },
    );
  }
}

// ─── Pre-Trip Inspection Report Sheet ────────────────────────────────────────

class _InspectionReportSheet extends StatelessWidget {
  final PreTripInspection inspection;
  const _InspectionReportSheet({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('Pre-Trip Inspection Report',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
              child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              _reportRow('Deposit Collected',
                  'PKR ${inspection.depositCollected.toStringAsFixed(0)}'),
              _reportRow('Fuel Level', inspection.fuelLevel),
              _reportRow('Odometer', '${inspection.odometerReading} km'),
              if (inspection.completedAt != null)
                _reportRow('Completed At',
                    DateFormat('MMM d, yyyy • h:mm a').format(inspection.completedAt!)),
              const SizedBox(height: 16),
              Text('Inspection Areas',
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...InspectionAreas.all.map((area) {
                final item = inspection.items[area];
                if (item == null) return const SizedBox.shrink();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: Icon(
                      item.hasDamage
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: item.hasDamage ? Colors.orange : Colors.green,
                    ),
                    title: Text(InspectionAreas.label(area),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(item.hasDamage
                        ? (item.notes.isNotEmpty ? item.notes : 'Damage noted')
                        : 'No damage'),
                    trailing: item.photoUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(item.photoUrls.first,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported)),
                          )
                        : null,
                  ),
                );
              }),
              _reportRow('Host Signed', inspection.hostSigned ? '✓ Yes' : '✗ No'),
              _reportRow(
                  'Renter Signed', inspection.renterSigned ? '✓ Yes' : '✗ No'),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _reportRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
      );
}
