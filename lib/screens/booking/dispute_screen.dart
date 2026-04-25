import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';

class DisputeScreen extends StatefulWidget {
  final BookingModel booking;
  final double hostClaimedDeduction;

  const DisputeScreen({
    super.key,
    required this.booking,
    required this.hostClaimedDeduction,
  });

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  final BookingService _service = BookingService();
  bool _submitting = false;

  String _pkr(double v) =>
      'PKR ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _service.raiseDispute(
        booking: widget.booking,
        description: _descriptionCtrl.text.trim(),
        renterBelievesAmount: double.tryParse(_amountCtrl.text) ?? 0,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            '✅ Your dispute has been submitted. RozRides will review it within 24 hours and contact you via the app.'),
        backgroundColor: Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 6),
      ));
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

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Raise a Dispute',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF7C3AED), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                       'RozRides will review the pre-trip and post-trip inspection photos, your conversation history, and both parties\' accounts to make a fair decision.',
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.5),
                    )),
                  ]),
            ),
            const SizedBox(height: 20),

            // Claimed amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Host is claiming:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_pkr(widget.hostClaimedDeduction),
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700)),
                const SizedBox(height: 2),
                Text('as a deduction from your security deposit.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),

            // Description
            Text('What happened from your perspective:',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 6,
              maxLength: 1000,
              validator: (v) {
                if (v == null || v.trim().length < 50) {
                  return 'Please provide at least 50 characters.';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText:
                    'Describe the disagreement in detail. Mention any relevant observations, prior condition of the car, or context that supports your position...',
                hintMaxLines: 4,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),

            // Renter's believed amount
            Text('You believe the correct deduction is:',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final amt = double.tryParse(v ?? '');
                if (amt == null || amt < 0) return 'Enter a valid amount (0 = no deduction).';
                if (amt > widget.booking.securityDeposit) {
                  return 'Cannot exceed deposit of ${_pkr(widget.booking.securityDeposit)}.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Correct deduction amount (PKR)',
                hintText: '0 = no deduction',
                prefixIcon: const Icon(Icons.attach_money),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
                'Enter 0 if you believe no deduction should be made from your deposit of ${_pkr(widget.booking.securityDeposit)}.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('SUBMIT DISPUTE',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
