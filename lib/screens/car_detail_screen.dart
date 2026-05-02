import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final reviews = await BookingService().fetchCarReviews(widget.listing.id, limit: 100);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _reviewsLoaded = true;
      });
    }
  }

  void _updatePricing() {
    if (_selectedStart != null) {
      try {
        final estimate = PricingCalculator.calculate(
          startDate: _selectedStart!,
          endDate: _selectedEnd ?? _selectedStart!, // Support 1-day trip
          pricePerDay: widget.listing.pricePerDay,
          securityDeposit: 10000.0,
          withDriver: widget.listing.withDriver,
        );
        setState(() {
          _pricingEstimate = estimate;
        });
      } catch (e) {
        setState(() {
          _pricingEstimate = null;
        });
      }
    } else {
      setState(() {
        _pricingEstimate = null;
      });
    }
  }

  void _openFullScreenImage(int index) {
    showDialog(
      context: context,
      builder: (context) => _FullScreenImageViewer(
        images: widget.listing.images,
        initialIndex: index,
      ),
    );
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
    final themeColor = const Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. Premium Hero Header
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            stretch: false, // Important for horizontal PageView gestures
            backgroundColor: Colors.white,
            elevation: 0,
            leading: _circleAction(Icons.arrow_back, () => Navigator.pop(context)),
            actions: [
              _circleAction(Icons.share_outlined, () {}),
              const SizedBox(width: 8),
              _circleAction(Icons.favorite_border, () {}),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.listing.images.length,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _openFullScreenImage(index),
                        child: Hero(
                          tag: 'car_image_$index',
                          child: Image.network(
                            widget.listing.images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                          stops: const [0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.listing.images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentImageIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Car Primary Info
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.listing.carName,
                                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _metaItem(Icons.star_rounded, '${widget.listing.averageRating.toStringAsFixed(1)} (${_reviews.length} reviews)', const Color(0xFFFACC15)),
                                _metaItem(Icons.verified_rounded, 'Verified Car', Colors.blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('PKR ${widget.listing.pricePerDay.toInt()}',
                              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: themeColor)),
                          Text('/ day', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _featureIcon(Icons.calendar_today_rounded, '${widget.listing.year}'),
                      _featureIcon(Icons.speed_rounded, '${widget.listing.mileage} km'),
                      _featureIcon(Icons.settings_input_component_rounded, widget.listing.transmission),
                      _featureIcon(Icons.local_gas_station_rounded, widget.listing.fuelType),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Detailed Sections
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionTitle('Host'),
                _hostCard(),
                const SizedBox(height: 32),
                
                _sectionTitle('Description'),
                Text(widget.listing.description,
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.blueGrey.shade700, height: 1.6)),
                const SizedBox(height: 32),

                _sectionTitle('Location'),
                _locationCard(),
                const SizedBox(height: 32),

                _sectionTitle('Availability'),
                const SizedBox(height: 12),
                AvailabilityCalendar(
                  bookedDateRanges: widget.listing.bookedDateRanges,
                  onRangeSelected: (start, end) {
                    setState(() { _selectedStart = start; _selectedEnd = end; });
                    _updatePricing();
                  },
                ),
                const SizedBox(height: 32),

                if (_pricingEstimate != null) ...[
                  _sectionTitle('Trip Summary'),
                  _pricingCard(),
                  const SizedBox(height: 32),
                ],

                _sectionTitle('How it works'),
                _howItWorks(),
                const SizedBox(height: 32),

                _sectionTitle('Reviews'),
                _ReviewsSection(listing: widget.listing, reviews: _reviews, loaded: _reviewsLoaded),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomAction(themeColor),
    );
  }

  // Helper Widgets
  Widget _circleAction(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
            child: IconButton(icon: Icon(icon, size: 20, color: Colors.black87), onPressed: onTap),
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700)),
    ]);
  }

  Widget _featureIcon(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF64748B), size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _hostCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            child: Text(widget.listing.ownerName[0].toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.listing.ownerName, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('Joined 2024 • Verified', style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey.shade500)),
              ],
            ),
          ),
          _circleIconButton(Icons.chat_bubble_outline_rounded, _startChat),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF7C3AED)), onPressed: onTap),
    );
  }

  Widget _locationCard() {
    return InkWell(
      onTap: () {
        if (widget.listing.location != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CarLocationMapScreen(location: widget.listing.location!, carName: widget.listing.carName)));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueGrey.shade100)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.location_on_rounded, color: Colors.red.shade400),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.listing.area}, ${widget.listing.city}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('Precise location shared after booking', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _pricingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        children: [
          _pricingRow('Daily Rate', 'PKR ${widget.listing.pricePerDay.toInt()} x ${_pricingEstimate!.totalDays}'),
          if (_pricingEstimate!.driverFeePerDay > 0) _pricingRow('Driver Service', 'PKR ${_pricingEstimate!.driverFeePerDay.toInt()} / day'),
          const Divider(height: 32),
          _pricingRow('Total Rental', 'PKR ${_pricingEstimate!.netCostToRenter.toInt()}', isBold: true),
          _pricingRow('Security Deposit', 'PKR ${_pricingEstimate!.depositAtPickup.toInt()}', color: Colors.blue.shade700),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Pay PKR ${_pricingEstimate!.depositAtPickup.toInt()} cash at handover.', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800))),
            ]),
          )
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 15, color: Colors.blueGrey.shade600)),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _howItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueGrey.shade100)),
      child: Column(
        children: [
          _stepRow('01', 'Request Booking', 'Select dates and send request to host.'),
          _stepRow('02', 'Host Confirms', 'Once accepted, meet the host for handover.'),
          _stepRow('03', 'Security Deposit', 'Pay deposit in cash and take the keys.'),
          _stepRow('04', 'Return & Pay', 'Return the car, pay rent, and get deposit back.'),
        ],
      ),
    );
  }

  Widget _stepRow(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(desc, style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey.shade500)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _bottomAction(Color color) {
    bool canBook = _selectedStart != null && _pricingEstimate != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: canBook ? () {
            final user = context.read<AuthProvider>().currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to book.')));
              return;
            }
            if (user.id == widget.listing.ownerId) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot book your own car.')));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingSummaryScreen(listing: widget.listing, startDate: _selectedStart!, endDate: _selectedEnd ?? _selectedStart!, pricing: _pricingEstimate!)));
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.blueGrey.shade200,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Text(canBook ? 'Request to Book' : 'Select Trip Dates', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

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
    final displayCount = (reviews.length > listing.totalReviews) ? reviews.length : listing.totalReviews;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (displayCount > 0)
        Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFACC15), size: 24),
          const SizedBox(width: 8),
          Text(listing.averageRating.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('•  $displayCount ${displayCount == 1 ? "review" : "reviews"}', style: GoogleFonts.outfit(fontSize: 16, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w600)),
        ])
      else
        Text('No reviews yet', style: GoogleFonts.outfit(fontSize: 16, color: Colors.blueGrey.shade500)),
      
      const SizedBox(height: 24),

      if (!loaded)
        const Center(child: CircularProgressIndicator())
      else if (reviews.isEmpty)
        const SizedBox.shrink()
      else
        ...reviews.take(3).map((r) => _ReviewTile(review: r)),

      if (displayCount > 3)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllReviewsScreen(targetId: listing.id, targetName: listing.carName, type: 'car'))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.blueGrey.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Show all $displayCount reviews', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ),
    ]);
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                child: Text(review.reviewerName[0].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.reviewerName, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('Verified Trip', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment, style: GoogleFonts.inter(fontSize: 14, color: Colors.blueGrey.shade700, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Full Screen Image Viewer ───────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return Hero(
                tag: 'car_image_$index',
                child: InteractiveViewer(
                  child: Image.network(widget.images[index], fit: BoxFit.contain),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
