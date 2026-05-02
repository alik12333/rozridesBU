import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/listing_provider.dart';
import '../models/listing_model.dart';
import 'car_detail_screen.dart';
import 'search/map_search_screen.dart';
import 'renter/my_bookings_screen.dart';
import 'host/host_bookings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'my_listings_screen.dart';
import 'add_listing_screen.dart';
import 'chat/conversations_list_screen.dart';
import '../providers/chat_provider.dart';

// ── Brand colours (mirrors AppTheme) ─────────────────────────────────────────
const _kPrimary   = Color(0xFF6200EE);
const _kPrimaryDk = Color(0xFF3700B3);
const _kAccent    = Color(0xFF03DAC6);
const _kBg        = Color(0xFFF3E5F5);

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
        context.read<BookingProvider>()
          ..listenToHostBookings(user.id)
          ..listenToRenterBookings(user.id);
        context.read<ChatProvider>().listenToConversations(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: _AppDrawer(user: user),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: () => context.read<ListingProvider>().loadAllListings(),
        child: CustomScrollView(
          slivers: [
            // ── Hero SliverAppBar ─────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: _kPrimaryDk,
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroBanner(
                  user: user,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onSearchTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MapSearchScreen())),
                ),
              ),
              // collapsed app-bar row
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Text('RozRides',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              actions: [
                _NotificationBell(userId: user?.id),
              ],
            ),

            // ── Quick Actions ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _QuickActions()),

            // ── Section header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available Cars',
                        style: GoogleFonts.outfit(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const MapSearchScreen())),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Map View'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Car list ─────────────────────────────────────────────────
            Consumer<ListingProvider>(
              builder: (context, provider, _) {
                if (provider.status == ListingStatus.loading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (provider.allListings.isEmpty) {
                  return SliverFillRemaining(child: _EmptyState());
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CarCard(listing: provider.allListings[i]),
                      childCount: provider.allListings.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Bell (AppBar Action) ────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  final String? userId;
  const _NotificationBell({this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isUnread', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final dynamic user;
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;

  const _HeroBanner(
      {required this.user,
      required this.onMenuTap,
      required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.fullName as String? ?? 'there').split(' ').first;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimaryDk, _kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // decorative circle
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded,
                          color: Color(0xFFFFD54F), size: 18),
                      const SizedBox(width: 6),
                      Text('Good day, $firstName!',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Find Your Perfect Ride',
                      style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 16),
                  // Search pill
                  GestureDetector(
                    onTap: onSearchTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 10),
                          Text('Search by location or city…',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.tune_rounded,
                                color: Colors.black, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final List<_QA> _actions = const [
    _QA(Icons.book_outlined, 'My\nBookings', MyBookingsScreen()),
    _QA(Icons.inbox_rounded, 'Host\nBookings', HostBookingsScreen()),
    _QA(Icons.directions_car_outlined, 'My\nListings', MyListingsScreen()),
    _QA(Icons.add_circle_outline_rounded, 'Add\nListing', AddListingScreen()),
  ];

  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _actions.map((a) => _QAButton(qa: a)).toList(),
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Widget screen;
  const _QA(this.icon, this.label, this.screen);
}

class _QAButton extends StatelessWidget {
  final _QA qa;
  const _QAButton({required this.qa});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => qa.screen)),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(qa.icon, color: _kPrimary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(qa.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  height: 1.2)),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_outlined,
                size: 60, color: _kPrimary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('No Cars Available Yet',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Be the first to list your car!',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ── Car Card ──────────────────────────────────────────────────────────────────
class _CarCard extends StatelessWidget {
  final ListingModel listing;
  const _CarCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CarDetailScreen(listing: listing))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: listing.images.isNotEmpty
                      ? Image.network(
                          listing.images.first,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
                // price badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PKR ${listing.pricePerDay.toStringAsFixed(0)}/day',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                // driver badge
                if (listing.withDriver)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('With Driver',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                  ),
              ],
            ),

            // ── Details ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name + rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${listing.carName} ${listing.model}',
                          style: GoogleFonts.outfit(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listing.totalReviews > 0) ...[
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFB300), size: 16),
                        const SizedBox(width: 3),
                        Text(
                          listing.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 3),
                        Text('(${listing.totalReviews})',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        [listing.area, listing.city]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(', ')
                            .let((s) => s.isNotEmpty ? s : 'Location not set'),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(Icons.speed_rounded,
                          '${listing.year}', Colors.indigo),
                      _chip(Icons.local_gas_station_outlined,
                          listing.fuelType, Colors.orange),
                      _chip(Icons.settings_outlined,
                          listing.transmission, Colors.teal),
                      if (listing.hasInsurance)
                        _chip(Icons.shield_outlined,
                            'Insured', Colors.green),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // owner row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            _kPrimary.withValues(alpha: 0.15),
                        child: Text(
                          listing.ownerName.isNotEmpty
                              ? listing.ownerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(listing.ownerName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_kPrimary, _kPrimaryDk]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('View Car',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
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

  Widget _imgPlaceholder() => Container(
        height: 190,
        color: _kPrimary.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.directions_car_outlined,
              size: 60, color: Color(0xFFBBBBBB)),
        ),
      );

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ── Drawer ────────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final dynamic user;
  const _AppDrawer({required this.user});

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.horizontal(right: Radius.circular(24))),
      child: Column(
        children: [
          // header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimaryDk, _kPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 20),
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
                      ? const Icon(Icons.person,
                          color: Colors.white, size: 32)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(user?.fullName ?? 'Guest',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sectionLabel('Account'),
                Consumer<ChatProvider>(
                  builder: (context, chat, _) => _DrawerTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messages',
                    badgeCount: chat.totalUnreadCount,
                    onTap: () =>
                        _go(context, const ConversationsListScreen()),
                  ),
                ),
                _DrawerTile(
                  icon: Icons.person_outline,
                  label: 'My Profile',
                  onTap: () => _go(context, const ProfileScreen()),
                ),
                const Divider(indent: 16, endIndent: 16, height: 24),
                _sectionLabel('As Renter'),
                _DrawerTile(
                  icon: Icons.book_outlined,
                  label: 'My Bookings',
                  onTap: () => _go(context, const MyBookingsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.map_outlined,
                  label: 'Search on Map',
                  onTap: () => _go(context, const MapSearchScreen()),
                ),
                const Divider(indent: 16, endIndent: 16, height: 24),
                _sectionLabel('As Host'),
                _DrawerTile(
                  icon: Icons.inbox_rounded,
                  label: 'Host Bookings',
                  onTap: () => _go(context, const HostBookingsScreen()),
                ),
                _DrawerTile(
                  icon: Icons.directions_car_outlined,
                  label: 'My Cars',
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

          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.red),
              title: Text('Sign Out',
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600)),
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
              letterSpacing: 1.0),
        ),
      );
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _kPrimary, size: 22),
      title: Text(label,
          style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$badgeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )
          : null,
      onTap: onTap,
      horizontalTitleGap: 8,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ── tiny extension helper ─────────────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
