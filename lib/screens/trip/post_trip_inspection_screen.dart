import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../models/inspection_model.dart';
import '../../models/post_inspection_model.dart';
import 'cash_settlement_screen.dart';

class PostTripInspectionScreen extends StatefulWidget {
  final BookingModel booking;
  final PreTripInspection preInspection;
  const PostTripInspectionScreen(
      {super.key, required this.booking, required this.preInspection});
  @override
  State<PostTripInspectionScreen> createState() =>
      _PostTripInspectionScreenState();
}

class _PostTripInspectionScreenState extends State<PostTripInspectionScreen> {
  final _pageCtrl = PageController();
  final _picker = ImagePicker();
  final _odometerCtrl = TextEditingController();
  late PostTripInspection _inspection;
  bool _returnConfirmed = false;
  int _step = 0; // 0=confirm, 1-5=areas, 6=fuel/odo, 7=summary
  static const _areas = InspectionAreas.all;

  @override
  void initState() {
    super.initState();
    _inspection = PostTripInspection.blank(widget.booking.id);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 7) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _pickPhoto(String area) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ])),
    );
    if (src == null) return;
    final xf = await _picker.pickImage(source: src, imageQuality: 80);
    if (xf == null) return;
    final old = _inspection.items[area]!;
    setState(() => _inspection = _inspection.copyWith(
        items: {..._inspection.items, area: old.copyWith(photoUrls: [xf.path])}));
  }

  void _updateItem(String area, InspectionItem item) => setState(() =>
      _inspection = _inspection.copyWith(
          items: {..._inspection.items, area: item}));

  void _proceed() {
    final pre = widget.preInspection;
    final post = _inspection.copyWith(
      odometerReading: int.tryParse(_odometerCtrl.text) ?? 0,
      hostSigned: true,
      renterSigned: true,
      completedAt: DateTime.now(),
    );
    final result = compareInspections(pre, post);
    final finalPost = post.copyWith(
      newDamageFound: result.hasNewDamage,
      newDamageAreas: result.newDamageAreas,
      fuelLevelChanged: result.hasFuelIssue,
      kmDriven: result.kmDriven,
    );
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CashSettlementScreen(
                booking: widget.booking,
                comparison: result,
                postInspection: finalPost)));
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
        ),
        child: child,
      );

  Widget _header(String title, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF7C3AED), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold))),
      ]);

  Widget _nextBtn(bool enabled, {String label = 'NEXT'}) => SizedBox(
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
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );

  // ─── Step 0: Confirm Return ───────────────────────────────────────────────

  Widget _step0() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header('Confirm Car Returned', Icons.assignment_turned_in_outlined),
          const SizedBox(height: 8),
          Text('Confirm that ${widget.booking.renterName} has returned the car.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
          const SizedBox(height: 20),
          _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Return Date & Time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                  DateFormat('MMM d, yyyy • h:mm a')
                      .format(_inspection.returnConfirmedAt),
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ])),
          CheckboxListTile(
            value: _returnConfirmed,
            onChanged: (v) => setState(() => _returnConfirmed = v ?? false),
            activeColor: const Color(0xFF7C3AED),
            title: Text(
                'The car has been physically returned to me by ${widget.booking.renterName}.',
                style: const TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 20),
          _nextBtn(_returnConfirmed),
        ]),
      );

  // ─── Steps 1–5: Area comparisons ─────────────────────────────────────────

  Widget _areaStep(int idx) {
    final area = _areas[idx];
    final label = InspectionAreas.label(area);
    final preItem = widget.preInspection.items[area];
    final postItem = _inspection.items[area]!;
    final hasNewPhoto = postItem.photoUrls.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header('$label Comparison', Icons.compare_arrows),
        const SizedBox(height: 12),

        // AT PICKUP
        _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('AT PICKUP',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: preItem != null && preItem.photoUrls.isNotEmpty
                ? Image.network(preItem.photoUrls.first,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder())
                : _photoPlaceholder(),
          ),
          if (preItem?.hasDamage == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Pre-existing damage: ${preItem?.notes.isNotEmpty == true ? preItem!.notes : "noted at pickup"}',
                        style: TextStyle(
                            color: Colors.orange.shade800, fontSize: 12))),
              ]),
            ),
          ],
        ])),

        // NOW
        _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('NOW',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1))),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pickPhoto(area),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasNewPhoto
                  ? Stack(children: [
                      Image.file(File(postItem.photoUrls.first),
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover),
                      Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Retake',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)))),
                    ])
                  : Container(
                      width: double.infinity,
                      height: 150,
                      color: Colors.grey.shade100,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Tap to take photo',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ]),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Is there NEW damage since pickup?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _damageChip('No new damage', !postItem.hasDamage,
                () => _updateItem(area, postItem.copyWith(hasDamage: false))),
            const SizedBox(width: 10),
            _damageChip('Yes, new damage', postItem.hasDamage,
                () => _updateItem(area, postItem.copyWith(hasDamage: true))),
          ]),
          if (postItem.hasDamage) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => _updateItem(area, postItem.copyWith(notes: v)),
              decoration: InputDecoration(
                hintText: 'Describe the new damage (required)...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ],
        ])),

        _nextBtn(hasNewPhoto &&
            (!postItem.hasDamage || postItem.notes.trim().isNotEmpty)),
      ]),
    );
  }

  Widget _photoPlaceholder() => Container(
        width: double.infinity,
        height: 150,
        color: Colors.grey.shade200,
        child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
      );

  Widget _damageChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (label.startsWith('No') ? Colors.green.shade50 : Colors.red.shade50)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? (label.startsWith('No')
                        ? Colors.green.shade400
                        : Colors.red.shade400)
                    : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected
                      ? (label.startsWith('No')
                          ? Colors.green.shade700
                          : Colors.red.shade700)
                      : Colors.grey.shade600,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ),
      );

  // ─── Step 6: Fuel & Odometer ──────────────────────────────────────────────

  Widget _step6() {
    final pre = widget.preInspection;
    final fuelOrder = PreTripInspection.fuelLevels;
    final preIdx = fuelOrder.indexOf(pre.fuelLevel);
    final postIdx = fuelOrder.indexOf(_inspection.fuelLevel);
    final fuelLower = postIdx > preIdx;
    final odomOk = _odometerCtrl.text.trim().isNotEmpty;
    final postOdo = int.tryParse(_odometerCtrl.text) ?? 0;
    final kmDriven = (postOdo - pre.odometerReading).clamp(0, 999999);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header('Fuel & Odometer', Icons.local_gas_station_outlined),
        const SizedBox(height: 16),

        // Fuel
        _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AT PICKUP: Fuel was ${pre.fuelLevel}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 10),
          const Text('CURRENT FUEL LEVEL:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              children: fuelOrder.map((level) {
                final sel = _inspection.fuelLevel == level;
                return GestureDetector(
                  onTap: () => setState(
                      () => _inspection = _inspection.copyWith(fuelLevel: level)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF7C3AED) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFF7C3AED)
                              : Colors.grey.shade300),
                    ),
                    child: Text(level,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.grey.shade700,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList()),
          if (fuelLower) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text(
                        '⚠ Fuel level is lower than at pickup. This may result in a deduction.',
                        style: TextStyle(fontSize: 13))),
              ]),
            ),
          ],
        ])),

        // Odometer
        _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AT PICKUP: Odometer was ${pre.odometerReading} km',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 10),
          const Text('CURRENT ODOMETER:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _odometerCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Current odometer reading (km)',
              suffixText: 'km',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (odomOk) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Distance driven:',
                  style: TextStyle(color: Colors.grey)),
              Text('$kmDriven km',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF7C3AED))),
            ]),
          ],
        ])),

        _nextBtn(odomOk, label: 'REVIEW SUMMARY'),
      ]),
    );
  }

  // ─── Step 7: Summary & Sign-Off ───────────────────────────────────────────

  Widget _step7() {
    final pre = widget.preInspection;
    final postOdo = int.tryParse(_odometerCtrl.text) ?? 0;
    final tmpPost = _inspection.copyWith(odometerReading: postOdo);
    final result = compareInspections(pre, tmpPost);

    bool hostSigned = false;
    bool renterSigned = false;

    return StatefulBuilder(builder: (context, setLocal) {
      final canProceed = hostSigned && renterSigned;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Return Summary',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Review before proceeding to cash settlement.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),

          // Result banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: result.hasAnyIssue ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: result.hasAnyIssue
                      ? Colors.red.shade200
                      : Colors.green.shade300),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                result.hasAnyIssue
                    ? '⚠ The following was noted:'
                    : '✅ No new damage found! Great trip.',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: result.hasAnyIssue
                        ? Colors.red.shade700
                        : Colors.green.shade700),
              ),
              if (result.hasNewDamage) ...[
                const SizedBox(height: 8),
                ...result.newDamageAreas.map((a) => Text(
                    '• ${InspectionAreas.label(a)}: ${result.newDamageNotes[a] ?? "damage"}',
                    style: const TextStyle(fontSize: 13))),
              ],
              if (result.hasFuelIssue) ...[
                const SizedBox(height: 4),
                const Text('• Fuel level returned lower than at pickup',
                    style: TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Text('Distance driven: ${result.kmDriven} km',
                  style: const TextStyle(fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 14),

          // Host sign-off
          _signatureBox(
              title: 'Host confirms the above is accurate:',
              name: 'Host',
              signed: hostSigned,
              onSign: () => setLocal(() => hostSigned = true)),
          const SizedBox(height: 10),

          // Renter sign-off
          _signatureBox(
              title: 'Renter confirms the above is accurate:',
              name: widget.booking.renterName,
              signed: renterSigned,
              onSign: () => setLocal(() => renterSigned = true)),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canProceed ? _proceed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('PROCEED TO CASH SETTLEMENT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ]),
      );
    });
  }

  Widget _signatureBox(
          {required String title,
          required String name,
          required bool signed,
          required VoidCallback onSign}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: signed ? null : onSign,
            child: Container(
              width: double.infinity,
              height: 72,
              decoration: BoxDecoration(
                color: signed ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: signed ? Colors.green.shade400 : Colors.grey.shade300,
                    width: signed ? 2 : 1),
              ),
              child: signed
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                      const SizedBox(width: 8),
                      Text('$name — Signed ✓',
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold)),
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            color: Colors.grey.shade400, size: 26),
                        const SizedBox(height: 4),
                        Text('TAP TO SIGN',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ]),
            ),
          ),
        ]),
      );

  // ─── Progress bar ─────────────────────────────────────────────────────────

  Widget _progressBar() {
    const total = 8;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Step ${_step + 1} of $total',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text('${((_step + 1) / total * 100).toInt()}%',
              style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / total,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          _step < 7 ? 'Post-Trip Inspection' : 'Return Summary',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step == 0 ? () => Navigator.pop(context) : _back,
        ),
      ),
      body: Column(children: [
        if (_step < 7) _progressBar(),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _step0(),
              ..._areas.asMap().entries.map((e) => _areaStep(e.key)),
              _step6(),
              _step7(),
            ],
          ),
        ),
      ]),
    );
  }
}
