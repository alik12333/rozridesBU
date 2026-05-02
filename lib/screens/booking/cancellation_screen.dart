import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/booking_service.dart';
import '../../models/booking_model.dart';

class CancellationScreen extends StatefulWidget {
  final String bookingId;
  final String cancelledBy; // 'renter' or 'host'

  const CancellationScreen({
    super.key,
    required this.bookingId,
    required this.cancelledBy,
  });

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  final BookingService _service = BookingService();
  BookingModel? _booking;
  bool _loading = true;
  bool _submitting = false;
  String? _selectedReason;
  final TextEditingController _customCtrl = TextEditingController();

  static const _renterReasons = [
    'Change of plans',
    'Found a better option',
    'Emergency',
    'Host was unresponsive',
    'Other',
  ];
  static const _hostReasons = [
    'Car unavailable',
    'Car needs maintenance',
    'Emergency',
    'Renter profile issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchBooking();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBooking() async {
    try {
      final snap = await _service.streamBooking(widget.bookingId).first;
      if (mounted) setState(() { _booking = snap; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canConfirm =>
      _selectedReason != null &&
      (_selectedReason != 'Other' || _customCtrl.text.trim().isNotEmpty);

  bool get _isLateCancellation {
    if (_booking == null) return false;
    if (widget.cancelledBy == 'renter' && _booking!.status == 'confirmed') {
      return _booking!.startDate.difference(DateTime.now()).inHours < 24;
    }
    return false;
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _booking == null) return;
    final reason =
        _selectedReason == 'Other' ? _customCtrl.text.trim() : _selectedReason!;

    setState(() => _submitting = true);
    final ok = await context.read<BookingProvider>().cancelBooking(
          bookingId: widget.bookingId,
          reason: reason,
          cancelledBy: widget.cancelledBy,
        );

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking cancelled.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  context.read<BookingProvider>().errorMessage ?? 'Error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final b = _booking;
    final reasons =
        widget.cancelledBy == 'renter' ? _renterReasons : _hostReasons;
    final fmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Cancel Booking',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car info card
            if (b != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12)
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: b.carPhoto.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(b.carPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.directions_car,
                                        color: Colors.grey)),
                          )
                        : const Icon(Icons.directions_car, color: Colors.grey),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.carName,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(b.startDate)} → ${fmt.format(b.endDate)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  )),
                ]),
              ),
            const SizedBox(height: 20),

            // Cash notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Since all payments are cash, there is no automatic refund. '
                      'If you have already exchanged any cash with the host, '
                      'contact them directly to arrange its return.',
                      style: TextStyle(color: Colors.blue.shade800, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reason selector
            Text('Why are you cancelling?',
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12)
                ],
              ),
              child: Column(
                children: reasons.map((r) {
                  final isLast = r == reasons.last;
                  return Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(r, style: const TextStyle(fontSize: 15)),
                        value: r,
                        groupValue: _selectedReason,
                        activeColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setState(() => _selectedReason = v),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        dense: true,
                      ),
                      if (!isLast)
                        Divider(height: 1, indent: 52, color: Colors.grey.shade100),
                    ],
                  );
                }).toList(),
              ),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                maxLength: 200,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Please describe your reason...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Warnings
            if (_isLateCancellation)
              _warningBox(
                '⚠️ Late Cancellation Warning',
                'Cancelling within 24 hours of your pickup may affect your renter reputation score.',
                Colors.orange,
              ),
            if (widget.cancelledBy == 'host' && b?.status == 'confirmed')
              _warningBox(
                '⚠️ Host Cancellation Notice',
                'Cancelling confirmed bookings negatively impacts your host score. '
                '3 cancellations may result in account review.',
                Colors.red,
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        color: Colors.white,
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _canConfirm && !_submitting ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Confirm Cancellation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _warningBox(String title, String body, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 13, height: 1.4)),
          ],
        ),
      );
}
