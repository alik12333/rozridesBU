import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;

  // Vehicle Details
  final String carName;
  final String? carNumber;
  final String brand;
  final String model;
  final int year;
  final double pricePerDay;
  final String engineSize;
  final int mileage; // in kilometers
  final String fuelType; // Petrol, Diesel, Hybrid, Electric
  final String transmission; // Manual, Automatic
  final String description;

  // Service Options
  final bool withDriver;
  final bool hasInsurance;

  // Images
  final List<String> images;

  // Status
  final String status; // draft, pending, approved, rejected, inactive
  final DateTime createdAt;
  final DateTime updatedAt;

  // Location
  final String? city;
  final String? area;
  final GeoPoint? location;
  final String? geohash;
  final String? locationLabel;
  final bool isPickupFlexible;

  // Bookings
  final List<Map<String, dynamic>> bookedDateRanges;

  // Ratings
  final double averageRating;
  final int totalReviews;
  final Map<String, int> ratingBreakdown; // {'1': N, '2': N, ...}

  ListingModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.carName,
    this.carNumber,
    required this.brand,
    required this.model,
    required this.year,
    required this.pricePerDay,
    required this.engineSize,
    required this.mileage,
    required this.fuelType,
    required this.transmission,
    required this.description,
    required this.withDriver,
    required this.hasInsurance,
    required this.images,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.city,
    this.area,
    this.location,
    this.geohash,
    this.locationLabel,
    this.isPickupFlexible = false,
    this.bookedDateRanges = const [],
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.ratingBreakdown = const {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
  });

  factory ListingModel.fromMap(Map<String, dynamic> map, String id) {
    return ListingModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerPhone: map['ownerPhone'] ?? '',
      carName: map['carName'] ?? '',
      carNumber: map['carNumber'],
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 2020,
      pricePerDay: (map['pricePerDay'] ?? 0).toDouble(),
      engineSize: map['engineSize'] ?? '',
      mileage: map['mileage'] ?? 0,
      fuelType: map['fuelType'] ?? 'Petrol',
      transmission: map['transmission'] ?? 'Manual',
      description: map['description'] ?? '',
      withDriver: map['withDriver'] ?? false,
      hasInsurance: map['hasInsurance'] ?? false,
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'draft',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      city: map['city'],
      area: map['area'],
      location: map['location'] as GeoPoint?,
      geohash: map['geohash'],
      locationLabel: map['locationLabel'],
      isPickupFlexible: map['isPickupFlexible'] ?? false,
      bookedDateRanges: map['bookedDateRanges'] != null
          ? List<Map<String, dynamic>>.from(map['bookedDateRanges'])
          : [],
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: (map['totalReviews'] ?? 0) as int,
      ratingBreakdown: map['ratingBreakdown'] != null
          ? Map<String, int>.from(
              (map['ratingBreakdown'] as Map).map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'carName': carName,
      'carNumber': carNumber,
      'brand': brand,
      'model': model,
      'year': year,
      'pricePerDay': pricePerDay,
      'engineSize': engineSize,
      'mileage': mileage,
      'fuelType': fuelType,
      'transmission': transmission,
      'description': description,
      'withDriver': withDriver,
      'hasInsurance': hasInsurance,
      'images': images,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'city': city,
      'area': area,
      'location': location,
      'geohash': geohash,
      'locationLabel': locationLabel,
      'isPickupFlexible': isPickupFlexible,
      'bookedDateRanges': bookedDateRanges,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingBreakdown': ratingBreakdown,
    };
  }
}