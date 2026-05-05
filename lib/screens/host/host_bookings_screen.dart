import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/booking_status_utils.dart';
import '../booking/booking_detail_screen.dart';
import '../trip/pre_trip_inspection_screen.dart';
import 'request_detail_screen.dart';

class HostBookingsScreen extends StatefulWidget {
  const HostBookingsScreen({super.key});

  @override
  State<HostBookingsScreen> createState() => _HostBookingsScreenState();
}

class _HostBookingsScreenState extends State<HostBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) context.read<BookingProvider>().listenToHostBookings(user.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        final pendingCount = provider.hostPendingBookings.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            title: Text('Host Inbox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
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
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
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
                  tabs: [
                    Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Requests'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Text('$pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ])),
                    const Tab(text: 'Upcoming'),
                    const Tab(text: 'Active'),
                    const Tab(text: 'Flagged'),
                    const Tab(text: 'Past'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _BookingList(bookings: provider.hostPendingBookings, emptyMsg: ('No pending requests', 'Booking requests from renters will appear here.'), isHost: true),
              _BookingList(bookings: provider.hostConfirmedBookings, emptyMsg: ('No upcoming bookings', 'Confirmed bookings will appear here.'), isHost: true),
              _BookingList(bookings: provider.hostActiveBookings, emptyMsg: ('No active trips', 'Active rentals will appear here.'), isHost: true),
              _BookingList(bookings: provider.hostFlaggedBookings, emptyMsg: ('No flagged trips', 'Trips under review will appear here.'), isHost: true),
              _BookingList(bookings: provider.hostPastBookings, emptyMsg: ('No past bookings', 'Completed and cancelled bookings appear here.'), isHost: true),
            ],
          ),
        );
      },
    );
  }
}

// ─── Generic booking list ──────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final (String, String) emptyMsg;
  final bool isHost;

  const _BookingList({required this.bookings, required this.emptyMsg, required this.isHost});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(isHost ? Icons.inbox_rounded : Icons.car_rental_rounded,
                size: 64, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 24),
          Text(emptyMsg.$1,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(emptyMsg.$2,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
          ),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (_, i) => _HostBookingCard(booking: bookings[i]),
    );
  }
}

// ─── Host Booking Card ─────────────────────────────────────────────────────────

class _HostBookingCard extends StatelessWidget {
  final BookingModel booking;
  const _HostBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fmt = DateFormat('MMM d, yyyy');
    final color = getStatusColor(b.status);

    return GestureDetector(
      onTap: () {
        if (b.status == 'pending') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(bookingId: b.id)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
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
                                child: Icon(Icons.circle, size: 10, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(getStatusLabel(b.status),
                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                              Text(fmt.format(b.startDate),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Renter row
                  Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      child: Text(
                        b.renterName.isNotEmpty ? b.renterName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.renterName.isNotEmpty ? b.renterName : 'Renter',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(b.carName,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    )),
                    // Income badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF16A34A).withValues(alpha: 0.15), const Color(0xFF16A34A).withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PKR ${b.totalRent.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Dates
                  Row(children: [
                    Icon(Icons.login_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(fmt.format(b.startDate), style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(fmt.format(b.actualEndDate), style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('${b.totalDays}d',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  // Action button
                  _actionButton(context, b),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, BookingModel b) {
    String? label;
    Color? color;
    VoidCallback? onTap;

    if (b.status == 'confirmed') {
      final canStart = !DateTime.now().isBefore(
          b.startDate.subtract(const Duration(hours: 2)));
      
      label = canStart ? 'Start Handover' : 'Available ${DateFormat('MMM d').format(b.startDate)}';
      color = canStart ? const Color(0xFF16A34A) : Colors.grey.shade400;
      onTap = canStart ? () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PreTripInspectionScreen(booking: b))) : null;
    } else if (b.status == 'active') {
      label = 'Complete Return';
      color = Colors.blue.shade700;
      onTap = () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BookingDetailScreen(bookingId: b.id)));
    } else if (b.status == 'pending') {
      label = 'View Request';
      color = const Color(0xFF7C3AED);
      onTap = () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RequestDetailScreen(bookingId: b.id)));
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: (color ?? Colors.grey).withValues(alpha: 0.3),
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
  }
}
