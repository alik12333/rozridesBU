import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/listing_model.dart';
import '../models/pricing_breakdown_model.dart';
import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../widgets/availability_calendar.dart';
import '../utils/pricing_calculator.dart';
import 'booking/booking_summary_screen.dart';
import 'reviews/all_reviews_screen.dart';
import '../services/chat_service.dart';
import 'chat/chat_screen.dart';
import 'car_location_map_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final ListingModel listing;

  const CarDetailScreen({super.key, required this.listing});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  int _currentImageIndex = 0;
  DateTime? _selectedStart;
  DateTime? _selectedEnd;
  CashPricingBreakdown? _pricingEstimate;
  List<ReviewModel> _reviews = [];
  bool _reviewsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final reviews = await BookingService().fetchCarReviews(widget.listing.id, limit: 3);
    if (mounted) setState(() { _reviews = reviews; _reviewsLoaded = true; });
  }

  void _updatePricing() {
    if (_selectedStart != null && _selectedEnd != null) {
      try {
        final estimate = PricingCalculator.calculate(
          startDate: _selectedStart!,
          endDate: _selectedEnd!,
          pricePerDay: widget.listing.pricePerDay,
          securityDeposit: 10000.0, // Fixed PKR 10k standard deposit for MVP based on PDF
          withDriver: widget.listing.withDriver,
        );
        setState(() { _pricingEstimate = estimate; });
      } catch (e) {
        setState(() { _pricingEstimate = null; });
      }
    } else {
      setState(() { _pricingEstimate = null; });
    }
  }

  Future<void> _callOwner() async {
    final phoneNumber = widget.listing.ownerPhone;
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to message the host.')),
      );
      return;
    }
    if (user.id == widget.listing.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself.')),
      );
      return;
    }

    try {
      final conv = await ChatService().getOrCreateConversation(
        carId: widget.listing.id,
        carName: widget.listing.carName,
        hostId: widget.listing.ownerId,
        hostName: widget.listing.ownerName,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conv.conversationId,
              currentUserId: user.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image Carousel
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image Carousel
                  PageView.builder(
                    itemCount: widget.listing.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        widget.listing.images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  ),

                  // Image Counter
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${widget.listing.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PKR ${widget.listing.pricePerDay.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'Rental Price Per Day',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Security Deposit: PKR 10,000',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.money, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'All payments are CASH paid directly to host',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.listing.carName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.listing.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.speed, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.listing.mileage} KM',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Specifications
                      const Text(
                        'Specifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _SpecRow(icon: Icons.branding_watermark, label: 'Brand', value: widget.listing.brand),
                      _SpecRow(icon: Icons.style, label: 'Model', value: widget.listing.model),
                      _SpecRow(icon: Icons.settings, label: 'Engine', value: widget.listing.engineSize),
                      _SpecRow(icon: Icons.local_gas_station, label: 'Fuel Type', value: widget.listing.fuelType),
                      _SpecRow(icon: Icons.settings_input_component, label: 'Transmission', value: widget.listing.transmission),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Features
                      const Text(
                        'Features & Services',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _FeatureChip(
                            icon: widget.listing.withDriver ? Icons.person : Icons.person_off,
                            label: widget.listing.withDriver ? 'With Driver' : 'Self Drive',
                            color: widget.listing.withDriver ? Colors.blue : Colors.grey,
                          ),
                          _FeatureChip(
                            icon: widget.listing.hasInsurance ? Icons.shield : Icons.warning,
                            label: widget.listing.hasInsurance ? 'Insured' : 'No Insurance',
                            color: widget.listing.hasInsurance ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.listing.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Location
                      if (widget.listing.city != null || widget.listing.area != null) ...[
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: widget.listing.location != null ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CarLocationMapScreen(
                                  location: widget.listing.location!,
                                  carName: widget.listing.carName,
                                ),
                              ),
                            );
                          } : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.red.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${widget.listing.area ?? ''}, ${widget.listing.city ?? ''}',
                                    style: TextStyle(fontSize: 16, color: widget.listing.location != null ? Theme.of(context).primaryColor : Colors.black),
                                  ),
                                ),
                                if (widget.listing.location != null)
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).primaryColor),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Availability',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedStart = DateTime.now();
                                _selectedEnd = DateTime.now();
                              });
                              _updatePricing();
                            },
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('1 Day (Today)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                              foregroundColor: const Color(0xFF7C3AED),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AvailabilityCalendar(
                        bookedDateRanges: widget.listing.bookedDateRanges,
                        onRangeSelected: (start, end) {
                          setState(() {
                            _selectedStart = start;
                            _selectedEnd = end;
                          });
                          _updatePricing();
                        },
                      ),

                      // Trip Estimate Section
                      if (_pricingEstimate != null) ...[
                        const SizedBox(height: 32),
                        const Text(
                          'Trip Estimate',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_pricingEstimate!.totalDays} days x PKR ${widget.listing.pricePerDay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16)),
                                  Text('PKR ${(_pricingEstimate!.pricePerDay * _pricingEstimate!.totalDays).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (_pricingEstimate!.driverFeePerDay > 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Driver fee (${_pricingEstimate!.totalDays} days x PKR ${_pricingEstimate!.driverFeePerDay.toStringAsFixed(0)})', style: const TextStyle(fontSize: 16)),
                                    Text('PKR ${(_pricingEstimate!.driverFeePerDay * _pricingEstimate!.totalDays).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Security deposit (at pickup)', style: TextStyle(fontSize: 16)),
                                  Text('PKR ${_pricingEstimate!.depositAtPickup.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Bring to pickup (Cash)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                  Text('PKR ${_pricingEstimate!.depositAtPickup.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      const Text(
                        'How Cash Works',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildTimelineStep('1', 'Pay deposit at pickup', 'Hand over cash keys and sign the agreement.'),
                            _buildTimelineStep('2', 'Take the car', 'Enjoy your ride safely.'),
                            _buildTimelineStep('3', 'Return car at end of trip', 'Meet the host again to complete the trip.'),
                            _buildTimelineStep('4', 'Pay rent, get deposit back', 'Host inspects car. You pay rent, host refunds deposit.'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Owner Info
                      const Text(
                        'Host Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.person, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.listing.ownerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.listing.ownerPhone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.verified, size: 16, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text('Verified Host', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded),
                                color: const Color(0xFF7C3AED),
                                onPressed: _startChat,
                                tooltip: 'Message Host',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // ── Reviews Section ──────────────────────────────────
                      _ReviewsSection(
                        listing: widget.listing,
                        reviews: _reviews,
                        loaded: _reviewsLoaded,
                      ),

                      const SizedBox(height: 100), // bottom button space
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedStart != null && _selectedEnd != null) ? () {
                final user = context.read<AuthProvider>().currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please login to book.')),
                  );
                  return;
                }
                if (user.id == widget.listing.ownerId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You cannot book your own car.')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BookingSummaryScreen(
                      listing: widget.listing,
                      startDate: _selectedStart!,
                      endDate: _selectedEnd!,
                      pricing: _pricingEstimate!,
                    ),
                  ),
                );
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Text(
                (_selectedStart != null && _selectedEnd != null && _pricingEstimate != null)
                  ? 'REQUEST TO BOOK - PKR ${_pricingEstimate!.netCostToRenter.toStringAsFixed(0)} total'
                  : 'Select Dates to Continue',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildTimelineStep(String number, String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF7C3AED),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        )
      ],
    ),
  );
}

