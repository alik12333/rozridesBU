import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Pending', 'Confirmed', 'Active', 'History'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> _getTabBookings(
      int index, BookingProvider provider) {
    switch (index) {
      case 0:
        return provider.renterBookings;
      case 1:
        return provider.pendingBookings;
      case 2:
        return provider.confirmedBookings;
      case 3:
        return provider.activeBookings;
      case 4:
        return provider.cancelledBookings;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF7C3AED),
          labelColor: const Color(0xFF7C3AED),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          return TabBarView(
            controller: _tabController,
            children: List.generate(
              _tabs.length,
              (i) {
                final bookings = _getTabBookings(i, provider);
                if (bookings.isEmpty) return _buildEmptyState(i);
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (_, j) =>
                      _BookingCard(booking: bookings[j]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final messages = [
      ('No bookings yet', 'Your trip history will appear here.'),
      ('No pending requests', 'Requests waiting for host approval will show here.'),
      ('No confirmed bookings', 'Accepted bookings will appear here.'),
      ('No active trips', 'Your active rentals will appear here.'),
      ('No history', 'Cancelled or expired bookings will appear here.'),
    ];
    final (title, sub) = messages[tabIndex];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.car_rental_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Booking Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.booking.status == 'pending') {
      _remaining =
          widget.booking.expiresAt.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining =
              widget.booking.expiresAt.difference(DateTime.now());
          if (_remaining.isNegative) _remaining = Duration.zero;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b   = widget.booking;
    final fmt = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: b.status == 'pending'
            ? Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Status banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor(b.status).withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(b.status),
                    size: 18, color: _statusColor(b.status)),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(b.status),
                  style: TextStyle(
                    color: _statusColor(b.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (b.status == 'pending') _CountdownChip(remaining: _remaining),
              ],
            ),
          ),

          // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Car name
                Text(
                  b.carName.isNotEmpty ? b.carName : 'Car',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Dates
                Row(
                  children: [
                    _infoChip(
                        Icons.login_rounded, fmt.format(b.startDate), 'Pick-up'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    _infoChip(
                        Icons.logout_rounded, fmt.format(b.endDate), 'Drop-off'),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount + days
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _pillBadge(
                        '${b.totalDays} day${b.totalDays > 1 ? 's' : ''}',
                        Icons.calendar_today_outlined),
                    Text(
                      'PKR ${b.totalRent.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),

                // Decline / expiry reason
                if ((b.status == 'rejected' || b.status == 'expired') &&
                    (b.rejectionReason != null || b.status == 'expired')) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b.status == 'expired'
                                ? 'Host did not respond in time.'
                                : 'Reason: ${b.rejectionReason}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Confirmed pickup callout
                if (b.status == 'confirmed') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your booking is confirmed! Pick-up on ${fmt.format(b.startDate)}.',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _infoChip(IconData icon, String main, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(main,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        Text(sub,
            style:
                TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }

  Widget _pillBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':   return const Color(0xFF7C3AED);
      case 'confirmed': return Colors.green;
      case 'active':    return Colors.orange;
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
      case 'confirmed': return 'Confirmed â€” Ready to Go!';
      case 'active':    return 'Trip In Progress';
      case 'completed': return 'Completed';
      case 'rejected':  return 'Declined by Host';
      case 'expired':   return 'Expired â€” No Response';
      case 'cancelled': return 'Cancelled';
      default:          return s.toUpperCase();
    }
  }
}

// â”€â”€ Countdown chip (extracted to keep build clean) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CountdownChip extends StatelessWidget {
  final Duration remaining;
  const _CountdownChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final text = remaining == Duration.zero ? 'Expired' : '$h:$m:$s left';
    final color = remaining.inHours < 3
        ? Colors.red.shade700
        : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

