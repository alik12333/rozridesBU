import 'package:flutter/material.dart';
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
            title: Text('Host Bookings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF7C3AED),
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
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
                      ),
                      child: Text('$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
          Icon(isHost ? Icons.inbox_rounded : Icons.car_rental_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(emptyMsg.$1,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(emptyMsg.$2,
              style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(getStatusLabel(b.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Text(fmt.format(b.startDate),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'PKR ${b.totalRent.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
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
                    Text(fmt.format(b.endDate), style: const TextStyle(fontSize: 13)),
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
      onTap = () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return flow — Phase 5')));
    } else if (b.status == 'pending') {
      label = 'View Request';
      color = const Color(0xFF7C3AED);
      onTap = () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RequestDetailScreen(bookingId: b.id)));
    }

    if (label == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
