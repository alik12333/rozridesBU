import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result returned from the LocationPickerScreen.
/// Contains the pinned coordinates + a human-readable label (e.g. "DHA Phase 6, Karachi").
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

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _cameraCenter = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      await _reverseGeocode(_cameraCenter);
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

        // Extract meaningful area name — sub-locality is most granular
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
            .toSet() // remove duplicates (when area == city)
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

  void _onCameraIdle(LatLng latLng) {
    setState(() => _cameraCenter = latLng);
    _reverseGeocode(latLng);
  }

  void _confirmLocation() {
    // Parse city and area from label for Firestore
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
      appBar: AppBar(
        title: const Text('Pin Car Location'),
        leading: const BackButton(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              onPressed: _isGeocoding ? null : _confirmLocation,
              child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _cameraCenter,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onCameraMove: (CameraPosition position) {
                    // Update center silently while moving
                    _cameraCenter = position.target;
                  },
                  onCameraIdle: () {
                    _onCameraIdle(_cameraCenter);
                  },
                ),

                // Fixed center pin icon
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0),
                    child: Icon(Icons.location_pin, size: 52, color: Color(0xFF7C3AED)),
                  ),
                ),

                // Location label at bottom
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isGeocoding
                              ? const Text('Detecting location...', style: TextStyle(color: Colors.grey))
                              : Text(
                                  _locationLabel,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 2,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Instruction chip at top
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app, size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          'Drag the map to pin your car\'s exact location',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
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
