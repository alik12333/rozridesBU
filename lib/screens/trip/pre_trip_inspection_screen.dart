import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../models/inspection_model.dart';
import '../../services/booking_service.dart';

class PreTripInspectionScreen extends StatefulWidget {
  final BookingModel booking;
  const PreTripInspectionScreen({super.key, required this.booking});

  @override
  State<PreTripInspectionScreen> createState() => _PreTripInspectionScreenState();
}

class _PreTripInspectionScreenState extends State<PreTripInspectionScreen> {
  final PageController _pageCtrl = PageController();
  final BookingService _service = BookingService();
  final ImagePicker _picker = ImagePicker();

  late PreTripInspection _inspection;

  // Step 1 state
  final TextEditingController _depositCtrl = TextEditingController();
  bool _depositChecked = false;

  // Step 7 state
  final TextEditingController _odometerCtrl = TextEditingController();

  bool _submitting = false;
  int _currentStep = 0; // 0-7 (0-6 = steps, 7 = summary)

  static const _areas = InspectionAreas.all; // front,rear,leftSide,rightSide,interior

  @override
  void initState() {
    super.initState();
    _inspection = PreTripInspection.blank(widget.booking.id);
    _depositCtrl.text = widget.booking.securityDeposit.toStringAsFixed(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEarlyEntry());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _depositCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  void _checkEarlyEntry() {
    final now = DateTime.now();
    final pickup = widget.booking.startDate;
    if (now.isBefore(pickup.subtract(const Duration(hours: 2)))) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('A bit early?'),
          content: Text(
            'The pickup is scheduled for ${DateFormat('MMM d \'at\' h:mm a').format(pickup)}. '
            'Are you sure you want to start the handover early?',
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('Continue Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _next() {
    if (_currentStep < 7) {
      setState(() => _currentStep++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _pickPhoto(String area) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final xFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xFile == null) return;
    setState(() {
      final old = _inspection.items[area]!;
      _inspection = _inspection.copyWith(
        items: {..._inspection.items, area: old.copyWith(photoUrls: [xFile.path])},
      );
    });
  }

  void _updateItem(String area, InspectionItem updated) {
    setState(() {
      _inspection = _inspection.copyWith(
        items: {..._inspection.items, area: updated},
      );
    });
  }

  Future<void> _completeHandover() async {
    setState(() => _submitting = true);
    try {
      final deposit = double.tryParse(_depositCtrl.text) ?? widget.booking.securityDeposit;
      final odometer = int.tryParse(_odometerCtrl.text) ?? 0;
      final finalInspection = _inspection.copyWith(
        depositCollected: deposit,
        odometerReading: odometer,
        hostSigned: true,
        renterSigned: true,
      );
      await _service.completePreHandover(widget.booking.id, finalInspection);
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Handover complete! Waiting for the renter to start the trip.'),
            backgroundColor: Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          _currentStep < 7 ? 'Pre-Trip Inspection' : 'Handover Summary',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _back,
        ),
      ),
      body: Column(
        children: [
          if (_currentStep < 7) _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                ..._areas.asMap().entries.map((e) => _buildPhotoStep(e.key + 2, e.value)),
                _buildStep7(),
                _buildSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = 7;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Step ${_currentStep + 1} of $total',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text('${((_currentStep + 1) / total * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / total,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Deposit ───────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Security Deposit', Icons.payments_outlined),
        const SizedBox(height: 8),
        Text('Collect the security deposit from ${widget.booking.renterName} before proceeding.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        const SizedBox(height: 24),
        // Amount display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('Expected Amount', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('PKR ${widget.booking.securityDeposit.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _depositCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Amount Received (PKR)',
            prefixIcon: const Icon(Icons.money),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'The driver should be present. Keys are not handed over until all steps are complete.',
              style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _depositChecked,
          onChanged: (v) => setState(() => _depositChecked = v ?? false),
          activeColor: const Color(0xFF7C3AED),
          title: Text('I have received PKR ${_depositCtrl.text.isEmpty ? widget.booking.securityDeposit.toStringAsFixed(0) : _depositCtrl.text} cash from the renter.',
              style: const TextStyle(fontSize: 14)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 24),
        _nextButton(_depositChecked && _depositCtrl.text.isNotEmpty),
      ]),
    );
  }

  // ─── Photo Steps (2–6) ────────────────────────────────────────────────────

  Widget _buildPhotoStep(int stepNumber, String area) {
    final item = _inspection.items[area]!;
    final hasPhoto = item.photoUrls.isNotEmpty;
    final label = InspectionAreas.label(area);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(label, Icons.camera_alt_outlined),
        const SizedBox(height: 8),
        Text('Take a clear photo of the ${label.toLowerCase()}.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        const SizedBox(height: 20),

        // Photo area
        GestureDetector(
          onTap: () => _pickPhoto(area),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasPhoto ? const Color(0xFF7C3AED) : Colors.grey.shade300, width: hasPhoto ? 2 : 1),
            ),
            child: hasPhoto
                ? Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(15),
                        child: Image.file(File(item.photoUrls.first), fit: BoxFit.cover)),
                    Positioned(top: 8, right: 8, child: GestureDetector(
                      onTap: () => _pickPhoto(area),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    )),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Tap to take photo', style: TextStyle(color: Colors.grey.shade500)),
                  ]),
          ),
        ),
        const SizedBox(height: 20),

        // Damage toggle
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Is there any existing damage?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _damageChip('No Damage', !item.hasDamage, () => _updateItem(area, item.copyWith(hasDamage: false))),
            const SizedBox(width: 10),
            _damageChip('Yes, damage present', item.hasDamage, () => _updateItem(area, item.copyWith(hasDamage: true))),
          ]),
          if (item.hasDamage) ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => _updateItem(area, item.copyWith(notes: v)),
              decoration: InputDecoration(
                hintText: 'Describe the damage...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
                filled: true, fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ],
        ])),
        const SizedBox(height: 24),
        _nextButton(hasPhoto),
      ]),
    );
  }

  // ─── Step 7: Fuel & Odometer ───────────────────────────────────────────────

  Widget _buildStep7() {
    final fuelSelected = _inspection.fuelLevel.isNotEmpty;
    final odometerEntered = _odometerCtrl.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Fuel & Odometer', Icons.local_gas_station_outlined),
        const SizedBox(height: 24),

        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fuel Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: PreTripInspection.fuelLevels.map((level) {
            final selected = _inspection.fuelLevel == level;
            return GestureDetector(
              onTap: () => setState(() => _inspection = _inspection.copyWith(fuelLevel: level)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF7C3AED) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? const Color(0xFF7C3AED) : Colors.grey.shade300),
                ),
                child: Text(level, style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                )),
              ),
            );
          }).toList()),
        ])),
        const SizedBox(height: 16),

        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Odometer Reading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          TextField(
            controller: _odometerCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Current odometer reading (km)',
              suffixText: 'km',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey.shade50,
            ),
          ),
        ])),
        const SizedBox(height: 24),
        _nextButton(fuelSelected && odometerEntered, label: 'REVIEW SUMMARY'),
      ]),
    );
  }

  // ─── Summary / Sign-Off ────────────────────────────────────────────────────

  Widget _buildSummary() {
    bool hostSigned = _inspection.hostSigned;
    bool renterSigned = _inspection.renterSigned;
    final deposit = double.tryParse(_depositCtrl.text) ?? widget.booking.securityDeposit;
    final photos = _areas.where((a) => _inspection.items[a]!.photoUrls.isNotEmpty).length;
    final damageNotes = _areas
        .where((a) => _inspection.items[a]!.hasDamage && _inspection.items[a]!.notes.isNotEmpty)
        .map((a) => '${InspectionAreas.label(a)}: ${_inspection.items[a]!.notes}')
        .join(', ');

    return StatefulBuilder(builder: (context, setLocal) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Handover Summary', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Please review all details before signing.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          // Summary card
          _card(child: Column(children: [
            _summaryRow('Deposit collected', 'PKR ${deposit.toStringAsFixed(0)}', true),
            _summaryRow('Photos taken', '$photos / 5', photos == 5),
            _summaryRow('Damage notes', damageNotes.isEmpty ? 'None noted' : damageNotes, true),
            _summaryRow('Fuel level', _inspection.fuelLevel, true),
            _summaryRow('Odometer', '${_odometerCtrl.text} km', true),
          ])),
          const SizedBox(height: 20),

          // Host sign-off
          _signatureBox(
            title: 'Host confirms the above is accurate:',
            name: 'Host',
            signed: hostSigned,
            onSign: () => setLocal(() {
              hostSigned = true;
              _inspection = _inspection.copyWith(hostSigned: true);
            }),
          ),
          const SizedBox(height: 12),

          // Renter sign-off
          _signatureBox(
            title: 'Renter confirms the above is accurate:',
            name: widget.booking.renterName,
            signed: renterSigned,
            onSign: () => setLocal(() {
              renterSigned = true;
              _inspection = _inspection.copyWith(renterSigned: true);
            }),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (hostSigned && renterSigned && !_submitting) ? _completeHandover : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('COMPLETE HANDOVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),
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
                  'After completing, the renter will see a "Start Trip" button on their device.',
                  style: TextStyle(color: Colors.purple.shade800, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      );
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _stepHeader(String title, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: const Color(0xFF7C3AED), size: 22),
    ),
    const SizedBox(width: 12),
    Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
  ]);

  Widget _nextButton(bool enabled, {String label = 'NEXT'}) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: enabled ? _next : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: child,
  );

  Widget _damageChip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? (label.startsWith('No') ? Colors.green.shade50 : Colors.red.shade50) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? (label.startsWith('No') ? Colors.green.shade400 : Colors.red.shade400) : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? (label.startsWith('No') ? Colors.green.shade700 : Colors.red.shade700) : Colors.grey.shade600,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      )),
    ),
  );

  Widget _summaryRow(String label, String value, bool ok) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 18, color: ok ? Colors.green.shade600 : Colors.orange),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  Widget _signatureBox({required String title, required String name, required bool signed, required VoidCallback onSign}) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: signed ? null : onSign,
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: signed ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: signed ? Colors.green.shade400 : Colors.grey.shade300,
              style: signed ? BorderStyle.solid : BorderStyle.solid,
              width: signed ? 2 : 1,
            ),
          ),
          child: signed
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 10),
                  Text('$name — Signed ✓',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.touch_app_outlined, color: Colors.grey.shade400, size: 28),
                  const SizedBox(height: 6),
                  Text('TAP TO SIGN', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
        ),
      ),
    ]),
  );
}
