import 'package:cloud_firestore/cloud_firestore.dart';

class DamageClaim {
  final String claimId;
  final String bookingId;
  final String carId;
  final String hostId;
  final String renterId;
  final double hostClaimedAmount;
  final String status; // 'open' | 'admin_reviewing' | 'resolved'
  final String? resolvedInFavorOf; // 'host' | 'renter' | 'split'
  final double? finalDeductionAmount;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DamageClaim({
    required this.claimId,
    required this.bookingId,
    required this.carId,
    required this.hostId,
    required this.renterId,
    required this.hostClaimedAmount,
    this.status = 'open',
    this.resolvedInFavorOf,
    this.finalDeductionAmount,
    this.adminNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
        'claimId': claimId,
        'bookingId': bookingId,
        'carId': carId,
        'hostId': hostId,
        'renterId': renterId,
        'hostClaimedAmount': hostClaimedAmount,
        'status': status,
        'resolvedInFavorOf': resolvedInFavorOf,
        'finalDeductionAmount': finalDeductionAmount,
        'adminNotes': adminNotes,
        'createdAt': Timestamp.fromDate(createdAt),
        'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      };

  factory DamageClaim.fromMap(Map<String, dynamic> map, String id) =>
      DamageClaim(
        claimId: id,
        bookingId: map['bookingId'] as String? ?? '',
        carId: map['carId'] as String? ?? '',
        hostId: map['hostId'] as String? ?? '',
        renterId: map['renterId'] as String? ?? '',
        hostClaimedAmount: (map['hostClaimedAmount'] ?? 0).toDouble(),
        status: map['status'] as String? ?? 'open',
        resolvedInFavorOf: map['resolvedInFavorOf'] as String?,
        finalDeductionAmount: map['finalDeductionAmount'] != null
            ? (map['finalDeductionAmount'] as num).toDouble()
            : null,
        adminNotes: map['adminNotes'] as String?,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        resolvedAt: map['resolvedAt'] != null
            ? (map['resolvedAt'] as Timestamp).toDate()
            : null,
      );

  String get statusLabel {
    switch (status) {
      case 'admin_reviewing':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Open';
    }
  }
}
