import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';

class SubmitReviewScreen extends StatefulWidget {
  final BookingModel booking;
  final String reviewType; // renter_to_host | host_to_renter

  const SubmitReviewScreen({
    super.key,
    required this.booking,
    required this.reviewType,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final _commentCtrl = TextEditingController();
  final BookingService _service = BookingService();
  double _rating = 0;
  bool _submitting = false;

  bool get _isRenterReviewing => widget.reviewType == 'renter_to_host';

  String get _revieweeId =>
      _isRenterReviewing ? widget.booking.hostId : widget.booking.renterId;

  String get _revieweeName =>
      _isRenterReviewing ? 'Host' : widget.booking.renterName;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a star rating.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_commentCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write at least 10 characters.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = context.read<AuthProvider>().currentUser;
      await _service.submitReview(
        bookingId: widget.booking.id,
        revieweeId: _revieweeId,
        carId: _isRenterReviewing ? widget.booking.carId : null,
        type: widget.reviewType,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
        reviewerName: user?.fullName ?? 'User',
        reviewerPhoto: user?.profilePhoto,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Review submitted! It will be posted after the other party also reviews, or after 7 days.'),
        backgroundColor: Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final msg = e.toString().contains('ALREADY_REVIEWED')
            ? 'You have already submitted a review for this trip.'
            : e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          _isRenterReviewing ? 'Rate your trip' : 'Rate this renter',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20).copyWith(bottom: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('Submit Review', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car / Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _revieweeName.isNotEmpty ? _revieweeName[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.booking.carName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Trip with $_revieweeName', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Star Rating Section
            Center(
              child: Column(
                children: [
                  Text(
                    _rating == 0 ? 'How was your experience?' : _getRatingLabel(_rating),
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: _getRatingColor(_rating)),
                  ),
                  const SizedBox(height: 16),
                  _StarSelector(
                    rating: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Comment Section
            Text('Write a detailed review', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentCtrl,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Describe your experience...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                counterStyle: TextStyle(color: Colors.grey.shade500),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Warning / Disclaimer Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blind Review System', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                        const SizedBox(height: 4),
                        Text(
                          'To ensure honesty, your review remains hidden until $_revieweeName also submits theirs, or until 7 days pass.',
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5) return 'Exceptional! 🤩';
    if (rating >= 4) return 'Great Experience! 😊';
    if (rating >= 3) return 'It was Okay 😐';
    if (rating >= 2) return 'Could be Better 😕';
    if (rating >= 1) return 'Poor Experience 😞';
    return 'Select a rating';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return const Color(0xFF16A34A);
    if (rating >= 3) return const Color(0xFFF59E0B);
    if (rating >= 1) return const Color(0xFFEF4444);
    return Colors.black87;
  }
}

// ─── Star Selector ───────────────────────────────────────────────────────────

class _StarSelector extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;

  const _StarSelector({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starValue = (i + 1).toDouble();
        final isSelected = rating >= starValue;
        
        return GestureDetector(
          onTap: () {
            onChanged(starValue);
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: isSelected ? 1.1 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isSelected ? const Color(0xFFFACC15) : Colors.grey.shade300,
                size: 52,
              ),
            ),
          ),
        );
      }),
    );
  }
}
