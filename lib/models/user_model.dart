
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? profilePhoto;
  final CNIC? cnic;
  final Location? location;
  final Roles? roles;
  final double? renterRating;
  final int? renterReviewCount;
  final double? hostRating;
  final int? hostReviewCount;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profilePhoto,
    this.cnic,
    this.location,
    this.roles,
    this.renterRating,
    this.renterReviewCount,
    this.hostRating,
    this.hostReviewCount,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profilePhoto: map['profilePhoto'],
      cnic: map['cnic'] != null ? CNIC.fromMap(map['cnic']) : null,
      location: map['location'] != null ? Location.fromMap(map['location']) : null,
      roles: map['roles'] != null ? Roles.fromMap(map['roles']) : Roles(isOwner: false),
      renterRating: map['renterRating'] != null ? (map['renterRating']).toDouble() : null,
      renterReviewCount: map['renterReviewCount'] as int?,
      hostRating: map['hostRating'] != null ? (map['hostRating']).toDouble() : null,
      hostReviewCount: map['hostReviewCount'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePhoto': profilePhoto,
      'cnic': cnic?.toMap(),
      'location': location?.toMap(),
      'roles': roles?.toMap(),
      'renterRating': renterRating,
      'renterReviewCount': renterReviewCount,
      'hostRating': hostRating,
      'hostReviewCount': hostReviewCount,
    };
  }
}

class Roles {
  final bool isOwner;
  final bool isAdmin; // NEW

  Roles({this.isOwner = false, this.isAdmin = false}); // NEW

  factory Roles.fromMap(Map<String, dynamic> map) {
    return Roles(
      isOwner: map['isOwner'] ?? false,
      isAdmin: map['isAdmin'] ?? false, // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOwner': isOwner,
      'isAdmin': isAdmin, // NEW
    };
  }
}

class CNIC {
  final String? number;
  final String? frontImage;
  final String? backImage;
  final String verificationStatus;

  CNIC({
    this.number,
    this.frontImage,
    this.backImage,
    this.verificationStatus = 'pending',
  });

  factory CNIC.fromMap(Map<String, dynamic> map) {
    return CNIC(
      number: map['number'],
      frontImage: map['frontImage'],
      backImage: map['backImage'],
      verificationStatus: map['verificationStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'frontImage': frontImage,
      'backImage': backImage,
      'verificationStatus': verificationStatus,
    };
  }
}

class Location {
  final String? city;
  final String? area;

  Location({this.city, this.area});

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      city: map['city'],
      area: map['area'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'area': area,
    };
  }
}
