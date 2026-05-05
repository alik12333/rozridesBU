import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/booking_model.dart';

class CarLocationMapScreen extends StatefulWidget {
  final BookingModel? booking;
  // Fallback fields for compatibility
  final GeoPoint? location;
  final String? carName;
  final bool showPin;

  const CarLocationMapScreen({
    super.key,
    this.booking,
    this.location,
    this.carName,
    this.showPin = false,
  });

  @override
  State<CarLocationMapScreen> createState() => _CarLocationMapScreenState();
}

class _CarLocationMapScreenState extends State<CarLocationMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  double _distanceInKm = 0.0;
  bool _isLoadingLocation = true;
  
  // Use either booking location or provided location
  late final LatLng _carLatLng;
  late final String _displayCarName;

  @override
  void initState() {
    super.initState();
    _carLatLng = widget.booking?.location != null 
        ? LatLng(widget.booking!.location!.latitude, widget.booking!.location!.longitude)
        : LatLng(widget.location?.latitude ?? 0, widget.location?.longitude ?? 0);
    
    _displayCarName = widget.booking?.carName ?? widget.carName ?? 'Car';
    
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _distanceInKm = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _carLatLng.latitude,
        _carLatLng.longitude,
      ) / 1000;
      _isLoadingLocation = false;
    });
  }

  void _recenter(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  void _recenterToFit() {
    if (_currentPosition == null) return;
    
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _currentPosition!.latitude < _carLatLng.latitude ? _currentPosition!.latitude : _carLatLng.latitude,
        _currentPosition!.longitude < _carLatLng.longitude ? _currentPosition!.longitude : _carLatLng.longitude,
      ),
      northeast: LatLng(
        _currentPosition!.latitude > _carLatLng.latitude ? _currentPosition!.latitude : _carLatLng.latitude,
        _currentPosition!.longitude > _carLatLng.longitude ? _currentPosition!.longitude : _carLatLng.longitude,
      ),
    );
    
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF7C3AED);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _carLatLng,
              zoom: widget.showPin ? 16.0 : 14.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            circles: widget.showPin ? {} : {
              Circle(
                circleId: const CircleId('car_location_radius'),
                center: _carLatLng,
                radius: 500,
                fillColor: themeColor.withValues(alpha: 0.15),
                strokeColor: themeColor,
                strokeWidth: 2,
              ),
            },
            markers: widget.showPin ? {
              Marker(
                markerId: const MarkerId('car_pin'),
                position: _carLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                infoWindow: InfoWindow(title: _displayCarName),
              ),
            } : {},
            polylines: (_currentPosition != null && widget.showPin) ? {
              Polyline(
                polylineId: const PolylineId('path_to_car'),
                points: [_currentPosition!, _carLatLng],
                color: themeColor,
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            } : {},
          ),

          // Floating Controls
          Positioned(
            right: 16,
            bottom: 240,
            child: Column(
              children: [
                _mapActionButton(Icons.my_location, () => _recenter(_currentPosition ?? _carLatLng)),
                const SizedBox(height: 12),
                _mapActionButton(Icons.directions_car, () => _recenter(_carLatLng)),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 12),
                  _mapActionButton(Icons.zoom_out_map, _recenterToFit),
                ],
              ],
            ),
          ),

          // Bottom Aesthetic Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.directions_car_filled_rounded, color: themeColor, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayCarName,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.showPin ? 'Exact pickup location' : 'General area (500m radius)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoBadge(Icons.straighten_rounded, 
                        _isLoadingLocation ? "..." : "${_distanceInKm.toStringAsFixed(1)} km", 
                        "Distance"
                      ),
                      _infoBadge(Icons.timer_outlined, 
                        _isLoadingLocation ? "..." : "${(_distanceInKm * 2.5).toStringAsFixed(0)} min", 
                        "Time"
                      ),
                      _infoBadge(Icons.local_gas_station_rounded, "Full Tank", "Fuel"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _openInMaps(_carLatLng.latitude, _carLatLng.longitude),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('START NAVIGATION'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _mapActionButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }

  Widget _infoBadge(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }
}
