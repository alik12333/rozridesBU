import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../models/listing_model.dart';
import '../car_detail_screen.dart';
import '../search_screen.dart';

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  bool _isLoading = true;
  bool _isMapMode = true;

  final Completer<GoogleMapController> _mapController = Completer();
  final ScrollController _listScrollController = ScrollController();

  Position? _currentPosition;
  double _searchRadius = 15.0;
  String? _selectedListingId;

  List<ListingModel> _carsInRadius = [];
  StreamSubscription? _geoSubscription;

  BitmapDescriptor? _defaultMarkerIcon;
  BitmapDescriptor? _selectedMarkerIcon;

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    // 1) Ensure the spinner goes away after 2.5 seconds no matter what
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isLoading) {
        if (_currentPosition == null) {
          _setKarachiFallback();
        } else {
          setState(() => _isLoading = false);
        }
      }
    });

    // 2) Original logic
    _initMarkerIcons()
        .catchError((_) {})
        .whenComplete(() => _checkLocationPermissions());
  }

  @override
  void dispose() {
    _geoSubscription?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  // ─── Marker icons ──────────────────────────────────────────────────────────

  Future<BitmapDescriptor> _buildDotIcon({
    required double radius,
    required Color fill,
    required Color border,
  }) async {
    final size = (radius * 2 + 4).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(radius + 2, radius + 2);

    // White ring border
    canvas.drawCircle(center, radius + 2, Paint()..color = border);
    // Fill
    canvas.drawCircle(center, radius, Paint()..color = fill);

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _initMarkerIcons() async {
    _defaultMarkerIcon = await _buildDotIcon(
      radius: 10,
      fill: Colors.black87,
      border: Colors.white,
    );
    _selectedMarkerIcon = await _buildDotIcon(
      radius: 14,
      fill: const Color(0xFF7C3AED),
      border: Colors.white,
    );
  }

  // ─── Location ──────────────────────────────────────────────────────────────

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setKarachiFallback();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setKarachiFallback();
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      _setKarachiFallback();
      return;
    }

    _startGeoQuery();
    if (mounted) setState(() => _isLoading = false);
  }

  void _setKarachiFallback() {
    _currentPosition = Position(
      latitude: 24.8607,
      longitude: 67.0011,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    _startGeoQuery();
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Camera idle → re-query ────────────────────────────────────────────────

  void _onCameraIdle() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    final bounds = await controller.getVisibleRegion();

    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;

    _currentPosition = Position(
      latitude: centerLat,
      longitude: centerLng,
      timestamp: DateTime.now(),
      accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0,
      heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0,
    );

    // Radius = distance from center to corner (covers full visible region)
    final distMeters = Geolocator.distanceBetween(
      centerLat, centerLng,
      bounds.northeast.latitude, bounds.northeast.longitude,
    );
    _searchRadius = (distMeters / 1000).clamp(2.0, 150.0);
    _startGeoQuery();
  }

  // ─── Geo query (THE CRITICAL FIX) ─────────────────────────────────────────
  //
  //  geoflutterfire_plus requires:
  //    field = the KEY in the Firestore doc that contains the nested geo map
  //    geopointFrom = a function that extracts GeoPoint from that nested map
  //
  //  Our Firestore docs now store:
  //    { geo: { geopoint: GeoPoint, geohash: "..." }, ... flat fields ... }
  //
  //  Old WRONG approach:  field: 'location'  (flat GeoPoint — library can't read this)
  //  Old WRONG approach:  field: 'geohash'   (just a string — library definitely can't use this)
  //  CORRECT:             field: 'geo',  geopointFrom: (data) => data['geo']['geopoint']
  //
  // ──────────────────────────────────────────────────────────────────────────

  void _startGeoQuery() {
    if (_currentPosition == null) return;

    final center = GeoFirePoint(
      GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
    );

    final colRef = FirebaseFirestore.instance.collection('listings');
    final geoRef = GeoCollectionReference<Map<String, dynamic>>(colRef);

    _geoSubscription?.cancel();
    _geoSubscription = geoRef
        .subscribeWithin(
          center: center,
          radiusInKm: _searchRadius,
          field: 'geo', // ← nested geo map field
          geopointFrom: (data) {
            // Extract GeoPoint from the nested geo map
            final geo = data['geo'];
            if (geo is Map && geo['geopoint'] is GeoPoint) {
              return geo['geopoint'] as GeoPoint;
            }
            // Fallback: try reading the flat 'location' field for legacy docs
            if (data['location'] is GeoPoint) {
              return data['location'] as GeoPoint;
            }
            // Must return something — return center as no-op
            return GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
          },
          strictMode: false,
        )
        .listen((docs) {
          if (!mounted) return;

          final cars = docs
              .where((d) {
                // Ensure the doc actually has location data before including it
                final data = d.data() as Map<String, dynamic>?;
                if (data == null) return false;
                final hasGeo = data['geo'] is Map;
                final hasLegacyLocation = data['location'] is GeoPoint;
                return hasGeo || hasLegacyLocation;
              })
              .map((d) => ListingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .where((car) => car.status == 'approved')
              .toList();

          setState(() => _carsInRadius = cars);
          _rebuildMarkers();
        }, onError: (e) {
          debugPrint('GeoQuery error: $e');
        });
  }

  // ─── Markers ───────────────────────────────────────────────────────────────

  Future<void> _rebuildMarkers() async {
    if (_defaultMarkerIcon == null || _selectedMarkerIcon == null) return;

    final newMarkers = <Marker>{};

    for (int i = 0; i < _carsInRadius.length; i++) {
      final car = _carsInRadius[i];
      if (car.location == null) continue;

      final isSelected = car.id == _selectedListingId;

      newMarkers.add(Marker(
        markerId: MarkerId(car.id),
        position: LatLng(car.location!.latitude, car.location!.longitude),
        icon: isSelected ? _selectedMarkerIcon! : _defaultMarkerIcon!,
        zIndex: isSelected ? 2.0 : 1.0,
        onTap: () {
          setState(() => _selectedListingId = car.id);
          _rebuildMarkers();
          _scrollToCard(i);
        },
      ));
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    }
  }

  void _scrollToCard(int index) {
    if (_listScrollController.hasClients) {
      _listScrollController.animateTo(
        index * 132.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _onCardTapped(int index, ListingModel car) async {
    setState(() => _selectedListingId = car.id);
    _rebuildMarkers();

    if (car.location != null && _mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(car.location!.latitude, car.location!.longitude),
          zoom: 15,
        )),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Cars'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildToggle(),
          ),
        ],
      ),
      body: _isMapMode ? _buildSplitView() : const SearchScreen(isEmbedded: true),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(children: [
        _ToggleBtn(label: 'List', icon: Icons.format_list_bulleted,
            active: !_isMapMode, onTap: () => setState(() => _isMapMode = false)),
        _ToggleBtn(label: 'Map', icon: Icons.map,
            active: _isMapMode, onTap: () => setState(() => _isMapMode = true)),
      ]),
    );
  }

  Widget _buildSplitView() {
    return Column(children: [
      // ── TOP: Google Map ───────────────────────────────────────────────────
      Expanded(
        flex: 5,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 13,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: _markers,
          onCameraIdle: _onCameraIdle,
          onMapCreated: (c) {
            if (!_mapController.isCompleted) _mapController.complete(c);
          },
        ),
      ),

      // ── BOTTOM: Listing cards ─────────────────────────────────────────────
      Expanded(
        flex: 5,
        child: Container(
          color: Colors.grey.shade50,
          child: _carsInRadius.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _listScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _carsInRadius.length,
                  itemBuilder: (context, i) => _buildCard(i, _carsInRadius[i]),
                ),
        ),
      ),
    ]);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_searching, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No approved listings in this area.\nPan or zoom to explore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int index, ListingModel car) {
    final isSelected = car.id == _selectedListingId;
    return GestureDetector(
      onTap: () => _onCardTapped(index, car),
      onDoubleTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailScreen(listing: car)),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 120,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.10 : 0.05),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // Image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              color: Colors.grey.shade200,
              image: car.images.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(car.images.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: car.images.isEmpty
                ? const Icon(Icons.directions_car, size: 40, color: Colors.grey)
                : null,
          ),
          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.carName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              car.locationLabel ?? car.city ?? 'Location flexible',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${car.pricePerDay.toStringAsFixed(0)}/day',
                        style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CarDetailScreen(listing: car)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Toggle button ────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: active
              ? [const BoxShadow(color: Color(0x0D000000), blurRadius: 4)]
              : [],
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? const Color(0xFF7C3AED) : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF7C3AED) : Colors.grey,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ]),
      ),
    );
  }
}
