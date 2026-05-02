import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../booking/booking_detail_screen.dart';
import '../reviews/submit_review_screen.dart';
import '../../services/booking_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['Upcoming', 'Active', 'Flagged', 'Past'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) context.read<BookingProvider>().listenToRenterBookings(user.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> _getTabBookings(int i, BookingProvider p) {
    switch (i) {
      case 0: return p.upcomingBookings;
      case 1: return p.activeBookings;
      case 2: return p.flaggedBookings;
      case 3: return p.pastBookings;
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('My Bookings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) => TabBarView(
          controller: _tabController,
          children: List.generate(_tabs.length, (i) {
            final bookings = _getTabBookings(i, provider);
            if (bookings.isEmpty) return _emptyState(i);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, j) => _BookingCard(booking: bookings[j]),
            );
          }),
        ),
      ),
    );
  }

  Widget _emptyState(int i) {
    const msgs = [
      ('No upcoming bookings', 'Pending and confirmed bookings will appear here.'),
      ('No active trips', 'Your current rentals will appear here.'),
      ('No flagged trips', 'Trips under review will appear here.'),
      ('No past bookings', 'Completed and expired bookings will appear here.'),
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.car_rental_rounded, size: 64, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 24),
          Text(msgs[i].$1,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(msgs[i].$2, style: TextStyle(color: Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ─── Booking Card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.booking.status == 'pending') {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':   return const Color(0xFF7C3AED);
      case 'confirmed': return Colors.green;
      case 'active':    return Colors.blue;
      case 'flagged':   return Colors.purple;
      case 'completed': return Colors.blueGrey;
      case 'rejected':
      case 'expired':   return Colors.red;
      case 'cancelled': return Colors.grey;
      default:          return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':   return Icons.hourglass_top_rounded;
      case 'confirmed': return Icons.check_circle_rounded;
      case 'active':    return Icons.directions_car_rounded;
      case 'flagged':   return Icons.gavel_rounded;
      case 'completed': return Icons.done_all_rounded;
      case 'rejected':  return Icons.cancel_rounded;
      case 'expired':   return Icons.timer_off_rounded;
      case 'cancelled': return Icons.block_rounded;
      default:          return Icons.info_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':   return 'Awaiting Host Response';
      case 'confirmed': return 'Confirmed — Ready to Go!';
      case 'active':    return 'Trip In Progress';
      case 'flagged':   return 'Under Review';
      case 'completed': return 'Completed';
      case 'rejected':  return 'Declined by Host';
      case 'expired':   return 'Expired — No Response';
      case 'cancelled': return 'Cancelled';
      default:          return s.toUpperCase();
    }
  }

  String _keyAmount(BookingModel b) {
    final fmt = DateFormat('MMM d');
    switch (b.status) {
      case 'pending':   return 'Bring PKR ${b.securityDeposit.toStringAsFixed(0)} if accepted';
      case 'confirmed': return 'Bring PKR ${b.securityDeposit.toStringAsFixed(0)} on ${fmt.format(b.startDate)}';
      case 'active':    return 'Return by ${fmt.format(b.endDate)}';
      case 'completed': return 'Trip completed ✓';
      default:          return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final fmt = DateFormat('MMM d, yyyy');
    final color = _statusColor(b.status);
    final remaining = b.expiresAt.difference(DateTime.now());

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BookingDetailScreen(bookingId: b.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: b.status == 'pending'
              ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), width: 1.5)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car Image Header with Glassmorphism Status Ribbon
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: b.carPhoto.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: b.carPhoto,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => Container(color: Colors.grey.shade200),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.directions_car_rounded, size: 48, color: Colors.grey)),
                          ),
                  ),
                  // Gradient Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                    ),
                  ),
                  // Glassmorphism Status Ribbon
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_statusIcon(b.status), size: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_statusLabel(b.status),
                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                              if (b.status == 'pending' && remaining > Duration.zero)
                                _countdownChip(remaining, Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.carName.isNotEmpty ? b.carName : 'Car',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _dateChip(Icons.login_rounded, fmt.format(b.startDate), 'Pick-up'),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      _dateChip(Icons.logout_rounded, fmt.format(b.endDate), 'Drop-off'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pillBadge('${b.totalDays} day${b.totalDays > 1 ? 's' : ''}'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('PKR ${b.totalRent.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.bold,
                                color: const Color(0xFF7C3AED))),
                      ),
                    ],
                  ),
                  if (_keyAmount(b).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_keyAmount(b),
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (b.rejectionReason != null && b.status == 'rejected') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Text('Reason: ${b.rejectionReason}',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons
            _buildActions(context, b),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, BookingModel b) {
    Widget? primary;
    Widget? secondary;

    switch (b.status) {
      case 'pending':
        secondary = _outlineBtn('Cancel Request', Colors.red.shade600, () =>
            _confirmCancelRequest(context, b.id));
        primary = _fillBtn('View Details', const Color(0xFF7C3AED), () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id))));
        break;
      case 'confirmed':
        primary = _fillBtn('View Details', const Color(0xFF7C3AED), () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id))));
        break;
      case 'completed':
        final reviewDone = b.reviewStatus['renterSubmitted'] == true;
        if (!reviewDone) {
          secondary = _outlineBtn('Leave Review', Colors.amber.shade700, () =>
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SubmitReviewScreen(booking: b, reviewType: 'renter_to_host'),
              )));
        }
        primary = _fillBtn('View Details', Colors.grey.shade600, () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id))));
        break;
      case 'rejected':
      case 'expired':
      case 'cancelled':
      case 'flagged':
        primary = _fillBtn('View Details', Colors.grey.shade600, () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id))));
        break;
      default: return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        if (secondary != null) ...[Expanded(child: secondary), const SizedBox(width: 10)],
        Expanded(flex: secondary != null ? 2 : 1, child: primary),
      ]),
    );
  }

  Future<void> _confirmCancelRequest(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Request?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to cancel this booking request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await BookingService().cancelBooking(
        bookingId: bookingId,
        reason: 'Cancelled by renter',
        cancelledBy: 'renter',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _fillBtn(String label, Color color, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      );

  Widget _outlineBtn(String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
          backgroundColor: color.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
      );

  Widget _countdownChip(Duration r, Color color) {
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color == Colors.white ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)
      ),
      child: Text('$h:$m:$s', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _dateChip(IconData icon, String date, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      );

  Widget _pillBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 12)),
      );
}
