import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../booking/booking_detail_screen.dart';

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
        title: Text('My Bookings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C3AED),
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
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
          Icon(Icons.car_rental_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(msgs[i].$1,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(msgs[i].$2, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
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
          borderRadius: BorderRadius.circular(20),
          border: b.status == 'pending'
              ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(b.status), size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusLabel(b.status),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
                  if (b.status == 'pending' && remaining > Duration.zero)
                    _countdownChip(remaining, color),
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
                      Text('PKR ${b.totalRent.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: const Color(0xFF7C3AED))),
                    ],
                  ),
                  if (_keyAmount(b).isNotEmpty) ...[
                    const SizedBox(height: 10),
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
            Navigator.of(context).pushNamed('/cancel', arguments: {'bookingId': b.id, 'cancelledBy': 'renter'}));
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reviews in Phase 9'))));
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

  Widget _fillBtn(String label, Color color, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _outlineBtn(String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _countdownChip(Duration r, Color color) {
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
