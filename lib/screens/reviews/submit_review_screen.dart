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
    if (_commentCtrl.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write at least 20 characters.'),
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
          _isRenterReviewing ? 'Review your trip' : 'Review this renter',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Reviewee card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: Text(
                  _revieweeName.isNotEmpty ? _revieweeName[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.booking.carName,
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_revieweeName,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                  ])),
            ]),
          ),
          const SizedBox(height: 28),

          // Star rating
          Text(
            _isRenterReviewing
                ? 'Rate your overall experience:'
                : 'Rate this renter:',
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StarSelector(
            rating: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 28),

          // Comment
          Text(
            'Tell others about your experience:',
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: _isRenterReviewing
                  ? 'Was the car as described? How was the host to deal with?'
                  : 'Was the renter responsible? Did they return on time and in good condition?',
              hintMaxLines: 3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.schedule, color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Your review will be posted after $_revieweeName also leaves their review, or after 7 days — whichever comes first.',
                style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                    height: 1.5),
              )),
            ]),
          ),
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
                  : const Text('SUBMIT REVIEW',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
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
      children: List.generate(5, (i) {
        final starValue = (i + 1).toDouble();
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              rating >= starValue ? Icons.star_rounded : Icons.star_outline_rounded,
              color: rating >= starValue
                  ? const Color(0xFFFACC15)
                  : Colors.grey.shade400,
              size: 40,
            ),
          ),
        );
      }),
    );
  }
}
