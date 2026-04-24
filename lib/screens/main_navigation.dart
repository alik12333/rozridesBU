import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'host/host_bookings_screen.dart';
import 'renter/my_bookings_screen.dart';
import 'add_listing_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _setupBookingStreams(UserModel? user) {
    if (user == null) return;
    final provider = context.read<BookingProvider>();
    provider.listenToHostBookings(user.id);
    provider.listenToRenterBookings(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user != null) _setupBookingStreams(user);

    final isHost = user?.roles?.isOwner == true;

    // Hosts get HostBookingsScreen (4 tabs: Requests/Upcoming/Active/Past)
    // Renters get MyBookingsScreen (3 tabs: Upcoming/Active/Past)
    final Widget bookingsTab =
        isHost ? const HostBookingsScreen() : const MyBookingsScreen();

    final screens = [
      const HomeScreen(),
      bookingsTab,
      const AddListingScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    final pendingCount = isHost
        ? context.watch<BookingProvider>().hostPendingBookings.length
        : 0;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: pendingCount > 0
                ? Badge(
                    label: Text('$pendingCount'),
                    child: Icon(isHost
                        ? Icons.inbox_outlined
                        : Icons.bookmark_border_outlined),
                  )
                : Icon(isHost
                    ? Icons.inbox_outlined
                    : Icons.bookmark_border_outlined),
            selectedIcon: Icon(
                isHost ? Icons.inbox_rounded : Icons.bookmark_rounded),
            label: isHost ? 'Bookings' : 'My Trips',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 32),
            selectedIcon: Icon(Icons.add_circle, size: 32),
            label: 'Add Car',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Updates',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}