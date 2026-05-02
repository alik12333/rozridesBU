import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/booking_model.dart';
import '../../models/inspection_model.dart';
import '../../models/post_inspection_model.dart';
import '../../services/booking_service.dart';
import 'trip_flagged_screen.dart';

class CashSettlementScreen extends StatefulWidget {
  final BookingModel booking;
  final ComparisonResult comparison;
  final PostTripInspection postInspection;
  /// True when opened by the host to propose a settlement.
  /// False when opened by the renter to review and confirm.
  final bool hostMode;

  const CashSettlementScreen({
    super.key,
    required this.booking,
    required this.comparison,
    required this.postInspection,
    this.hostMode = false,
  });

  @override
  State<CashSettlementScreen> createState() => _CashSettlementScreenState();
}

class _CashSettlementScreenState extends State<CashSettlementScreen> {
  final BookingService _service = BookingService();
  final TextEditingController _deductionCtrl = TextEditingController(text: '0');
  final TextEditingController _flagReasonCtrl = TextEditingController();

  bool _rentConfirmed = false;
  bool _depositConfirmed = false;
  bool _renterAgreesToDeduction = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _deductionCtrl.text = widget.comparison.hasNewDamage ? '5000' : '0';
  }

  @override
  void dispose() {
    _deductionCtrl.dispose();
    _flagReasonCtrl.dispose();
    super.dispose();
  }

  double get _deduction =>
      double.tryParse(_deductionCtrl.text) ?? 0;
  double get _depositRefund =>
      (widget.booking.securityDeposit - _deduction).clamp(0, widget.booking.securityDeposit);

  String _pkr(double v) => 'PKR ${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> _closeTrip() async {
    setState(() => _submitting = true);
    try {
      final settlement = CashSettlement(
        rentPaid: widget.booking.totalRent,
        depositRefunded: _depositRefund,
        damageDeduction: _deduction,
      );

      if (widget.hostMode) {
        // Host is proposing: upload inspection and store settlement, wait for renter
        await _service.proposeSettlement(
          bookingId: widget.booking.id,
          carId: widget.booking.carId,
          postInspection: widget.postInspection,
          settlement: settlement,
        );
        if (mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Return submitted! Waiting for renter to confirm.'),
            backgroundColor: Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ));
        }
      } else {
        // Renter is confirming: actually complete the trip
        await _service.completeTrip(
          bookingId: widget.booking.id,
          carId: widget.booking.carId,
          postInspection: widget.postInspection,
          settlement: settlement,
        );
        if (mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Trip completed! Thanks for using RozRides.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _flagTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to report this trip?\n\n'
                'Please explain the damage or issue for the admin:'),
            const SizedBox(height: 12),
            TextField(
              controller: _flagReasonCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g. Scratches on front bumper not agreed by renter...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_flagReasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason.')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Report'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await _service.flagTrip(
        bookingId: widget.booking.id,
        carId: widget.booking.carId,
        hostId: widget.booking.hostId,
        renterId: widget.booking.renterId,
        hostClaimedAmount: _deduction,
        description: _flagReasonCtrl.text.trim(),
        postInspection: widget.postInspection,
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const TripFlaggedScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
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

  Widget _stepCard({
    required int step,
    required String label,
    required String amount,
    required String subtitle,
    required bool checked,
    required VoidCallback onChanged,
  }) {
    return _card(
      color: checked ? Colors.green.shade50 : Colors.white,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Step indicator
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? Colors.green.shade600 : const Color(0xFF7C3AED),
          ),
          child: Center(
            child: checked
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(amount,
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7C3AED))),
            const SizedBox(height: 2),
            Text(subtitle,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onChanged,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: checked ? Colors.green.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: checked
                          ? Colors.green.shade400
                          : Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    checked
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: checked ? Colors.green.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    checked ? 'Confirmed ✓' : 'Tap to confirm',
                    style: TextStyle(
                        color: checked
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Scenario A — No new damage ────────────────────────────────────────────

  Widget _scenarioA() {
    final b = widget.booking;
    final canClose = _rentConfirmed && _depositConfirmed;

    return Column(children: [
      _card(
        color: Colors.green.shade50,
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 12),
          Expanded(
              child: Text('No new damage found! Great trip.',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700))),
        ]),
      ),
      _stepCard(
        step: 1,
        label: 'Renter pays car rental',
        amount: _pkr(b.totalRent),
        subtitle: '${b.renterName} pays host cash',
        checked: _rentConfirmed,
        onChanged: () => setState(() => _rentConfirmed = !_rentConfirmed),
      ),
      _stepCard(
        step: 2,
        label: 'Host returns security deposit',
        amount: _pkr(b.securityDeposit),
        subtitle: 'Host returns to ${b.renterName}',
        checked: _depositConfirmed,
        onChanged: () =>
            setState(() => _depositConfirmed = !_depositConfirmed),
      ),
      const SizedBox(height: 8),
      _closeTripButton(canClose),
    ]);
  }

  // ── Scenario B — Damage found ─────────────────────────────────────────────

  Widget _scenarioB() {
    final b = widget.booking;
    final comp = widget.comparison;
    final canClose = _renterAgreesToDeduction && _rentConfirmed && _depositConfirmed;

    return Column(children: [
      // Damage summary
      _card(
        color: Colors.red.shade50,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 24),
            const SizedBox(width: 10),
            Text('Damage Found',
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700)),
          ]),
          const SizedBox(height: 10),
          ...comp.newDamageAreas.map((area) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  Expanded(
                      child: Text(
                          '${InspectionAreas.label(area)}: ${comp.newDamageNotes[area] ?? "Damage noted"}',
                          style: const TextStyle(fontSize: 13, height: 1.4))),
                ]),
              )),
          if (comp.hasFuelIssue) ...[
            const SizedBox(height: 4),
            const Row(children: [
              Text('• ',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
              Text('Fuel level returned lower than at pickup',
                  style: TextStyle(fontSize: 13)),
            ]),
          ],
        ]),
      ),

      // Deduction input (host decides)
      if (!_renterAgreesToDeduction)
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Agree on a deduction amount',
                style:
                    GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Security deposit held: ${_pkr(b.securityDeposit)}',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: _deductionCtrl,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Icon(Icons.money_off),
                counterText: '',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Renter receives back:',
                      style: TextStyle(color: Colors.grey.shade600)),
                  Text(_pkr(_depositRefund),
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade700)),
                ]),
            const SizedBox(height: 16),
            // Renter agrees button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.handshake_outlined),
                label: Text(
                    'RENTER AGREES TO ${_pkr(_deduction)} DEDUCTION'),
                onPressed: _deduction >= 0 && _deduction <= b.securityDeposit
                    ? () => setState(() => _renterAgreesToDeduction = true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 32),
            Text("Don't agree with this claim?",
                style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Report to RozRides stub
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: const Text('REPORT THIS TRIP TO ROZRIDES'),
                onPressed: _submitting ? null : _flagTrip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade800,
                  side: BorderSide(color: Colors.amber.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tapping report sends this trip for admin review. RozRides will contact both parties within 24 hours.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  ),
                ),
              ],
            ),
          ]),
        ),

      // After renter agrees — show cash confirmation steps
      if (_renterAgreesToDeduction) ...[
        _card(
          color: Colors.green.shade50,
          child: Row(children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Renter agreed to ${_pkr(_deduction)} deduction. Proceed to cash exchange.',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
          ]),
        ),
        _stepCard(
          step: 1,
          label: 'Renter pays car rental',
          amount: _pkr(b.totalRent),
          subtitle: '${b.renterName} pays host cash',
          checked: _rentConfirmed,
          onChanged: () => setState(() => _rentConfirmed = !_rentConfirmed),
        ),
        _stepCard(
          step: 2,
          label: 'Host returns deposit (after deduction)',
          amount: _pkr(_depositRefund),
          subtitle:
              '${_pkr(b.securityDeposit)} − ${_pkr(_deduction)} deduction',
          checked: _depositConfirmed,
          onChanged: () =>
              setState(() => _depositConfirmed = !_depositConfirmed),
        ),
        _closeTripButton(canClose),
      ],
    ]);
  }

  Widget _closeTripButton(bool enabled) {
    // HOST MODE: show "Send to Renter" or waiting-for-renter indicator
    if (widget.hostMode) {
      return Column(children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: (enabled && !_submitting) ? _closeTrip : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('SEND TO RENTER FOR CONFIRMATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.purple.shade600, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'The renter will review this settlement on their device and confirm to end the trip.',
                style: TextStyle(color: Colors.purple.shade800, fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),
      ]);
    }

    // RENTER MODE: confirm and end trip
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (enabled && !_submitting) ? _closeTrip : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _submitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('CONFIRM & END TRIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasIssue = widget.comparison.hasAnyIssue;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          hasIssue ? '⚠ Damage Found — Settle Cash' : '✅ All Clear — Settle Cash',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: hasIssue ? _scenarioB() : _scenarioA(),
      ),
    );
  }
}
