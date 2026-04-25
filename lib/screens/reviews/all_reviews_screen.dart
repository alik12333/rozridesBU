import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/review_model.dart';
import '../../services/booking_service.dart';

class AllReviewsScreen extends StatefulWidget {
  final String targetId;   // carId or userId
  final String targetName;
  final String type;       // 'car' | 'renter_to_host' | 'host_to_renter'

  const AllReviewsScreen({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.type,
  });

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  final BookingService _service = BookingService();
  List<ReviewModel> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List<ReviewModel> reviews;
      if (widget.type == 'car') {
        reviews = await _service.fetchCarReviews(widget.targetId);
      } else {
        reviews = await _service.fetchUserReviews(widget.targetId, widget.type);
      }
      if (mounted) setState(() { _reviews = reviews; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Reviews for ${widget.targetName}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_border_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No reviews yet',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500)),
                      ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (_, i) => _ReviewCard(review: _reviews[i]),
                ),
    );
  }
}

// ─── Review Card ─────────────────────────────────────────────────────────────

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) => _ReviewCard(review: review);
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            backgroundImage: review.reviewerPhoto != null
                ? NetworkImage(review.reviewerPhoto!)
                : null,
            child: review.reviewerPhoto == null
                ? Text(
                    review.reviewerName.isNotEmpty
                        ? review.reviewerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF7C3AED), fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(review.reviewerName,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                    DateFormat('d MMM yyyy').format(review.createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
              ])),
          _Stars(rating: review.overallRating),
        ]),
        const SizedBox(height: 10),
        Text(review.comment,
            style: TextStyle(
                color: Colors.grey.shade700, fontSize: 14, height: 1.5)),
      ]),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = (i + 1).toDouble();
        return Icon(
          rating >= v ? Icons.star_rounded : Icons.star_outline_rounded,
          color: rating >= v ? const Color(0xFFFACC15) : Colors.grey.shade300,
          size: 16,
        );
      }),
    );
  }
}
