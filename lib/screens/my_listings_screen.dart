import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/listing_provider.dart';
import '../models/listing_model.dart';
import '../widgets/animated_listing_card.dart';
import 'car_detail_screen.dart';
import 'add_listing_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListings();
    });
  }

  Future<void> _loadListings() async {
    final authProvider = context.read<AuthProvider>();
    final listingProvider = context.read<ListingProvider>();

    if (authProvider.currentUser != null) {
      await listingProvider.loadMyListings(authProvider.currentUser!.id);
    }
  }

  Future<void> _deleteListing(ListingModel listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Car', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${listing.carName}" from your listings?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final listingProvider = context.read<ListingProvider>();

      final success = await listingProvider.deleteListing(
        listing.id,
        authProvider.currentUser!.id,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Car removed successfully', style: GoogleFonts.outfit()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(listingProvider.errorMessage ?? 'Failed to delete'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('My Cars', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddListingScreen()),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Car', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<ListingProvider>(
        builder: (context, listingProvider, child) {
          if (listingProvider.status == ListingStatus.loading && listingProvider.myListings.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
          }

          final listings = listingProvider.myListings;
          final approvedCount = listings.where((l) => l.status.toLowerCase() == 'approved').length;
          final pendingCount = listings.where((l) => l.status.toLowerCase() == 'pending').length;

          return RefreshIndicator(
            onRefresh: _loadListings,
            color: const Color(0xFF7C3AED),
            child: CustomScrollView(
              slivers: [
                // Stats Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _buildStatCard('Total', listings.length.toString(), const Color(0xFF7C3AED)),
                        const SizedBox(width: 12),
                        _buildStatCard('Active', approvedCount.toString(), const Color(0xFF059669)),
                        const SizedBox(width: 12),
                        _buildStatCard('Pending', pendingCount.toString(), const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                ),

                if (listings.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final listing = listings[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedListingCard(
                              listing: listing,
                              isOwner: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CarDetailScreen(listing: listing),
                                  ),
                                );
                              },
                              onDelete: () => _deleteListing(listing),
                            ),
                          );
                        },
                        childCount: listings.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 72,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No cars listed yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Turn your idle car into income.\nStart by adding your first car!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
