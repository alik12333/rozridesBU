import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CarLocationMapScreen extends StatelessWidget {
  final GeoPoint location;
  final String carName;

  const CarLocationMapScreen({
    super.key,
    required this.location,
    required this.carName,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng carLatLng = LatLng(location.latitude, location.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text('Location: $carName'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: carLatLng,
          zoom: 14.0, // Zoomed out enough to see the 500m radius
        ),
        circles: {
          Circle(
            circleId: const CircleId('car_location_radius'),
            center: carLatLng,
            radius: 500, // 500 meters
            fillColor: const Color(0xFF7C3AED).withValues(alpha: 0.2), // App primary color with transparency
            strokeColor: const Color(0xFF7C3AED),
            strokeWidth: 2,
          ),
        },
        markers: const {}, // Ensure no marker is placed
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
