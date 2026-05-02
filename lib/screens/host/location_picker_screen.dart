import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result returned from the LocationPickerScreen.
class LocationPickerResult {
  final LatLng latLng;
  final String locationLabel;
  final String? city;
  final String? area;

  const LocationPickerResult({
    required this.latLng,
    required this.locationLabel,
    this.city,
    this.area,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng _cameraCenter = const LatLng(24.8607, 67.0011); // Karachi default
  bool _isLoading = true;
  bool _isGeocoding = false;
  String _locationLabel = 'Drag to set location...';
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _cameraCenter = newPos;
        _isLoading = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
      await _reverseGeocode(newPos);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final area = place.subLocality?.isNotEmpty == true
            ? place.subLocality
            : place.locality?.isNotEmpty == true
                ? place.locality
                : place.administrativeArea;

        final city = place.locality?.isNotEmpty == true
            ? place.locality
            : place.administrativeArea;

        final label = [area, city]
            .where((p) => p != null && p.isNotEmpty && p != area || p == area)
            .toSet()
            .join(', ');

        setState(() {
          _locationLabel = label.isNotEmpty ? label : '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      setState(() {
        _locationLabel = '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      });
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  void _onCameraIdle() {
    _reverseGeocode(_cameraCenter);
  }

  void _confirmLocation() {
    final parts = _locationLabel.split(', ');
    final area = parts.length > 1 ? parts.first : null;
    final city = parts.length > 1 ? parts.last : parts.firstOrNull;

    Navigator.pop(
      context,
      LocationPickerResult(
        latLng: _cameraCenter,
        locationLabel: _locationLabel,
        city: city,
        area: area,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: const BackButton(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _cameraCenter, zoom: 15),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onCameraMove: (p) => _cameraCenter = p.target,
                  onCameraIdle: _onCameraIdle,
                ),

                // Stylized Center Marker
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                          ),
                          child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 24),
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF7C3AED), Colors.transparent],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Instruction Chip
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Drag the map to pin car location',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Action Card
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Current Location FAB
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FloatingActionButton(
                          onPressed: _getUserLocation,
                          backgroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF7C3AED)),
                        ),
                      ),
                      
                      // Bottom Address Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PICKUP LOCATION',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF7C3AED), size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _isGeocoding
                                      ? const LinearProgressIndicator(color: Color(0xFF7C3AED), backgroundColor: Color(0xFFF3E8FF))
                                      : Text(
                                          _locationLabel,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isGeocoding ? null : _confirmLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Confirm Location',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
