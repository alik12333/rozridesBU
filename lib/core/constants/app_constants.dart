class AppConstants {
  // App Info
  static const String appName = 'RozRides';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String listingsCollection = 'listings';
  static const String bookingsCollection = 'bookings';
  static const String chatsCollection = 'chats';

  // Storage Paths
  static const String userProfilesPath = 'users';
  static const String cnicDocumentsPath = 'users/{userId}/cnic';
  static const String listingImagesPath = 'listings/{listingId}/images';
  static const String listingDocumentsPath = 'listings/{listingId}/documents';

  // Pakistan Phone Code
  static const String pakistanPhoneCode = '+92';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxImageSizeMB = 5;
  static const int maxListingImages = 10;
}