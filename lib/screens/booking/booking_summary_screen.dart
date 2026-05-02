import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/listing_model.dart';
import '../../models/pricing_breakdown_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import 'booking_confirmed_screen.dart';

class BookingSummaryScreen extends StatefulWidget {
  final ListingModel listing;
  final DateTime startDate;
  final DateTime endDate;
  final CashPricingBreakdown pricing;

  const BookingSummaryScreen({
    super.key,
    required this.listing,
    required this.startDate,
    required this.endDate,
    required this.pricing,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isLoading = false;
  final BookingService _bookingService = BookingService();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      DateFormat('EEE, MMM d yyyy').format(date);

  String _formatPKR(double amount) =>
      'PKR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  Future<void> _submitBooking() async {
    setState(() => _isLoading = true);
    try {
      final bookingId = await _bookingService.createBookingRequest(
        carId: widget.listing.id,
        hostId: widget.listing.ownerId,
        startDate: widget.startDate,
        endDate: widget.endDate,
        pricing: widget.pricing,
        messageToHost: _messageController.text.trim(),
        carName: widget.listing.carName,
        carPhoto: widget.listing.images.isNotEmpty ? widget.listing.images.first : '',
        carLocation:
            '${widget.listing.area ?? ''}, ${widget.listing.city ?? ''}'.trim().replaceAll(RegExp(r'^, |, $'), ''),
        renterName: context.read<AuthProvider>().currentUser?.fullName ?? 'Renter',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingConfirmedScreen(
              bookingId: bookingId,
              hostName: widget.listing.ownerName,
              carName: widget.listing.carName,
              depositAmount: widget.pricing.depositAtPickup,
              expiresAt: DateTime.now().add(const Duration(hours: 24)),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;

      if (msg == 'CNIC_NOT_VERIFIED') {
        _showCnicDialog();
      } else if (msg == 'DATES_UNAVAILABLE') {
        _showDatesUnavailableDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCnicDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Identity Verification Required'),
        content: const Text(
            'You must complete CNIC verification before booking a car. Please go to your profile to upload and verify your CNIC.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
              // Navigate to profile for CNIC verification
            },
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  void _showDatesUnavailableDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dates No Longer Available'),
        content: const Text(
            'These dates were just booked by someone else. Please go back and select different dates.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // pop back to car detail
            },
            child: const Text('Select Different Dates'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final bool isCnicVerified = user?.cnic?.verificationStatus == 'approved';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────── SECTION 1: Car Info Card ────────────────
            _sectionHeader('Car Details'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: widget.listing.images.isNotEmpty
                          ? Image.network(
                              widget.listing.images.first,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderImage(),
                            )
                          : _placeholderImage(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.listing.carName,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${widget.listing.area ?? ''}, ${widget.listing.city ?? ''}'
                                      .trim()
                                      .replaceAll(RegExp(r'^, |, $'), ''),
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Host: ${widget.listing.ownerName}',
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ─────────────────────────── SECTION 2: Trip Dates ───────────────────
            _sectionHeader('Trip Dates'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _dateRow('Pickup', _formatDate(widget.startDate)),
                    const Divider(height: 24),
                    _dateRow('Return', _formatDate(widget.endDate)),
                    const Divider(height: 24),
                    _dateRow('Duration', '${widget.pricing.totalDays} days'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ─────────────────────────── SECTION 3: Your Profile ─────────────────
            _sectionHeader('Your Profile'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isCnicVerified
                    ? Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage: user?.profilePhoto != null
                                ? NetworkImage(user!.profilePhoto!)
                                : null,
                            child: user?.profilePhoto == null
                                ? const Icon(Icons.person, size: 26)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              user?.fullName ?? 'Renter',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 14, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text('CNIC Verified',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                child: Text(
                                  'You must complete identity verification before booking. Tap here to verify.',
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 28),

            // ─────────────────────────── SECTION 4: Cash Payment Schedule ────────
            _sectionHeader('Cash Payment Schedule'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AT PICKUP
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AT PICKUP — ${_formatDate(widget.startDate)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green.shade800,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pay host (security deposit)',
                                style: TextStyle(fontSize: 15)),
                            Text(_formatPKR(widget.pricing.depositAtPickup),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Have this cash ready when you meet the host',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                  ),

                  Divider(color: Colors.green.shade200, height: 1),

                  // AT RETURN
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AT RETURN — ${_formatDate(widget.endDate)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green.shade800,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Car rental (${widget.pricing.totalDays} days)',
                                style: const TextStyle(fontSize: 15)),
                            Text(_formatPKR(widget.pricing.pricePerDay * widget.pricing.totalDays),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (widget.pricing.driverFeePerDay > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Driver fee (${widget.pricing.totalDays} days)',
                                  style: const TextStyle(fontSize: 15)),
                              Text(_formatPKR(widget.pricing.driverFeePerDay * widget.pricing.totalDays),
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pay host total at return',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                            Text(_formatPKR(widget.pricing.payAtReturn),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Receive back (deposit refund)',
                                style: TextStyle(fontSize: 15)),
                            Text(_formatPKR(widget.pricing.receiveAtReturn),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Deposit returned only if no damage found',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                  ),

                  Divider(color: Colors.green.shade200, height: 1),

                  // Total
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('YOUR TOTAL TRIP COST',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(_formatPKR(widget.pricing.netCostToRenter),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('This is the rental only. Deposit is fully refundable.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─────────────────────────── SECTION 5: Message to Host ──────────────
            _sectionHeader('Message to Host (Optional)'),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (_, val, __) {
                return TextField(
                  controller: _messageController,
                  maxLength: 300,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Write a message to the host...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    counterText: '${val.text.length}/300',
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ─────────────────────────── SECTION 6: Cancellation Policy ──────────
            _sectionHeader('Cancellation Policy'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'Free cancellation before the pickup date. After pickup, the trip cannot be cancelled through the app.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),

            const SizedBox(height: 20),

            // ─────────────────────────── SECTION 7: Terms ────────────────────────
            Text(
              'By submitting this request, you confirm all payments will be made in cash directly to the host. RozRides does not process any payments.',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),

      // ─────────────────────────── Bottom Fixed Button ─────────────────────────
      bottomNavigationBar: Container(
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
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: isCnicVerified && !_isLoading ? _submitBooking : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'SEND BOOKING REQUEST',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      );

  Widget _dateRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _placeholderImage() => Container(
        width: 88,
        height: 88,
        color: Colors.grey.shade200,
        child: const Icon(Icons.directions_car, color: Colors.grey, size: 32),
      );
}
