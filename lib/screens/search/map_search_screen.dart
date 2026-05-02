import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geocoding/geocoding.dart';
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
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchingLocation = false;

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

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isLoading) {
        if (_currentPosition == null) {
          _setKarachiFallback();
        } else {
          setState(() => _isLoading = false);
        }
      }
    });

    _initMarkerIcons()
        .catchError((_) {})
        .whenComplete(() => _checkLocationPermissions());
  }

  @override
  void dispose() {
    _geoSubscription?.cancel();
    _listScrollController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<BitmapDescriptor> _buildCarIcon({
    required double size,
    required Color color,
    required Color backgroundColor,
  }) async {
    final int canvasSize = (size * 1.8).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(canvasSize / 2, canvasSize / 2);

    canvas.drawCircle(center, canvasSize / 2, Paint()..color = backgroundColor);
    canvas.drawCircle(
      center,
      canvasSize / 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.directions_car.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: Icons.directions_car.fontFamily,
        package: Icons.directions_car.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    final image = await recorder.endRecording().toImage(canvasSize, canvasSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _initMarkerIcons() async {
    _defaultMarkerIcon = await _buildCarIcon(
      size: 20,
      color: Colors.white,
      backgroundColor: Colors.black87,
    );
    _selectedMarkerIcon = await _buildCarIcon(
      size: 26,
      color: Colors.white,
      backgroundColor: const Color(0xFF7C3AED),
    );
  }

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

    final distMeters = Geolocator.distanceBetween(
      centerLat, centerLng,
      bounds.northeast.latitude, bounds.northeast.longitude,
    );
    _searchRadius = (distMeters / 1000).clamp(2.0, 150.0);
    _startGeoQuery();
  }

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
          field: 'geo',
          geopointFrom: (data) {
            final geo = data['geo'];
            if (geo is Map && geo['geopoint'] is GeoPoint) {
              return geo['geopoint'] as GeoPoint;
            }
            if (data['location'] is GeoPoint) {
              return data['location'] as GeoPoint;
            }
            return GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
          },
          strictMode: false,
        )
        .listen((docs) {
          if (!mounted) return;

          final cars = docs
              .where((d) {
                final data = d.data();
                if (data == null) return false;
                final hasGeo = data['geo'] is Map;
                final hasLegacyLocation = data['location'] is GeoPoint;
                return hasGeo || hasLegacyLocation;
              })
              .map((d) => ListingModel.fromMap(d.data()!, d.id))
              .where((car) => car.status == 'approved')
              .toList();

          setState(() => _carsInRadius = cars);
          _rebuildMarkers();
        }, onError: (e) {
          debugPrint('GeoQuery error: $e');
        });
  }

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
        zIndexInt: isSelected ? 2 : 1,
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
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) async {
    if (_carsInRadius.isEmpty) return;
    final car = _carsInRadius[index];
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

  Future<void> _searchArea(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearchingLocation = true);
    try {
      final searchString = '$query, Pakistan';
      final locations = await locationFromAddress(searchString);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        if (_mapController.isCompleted) {
          final controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(loc.latitude, loc.longitude),
            14,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found. Try a different area.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
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
      body: _isMapMode ? _buildMapLayout() : const SearchScreen(isEmbedded: true),
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

  Widget _buildMapLayout() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 13,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          markers: _markers,
          onCameraIdle: _onCameraIdle,
          onMapCreated: (c) {
            if (!_mapController.isCompleted) _mapController.complete(c);
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search area (e.g., DHA Phase 6)',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _searchArea,
                  ),
                ),
                if (_isSearchingLocation)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: Icon(Icons.arrow_forward, color: Theme.of(context).primaryColor),
                    onPressed: () => _searchArea(_searchController.text),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: _carsInRadius.isEmpty ? 32 : 160,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'my_location_btn',
            backgroundColor: Colors.white,
            mini: true,
            onPressed: () async {
              if (_currentPosition != null && _mapController.isCompleted) {
                final controller = await _mapController.future;
                controller.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  14,
                ));
              }
            },
            child: Icon(Icons.my_location, color: Colors.grey.shade800),
          ),
        ),
        if (_carsInRadius.isEmpty)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  )
                ],
              ),
              child: _buildEmptyState(),
            ),
          )
        else
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _carsInRadius.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildCard(i, _carsInRadius[i]),
              ),
            ),
          ),
      ],
    );
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.1),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
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
