import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/listing_model.dart';

class ListingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create new listing
  Future<String> createListing({
    required String ownerId,
    required String ownerName,
    required String ownerPhone,
    required String carName,
    required String carNumber,
    required String brand,
    required String model,
    required int year,
    required double pricePerDay,
    required String engineSize,
    required int mileage,
    required String fuelType,
    required String transmission,
    required String description,
    required bool withDriver,
    required bool hasInsurance,
    required List<File> images,
    String? city,
    String? area,
    GeoPoint? location,
    String? geohash,
    String? locationLabel,
  }) async {
    try {
      // Create document reference to get ID
      final docRef = _firestore.collection('listings').doc();
      final listingId = docRef.id;

      // Upload ALL images
      List<String> imageUrls = [];
      for (int i = 0; i < images.length; i++) {
        final url = await _uploadImage(listingId, images[i], i);
        imageUrls.add(url);
      }

      // Build geo sub-document in the format geoflutterfire_plus expects:
      // { geo: { geopoint: GeoPoint, geohash: "string" } }
      Map<String, dynamic>? geoData;
      if (location != null) {
        final geoPoint = GeoFirePoint(location);
        geoData = {
          'geopoint': location,
          'geohash': geoPoint.geohash,
        };
      }

      // Create listing data
      final listingData = {
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
        'images': imageUrls,
        'status': 'pending', // Pending approval by default
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'city': city,
        'area': area,
        // Flat fields for backward compat display
        'location': location,
        'geohash': geohash,
        'locationLabel': locationLabel,
        // Nested geo field — geoflutterfire_plus queries against this
        if (geoData != null) 'geo': geoData,
      };

      await docRef.set(listingData);

      // Add notification for user
      await _firestore
          .collection('users')
          .doc(ownerId)
          .collection('notifications')
          .add({
        'title': 'Listing Verification In Process',
        'message': 'Your listing for $year $brand $model is under review. We\'ll notify you once it\'s approved.',
        'type': 'listing_pending',
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return listingId;
    } catch (e) {
      throw Exception('Failed to create listing: $e');
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImage(String listingId, File image, int index) async {
    final ref = _storage.ref().child('listings/$listingId/image_$index.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

// Get user's listings
  Future<List<ListingModel>> getUserListings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('listings')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final listings = querySnapshot.docs
          .map((doc) {
        return ListingModel.fromMap(doc.data(), doc.id);
      })
          .toList();

      return listings;
    } catch (e) {
      return [];
    }
  }

// Get all approved listings
  Future<List<ListingModel>> getAllListings() async {
    try {
      final querySnapshot = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'approved')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final listings = querySnapshot.docs
          .map((doc) {
        return ListingModel.fromMap(doc.data(), doc.id);
      })
          .toList();

      return listings;
    } catch (e) {
      return [];
    }
  }

  // Delete listing
  Future<void> deleteListing(String listingId) async {
    try {
      // Delete images from storage
      final listRef = _storage.ref().child('listings/$listingId');
      final listResult = await listRef.listAll();

      for (var item in listResult.items) {
        await item.delete();
      }

      // Deactivate associated conversations
      final convs = await _firestore
          .collection('conversations')
          .where('carId', isEqualTo: listingId)
          .get();
      
      if (convs.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in convs.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
      }

      // Delete document
      await _firestore.collection('listings').doc(listingId).delete();
    } catch (e) {
      throw Exception('Failed to delete listing: $e');
    }
  }

  // Update listing status
  Future<void> updateListingStatus(String listingId, String status) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If listing is marked inactive, deactivate associated conversations
    if (status == 'inactive') {
      final convs = await _firestore
          .collection('conversations')
          .where('carId', isEqualTo: listingId)
          .get();
      
      if (convs.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in convs.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
      }
    }
  }

  /// Migrate an existing listing that has flat location/geohash fields
  /// but is missing the nested 'geo' field required by geoflutterfire_plus.
  Future<void> migrateListingGeoField(String listingId) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final GeoPoint? location = data['location'] as GeoPoint?;
    if (location == null) return;
    if (data['geo'] != null) return; // Already migrated

    final geoPoint = GeoFirePoint(location);
    await _firestore.collection('listings').doc(listingId).update({
      'geo': {
        'geopoint': location,
        'geohash': geoPoint.geohash,
      },
      'geohash': geoPoint.geohash, // Keep flat field in sync too
    });
  }
}