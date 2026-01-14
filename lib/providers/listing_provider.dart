import 'dart:io';
import 'package:flutter/material.dart';
import '../models/listing_model.dart';
import '../services/listing_service.dart';

enum ListingStatus { idle, loading, error, success }

class ListingProvider extends ChangeNotifier {
  final ListingService _listingService = ListingService();

  List<ListingModel> _myListings = [];
  List<ListingModel> _allListings = [];
  ListingStatus status = ListingStatus.idle;
  String? errorMessage;

  List<ListingModel> get myListings => _myListings;
  List<ListingModel> get allListings => _allListings;

  // Create new listing
  Future<bool> createListing({
    required String ownerId,
    required String ownerName,
    required String ownerPhone,
    required String carName,
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
  }) async {
    try {
      status = ListingStatus.loading;
      errorMessage = null;
      notifyListeners();

      await _listingService.createListing(
        ownerId: ownerId,
        ownerName: ownerName,
        ownerPhone: ownerPhone,
        carName: carName,
        brand: brand,
        model: model,
        year: year,
        pricePerDay: pricePerDay,
        engineSize: engineSize,
        mileage: mileage,
        fuelType: fuelType,
        transmission: transmission,
        description: description,
        withDriver: withDriver,
        hasInsurance: hasInsurance,
        images: images,
        city: city,
        area: area,
      );

      status = ListingStatus.success;
      notifyListeners();

      // Refresh listings
      await loadMyListings(ownerId);
      await loadAllListings();

      return true;
    } catch (e) {
      errorMessage = e.toString();
      status = ListingStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Load user's listings
  Future<void> loadMyListings(String userId) async {
    try {
      status = ListingStatus.loading;
      notifyListeners();

      _myListings = await _listingService.getUserListings(userId);

      status = ListingStatus.idle;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      status = ListingStatus.error;
      notifyListeners();
    }
  }

  // Load all listings
  Future<void> loadAllListings() async {
    try {
      status = ListingStatus.loading;
      notifyListeners();

      _allListings = await _listingService.getAllListings();

      status = ListingStatus.idle;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      status = ListingStatus.error;
      notifyListeners();
    }
  }

  // Delete listing
  Future<bool> deleteListing(String listingId, String userId) async {
    try {
      status = ListingStatus.loading;
      notifyListeners();

      await _listingService.deleteListing(listingId);

      status = ListingStatus.success;
      notifyListeners();

      // Refresh listings
      await loadMyListings(userId);

      return true;
    } catch (e) {
      errorMessage = e.toString();
      status = ListingStatus.error;
      notifyListeners();
      return false;
    }
  }
}