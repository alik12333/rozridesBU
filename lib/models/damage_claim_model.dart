import 'package:cloud_firestore/cloud_firestore.dart';

class DamageClaim {
  final String claimId;
  final String bookingId;
  final String carId;
  final String hostId;
  final String renterId;
  final String raisedBy;
  final String claimType;
  final String description;
  final double hostClaimedDeduction;
  final double renterAgreedDeduction;
  final String preInspectionRef;
  final String postInspectionRef;
  final String status; // open | admin_reviewing | resolved_for_host | resolved_for_renter | resolved_mutually
  final String? adminNotes;
  final double? mutualAmount;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final DateTime createdAt;

  const DamageClaim({
    required this.claimId,
    required this.bookingId,
    required this.carId,
    required this.hostId,
    required this.renterId,
    required this.raisedBy,
    this.claimType = 'damage_dispute',
    required this.description,
    required this.hostClaimedDeduction,
    this.renterAgreedDeduction = 0,
    required this.preInspectionRef,
    required this.postInspectionRef,
    this.status = 'open',
    this.adminNotes,
    this.mutualAmount,
    this.resolvedAt,
    this.resolvedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'claimId': claimId,
        'bookingId': bookingId,
        'carId': carId,
        'hostId': hostId,
        'renterId': renterId,
        'raisedBy': raisedBy,
        'claimType': claimType,
        'description': description,
        'hostClaimedDeduction': hostClaimedDeduction,
        'renterAgreedDeduction': renterAgreedDeduction,
        'preInspectionRef': preInspectionRef,
        'postInspectionRef': postInspectionRef,
        'status': status,
        'adminNotes': adminNotes,
        'mutualAmount': mutualAmount,
        'resolvedAt':
            resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
        'resolvedBy': resolvedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory DamageClaim.fromMap(Map<String, dynamic> map, String id) =>
      DamageClaim(
        claimId: id,
        bookingId: map['bookingId'] as String? ?? '',
        carId: map['carId'] as String? ?? '',
        hostId: map['hostId'] as String? ?? '',
        renterId: map['renterId'] as String? ?? '',
        raisedBy: map['raisedBy'] as String? ?? '',
        claimType: map['claimType'] as String? ?? 'damage_dispute',
        description: map['description'] as String? ?? '',
        hostClaimedDeduction:
            (map['hostClaimedDeduction'] ?? 0).toDouble(),
        renterAgreedDeduction:
            (map['renterAgreedDeduction'] ?? 0).toDouble(),
        preInspectionRef: map['preInspectionRef'] as String? ?? '',
        postInspectionRef: map['postInspectionRef'] as String? ?? '',
        status: map['status'] as String? ?? 'open',
        adminNotes: map['adminNotes'] as String?,
        mutualAmount: map['mutualAmount'] != null
            ? (map['mutualAmount']).toDouble()
            : null,
        resolvedAt: map['resolvedAt'] != null
            ? (map['resolvedAt'] as Timestamp).toDate()
            : null,
        resolvedBy: map['resolvedBy'] as String?,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  String get statusLabel {
    switch (status) {
      case 'admin_reviewing':
        return 'Under Review';
      case 'resolved_for_host':
        return 'Resolved — Host';
      case 'resolved_for_renter':
        return 'Resolved — Renter';
      case 'resolved_mutually':
        return 'Resolved Mutually';
      default:
        return 'Open';
    }
  }
}
