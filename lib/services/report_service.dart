import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/booking_model.dart';
import '../models/damage_claim_model.dart';
import '../models/inspection_model.dart';
import '../models/listing_model.dart';
import '../models/post_inspection_model.dart';
import '../models/user_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Uint8List> generateTripReport(String bookingId) async {
    // ── 1. Fetch all data in parallel ───────────────────────────────────────
    final results = await Future.wait([
      _firestore.collection('bookings').doc(bookingId).get(),
      _firestore.collection('bookings').doc(bookingId).collection('inspections').doc('pre_trip').get(),
      _firestore.collection('bookings').doc(bookingId).collection('inspections').doc('post_trip').get(),
      _firestore.collection('damageClaims').where('bookingId', isEqualTo: bookingId).get(),
    ]);

    final bookingSnap = results[0] as DocumentSnapshot;
    final preSnap = results[1] as DocumentSnapshot;
    final postSnap = results[2] as DocumentSnapshot;
    final claimsSnap = results[3] as QuerySnapshot;

    if (!bookingSnap.exists) throw Exception('Booking not found');
    final booking = BookingModel.fromMap(bookingSnap.data() as Map<String, dynamic>, bookingSnap.id);

    final pre = preSnap.exists ? PreTripInspection.fromMap(preSnap.data() as Map<String, dynamic>) : null;
    final post = postSnap.exists ? PostTripInspection.fromMap(postSnap.data() as Map<String, dynamic>) : null;
    final claim = claimsSnap.docs.isNotEmpty ? DamageClaim.fromMap(claimsSnap.docs.first.data() as Map<String, dynamic>, claimsSnap.docs.first.id) : null;

    // Fetch related docs
    final relatedResults = await Future.wait([
      _firestore.collection('users').doc(booking.hostId).get(),
      _firestore.collection('users').doc(booking.renterId).get(),
      _firestore.collection('listings').doc(booking.carId).get(),
    ]);

    final hostUser = UserModel.fromMap(relatedResults[0].data() as Map<String, dynamic>, booking.hostId);
    final renterUser = UserModel.fromMap(relatedResults[1].data() as Map<String, dynamic>, booking.renterId);
    final car = ListingModel.fromMap(relatedResults[2].data() as Map<String, dynamic>, booking.carId);

    // ── 2. Download inspection photos ───────────────────────────────────────
    final Map<String, Uint8List> photoData = {};

    List<Future<void>> downloadTasks = [];

    void addDownloadTask(String prefix, Map<String, InspectionItem>? items) {
      if (items == null) return;
      for (var entry in items.entries) {
        final area = entry.key;
        final item = entry.value;
        if (item.photoUrls.isNotEmpty) {
          final url = item.photoUrls.first; // We embed the first photo of each area
          downloadTasks.add(() async {
            try {
              final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
              if (response.statusCode == 200) {
                photoData['${prefix}_$area'] = response.bodyBytes;
              }
            } catch (e) {
              debugPrint('Error downloading photo for $area: $e');
            }
          }());
        }
      }
    }

    addDownloadTask('pre', pre?.items);
    addDownloadTask('post', post?.items);

    await Future.wait(downloadTasks);

    // ── 3. Build PDF ────────────────────────────────────────────────────────
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    Uint8List? logoBytes;
    try {
      logoBytes = (await rootBundle.load('logocir.png')).buffer.asUint8List();
    } catch (e) {
      debugPrint('Could not load logo: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(bookingId, logoBytes),
            pw.SizedBox(height: 20),

            // Section 1: Trip Summary
            _buildSectionTitle('1. TRIP SUMMARY'),
            _buildSummaryTable(booking, car, hostUser, renterUser, dateFormat),
            pw.SizedBox(height: 20),

            // Section 2: Pre-Trip Inspection
            if (pre != null) ...[
              _buildSectionTitle('2. PRE-TRIP INSPECTION'),
              _buildPreTripInfo(pre, dateFormat),
              _buildInspectionGrid(pre.items, photoData, 'pre'),
              pw.SizedBox(height: 20),
            ],

            // Section 3: Post-Trip Inspection
            if (post != null) ...[
              _buildSectionTitle('3. POST-TRIP INSPECTION'),
              _buildPostTripInfo(post, pre, dateFormat),
              _buildInspectionGrid(post.items, photoData, 'post', preItems: pre?.items),
              pw.SizedBox(height: 20),
            ],

            // Section 4: Dispute Record
            if (claim != null) ...[
              _buildSectionTitle('4. DISPUTE RECORD'),
              _buildDisputeInfo(claim, booking, dateFormat),
              pw.SizedBox(height: 20),
            ],

            // Section 5: Platform Certification
            _buildCertification(bookingId),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String bookingId, Uint8List? logoBytes) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            if (logoBytes != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(pw.MemoryImage(logoBytes), width: 40, height: 40),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoBytes == null)
                  pw.Text('RozRides',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#7C3AED'))),
                pw.Text('Trip Inspection Report',
                    style: pw.TextStyle(fontSize: logoBytes != null ? 18 : 14, fontWeight: logoBytes != null ? pw.FontWeight.bold : pw.FontWeight.normal, color: logoBytes != null ? PdfColor.fromHex('#7C3AED') : PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('BOOKING ID',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(bookingId.toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildSummaryTable(BookingModel booking, ListingModel car,
      UserModel host, UserModel renter, DateFormat df) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          _buildRow('Car', '${car.year} ${car.brand} ${car.model} (${car.carNumber ?? 'N/A'})'),
          _buildRow('Host', host.fullName),
          _buildRow('Renter', '${renter.fullName} (CNIC: ${renter.cnic?.number ?? 'N/A'})'),
          _buildRow('Pickup Date', df.format(booking.startDate)),
          _buildRow('Return Date', df.format(booking.endDate)),
          _buildRow('Duration', '${booking.totalDays} Days'),
        ],
      ),
    );
  }

  pw.Widget _buildPreTripInfo(PreTripInspection pre, DateFormat df) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          _buildRow('Security Deposit', 'PKR ${pre.depositCollected.toStringAsFixed(0)}'),
          _buildRow('Fuel Level', pre.fuelLevel),
          _buildRow('Odometer', '${pre.odometerReading} km'),
          _buildRow('Handover Time', pre.completedAt != null ? df.format(pre.completedAt!) : 'N/A'),
        ],
      ),
    );
  }

  pw.Widget _buildPostTripInfo(PostTripInspection post, PreTripInspection? pre, DateFormat df) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          _buildRow('Fuel Level', post.fuelLevel),
          _buildRow('Odometer', '${post.odometerReading} km'),
          _buildRow('Distance Driven', '${post.kmDriven} km'),
          _buildRow('Return Time', post.completedAt != null ? df.format(post.completedAt!) : 'N/A'),
        ],
      ),
    );
  }

  pw.Widget _buildInspectionGrid(Map<String, InspectionItem> items,
      Map<String, Uint8List> photos, String prefix,
      {Map<String, InspectionItem>? preItems}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Area', isHeader: true),
            _buildTableCell('Damage', isHeader: true),
            _buildTableCell('Notes', isHeader: true),
            _buildTableCell('Photo', isHeader: true),
          ],
        ),
        ...items.entries.map((e) {
          final area = e.key;
          final item = e.value;
          final preItem = preItems?[area];
          
          bool isNewDamage = false;
          if (prefix == 'post' && preItem != null) {
            isNewDamage = !preItem.hasDamage && item.hasDamage;
          }

          final photoBytes = photos['${prefix}_$area'];

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            decoration: isNewDamage ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFEBEE)) : null,
            children: [
              _buildTableCell(InspectionAreas.label(area)),
              _buildTableCell(item.hasDamage ? (isNewDamage ? 'NEW DAMAGE' : 'YES') : 'NO', 
                color: isNewDamage ? PdfColors.red : (item.hasDamage ? PdfColors.orange : PdfColors.black)),
              _buildTableCell(item.notes.isEmpty ? '-' : item.notes),
              pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: photoBytes != null 
                  ? pw.Image(pw.MemoryImage(photoBytes), height: 40, fit: pw.BoxFit.contain)
                  : pw.Center(child: pw.Text('No photo', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildDisputeInfo(DamageClaim claim, BookingModel booking, DateFormat df) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          _buildRow('Dispute Status', claim.statusLabel),
          _buildRow('Admin Decision', claim.adminDecision?.toUpperCase() ?? 'PENDING'),
          _buildRow('Final Deduction', 'PKR ${claim.finalDeductionAmount?.toStringAsFixed(0) ?? '0'}'),
          if (claim.extraChargeAmount > 0)
            _buildRow('Extra Charge', 'PKR ${claim.extraChargeAmount.toStringAsFixed(0)}', color: PdfColors.red),
          _buildRow('Admin Notes', claim.adminNotes ?? 'No notes provided.'),
          _buildRow('Resolved At', claim.resolvedAt != null ? df.format(claim.resolvedAt!) : 'N/A'),
        ],
      ),
    );
  }

  pw.Widget _buildCertification(String bookingId) {
    final reportId = 'RPT-${bookingId.substring(0, 8).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text('PLATFORM CERTIFICATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Report ID: $reportId', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Generated at: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
        pw.Text(
          'This report reflects data recorded in real-time by both parties on the RozRides platform. '
          'All photos and signatures were captured and stored securely by RozRides.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text('© 2026 RozRides - Peer-to-Peer Car Rentals', 
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C3AED'))),
        ),
      ],
    );
  }

  pw.Widget _buildRow(String label, String value, {PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, color: color))),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.Alignment alignment = pw.Alignment.centerLeft, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: alignment == pw.Alignment.centerLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }
}