// ─── Reviews Section ─────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  final ListingModel listing;
  final List<ReviewModel> reviews;
  final bool loaded;

  const _ReviewsSection({
    required this.listing,
    required this.reviews,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header with average
      Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (listing.totalReviews > 0) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFACC15), size: 18),
              const SizedBox(width: 4),
              Text(listing.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(' (${listing.totalReviews} ${listing.totalReviews == 1 ? "review" : "reviews"})',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ])
          ],
        ])),
        if (listing.totalReviews > 3)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AllReviewsScreen(
                        targetId: listing.id,
                        targetName: listing.carName,
                        type: 'car',
                      )),
            ),
            child: Text('View all ${listing.totalReviews}',
                style: const TextStyle(color: Color(0xFF7C3AED))),
          ),
      ]),

      // Rating breakdown bars
      if (listing.totalReviews > 0) ...[
        const SizedBox(height: 16),
        ...List.generate(5, (i) {
          final star = (5 - i).toString();
          final count = listing.ratingBreakdown[star] ?? 0;
          final pct = listing.totalReviews > 0
              ? count / listing.totalReviews
              : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text('$star ★',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                  child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFFFACC15),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 8),
              SizedBox(
                  width: 24,
                  child: Text('$count',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12))),
            ]),
          );
        }),
        const SizedBox(height: 16),
      ],

      // Review cards (max 3)
      if (!loaded)
        const Center(child: CircularProgressIndicator())
      else if (reviews.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: Text('No reviews yet. Be the first to review this car!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        )
      else
        ...reviews.map((r) => _SmallReviewCard(review: r)),

      if (reviews.length >= 3 && listing.totalReviews > 3)
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_forward,
                size: 16, color: Color(0xFF7C3AED)),
            label: const Text('View all reviews',
                style: TextStyle(color: Color(0xFF7C3AED))),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AllReviewsScreen(
                        targetId: listing.id,
                        targetName: listing.carName,
                        type: 'car',
                      )),
            ),
          ),
        ),
    ]);
  }
}

class _SmallReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _SmallReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            child: Text(
              review.reviewerName.isNotEmpty
                  ? review.reviewerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(review.reviewerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              return Icon(
                (i + 1).toDouble() <= review.overallRating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: (i + 1).toDouble() <= review.overallRating
                    ? const Color(0xFFFACC15)
                    : Colors.grey.shade300,
                size: 14,
              );
            }),
          ),
        ]),
        const SizedBox(height: 8),
        Text(review.comment,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.4)),
      ]),
    );
  }
}

