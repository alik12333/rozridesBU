import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/listing_model.dart';

class AnimatedListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isOwner;

  const AnimatedListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onDelete,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(listing.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image & Overlays
                Stack(
                  children: [
                    Hero(
                      tag: 'listing_${listing.id}',
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: listing.images.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: listing.images.first,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[100],
                                  child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
                                ),
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
                              ),
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
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Status Badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: statusColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(listing.status), color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusLabel(listing.status).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Price Badge
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Daily Rate',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'PKR ${listing.pricePerDay.toInt()}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Delete Button
                    if (isOwner && onDelete != null)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),

                // Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.carName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${listing.area}, ${listing.city}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Feature Row
                      Row(
                        children: [
                          _buildFeaturePill(
                            icon: Icons.settings_input_component_rounded,
                            label: listing.transmission,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildFeaturePill(
                            icon: Icons.local_gas_station_rounded,
                            label: listing.fuelType,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          if (listing.withDriver)
                            _buildFeaturePill(
                              icon: Icons.person_pin_rounded,
                              label: 'With Driver',
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return const Color(0xFF10B981);
      case 'pending':  return const Color(0xFFF59E0B);
      case 'rejected': return const Color(0xFFEF4444);
      case 'draft':    return Colors.blueGrey;
      default:         return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Icons.check_circle_rounded;
      case 'pending':  return Icons.hourglass_empty_rounded;
      case 'rejected': return Icons.error_outline_rounded;
      default:         return Icons.info_outline_rounded;
    }
  }

  String _getStatusLabel(String status) {
    if (status.isEmpty) return 'Draft';
    return status[0].toUpperCase() + status.substring(1);
  }
}
