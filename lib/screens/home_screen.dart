import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/listing_provider.dart';
import '../models/listing_model.dart';
import 'car_detail_screen.dart';
import 'search/map_search_screen.dart';
import 'renter/my_bookings_screen.dart';
import 'host/incoming_requests_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'my_listings_screen.dart';
import 'add_listing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().loadAllListings();
      
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        final bookingProvider = context.read<BookingProvider>();
        bookingProvider.listenToHostBookings(user.id);
        bookingProvider.listenToRenterBookings(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      key: _scaffoldKey,
      // ── Drawer ────────────────────────────────────────────────────────────
      drawer: _AppDrawer(user: user),
      // ── AppBar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            // Hamburger icon
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Text(
              'RozRides',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search on map',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapSearchScreen()),
            ),
          ),
        ],
      ),
      // ── Body ─────────────────────────────────────────────────────────────
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ListingProvider>().loadAllListings();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'Guest',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Find your perfect ride',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Available Cars
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Cars',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapSearchScreen()),
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Consumer<ListingProvider>(
                builder: (context, provider, _) {
                  if (provider.status == ListingStatus.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (provider.allListings.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.directions_car_outlined,
                                size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No cars available yet',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Be the first to list your car!',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.allListings.length,
                    itemBuilder: (_, i) =>
                        _CarCard(listing: provider.allListings[i]),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drawer ─────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final dynamic user; // UserModel

  const _AppDrawer({required this.user});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context); // close drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── User Header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  backgroundImage: (user?.profilePhoto != null &&
                          (user!.profilePhoto as String).isNotEmpty)
                      ? NetworkImage(user!.profilePhoto as String)
                      : null,
                  child: (user?.profilePhoto == null ||
                          (user!.profilePhoto as String).isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 32)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName ?? 'Guest',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Scrollable tile list ───────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
              // ── ACCOUNT ──────────────────────────────────────────────
                _sectionLabel('Account'),
                _DrawerTile(
                  icon: Icons.person_outline,
                  label: 'My Profile',
                  onTap: () => _go(context, const ProfileScreen()),
                ),
                const Divider(indent: 16, endIndent: 16, height: 24),

                // ── AS RENTER ────────────────────────────────────────────
                _sectionLabel('As Renter'),
                _DrawerTile(
                  icon: Icons.book_outlined,
                  label: 'My Bookings',
                  onTap: () => _go(context, const MyBookingsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () => _go(context, const NotificationsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.map_outlined,
                  label: 'Search on Map',
                  onTap: () => _go(context, const MapSearchScreen()),
                ),

                const Divider(indent: 16, endIndent: 16, height: 24),

                // ── AS HOST ──────────────────────────────────────────────
                _sectionLabel('As Host'),
                _DrawerTile(
                  icon: Icons.inbox_rounded,
                  label: 'Incoming Requests',
                  onTap: () => _go(context, const IncomingRequestsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.directions_car_outlined,
                  label: 'My Listings',
                  onTap: () => _go(context, const MyListingsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add a Listing',
                  onTap: () => _go(context, const AddListingScreen()),
                ),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: Text('Sign Out',
                  style: TextStyle(
                      color: Colors.red.shade700, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().signOut();
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
      );
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}



class _CarCard extends StatelessWidget {
  final ListingModel listing;

  const _CarCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarDetailScreen(listing: listing),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (listing.images.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  listing.images.first,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    '${listing.carName} ${listing.model}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Year and Engine
                  Text(
                    '${listing.year} • ${listing.engineSize}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Row(
                    children: [
                      const Icon(Icons.payments, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'PKR ${listing.pricePerDay.toStringAsFixed(0)}/day',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Features
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FeatureChip(
                        icon: listing.withDriver ? Icons.person : Icons.person_off,
                        label: listing.withDriver ? 'With Driver' : 'Self Drive',
                      ),
                      _FeatureChip(
                        icon: listing.hasInsurance ? Icons.shield : Icons.warning,
                        label: listing.hasInsurance ? 'Insured' : 'No Insurance',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Owner info
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.person, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        listing.ownerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
