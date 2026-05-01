import 'package:cloud_firestore/cloud_firestore.dart';

class DamageClaim {
  final String claimId;
  final String bookingId;
  final String carId;
  final String hostId;
  final String renterId;
  final double hostClaimedAmount;

  /// 'open' | 'admin_reviewing' | 'decided' | 'resolved'
  final String status;

  /// 'host' | 'renter' | 'split' | 'extra'
  final String? adminDecision;

  /// Set by admin. Used for 'host' and 'split' decisions.
  final double? finalDeductionAmount;

  /// True when damage exceeds deposit and renter owes extra.
  final bool requiresExtraPayment;

  /// How much renter owes ABOVE the deposit (only for 'extra' decision).
  final double extraChargeAmount;

  final String? adminNotes;

  final bool hostConfirmed;
  final bool renterConfirmed;
  final DateTime? hostConfirmedAt;
  final DateTime? renterConfirmedAt;

  final DateTime createdAt;
  final DateTime? resolvedAt;

  // Legacy field — kept for backwards compatibility
  final String? resolvedInFavorOf;

  const DamageClaim({
    required this.claimId,
    required this.bookingId,
    required this.carId,
    required this.hostId,
    required this.renterId,
    required this.hostClaimedAmount,
    this.status = 'open',
    this.adminDecision,
    this.finalDeductionAmount,
    this.requiresExtraPayment = false,
    this.extraChargeAmount = 0,
    this.adminNotes,
    this.hostConfirmed = false,
    this.renterConfirmed = false,
    this.hostConfirmedAt,
    this.renterConfirmedAt,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedInFavorOf,
  });

  Map<String, dynamic> toMap() => {
        'claimId': claimId,
        'bookingId': bookingId,
        'carId': carId,
        'hostId': hostId,
        'renterId': renterId,
        'hostClaimedAmount': hostClaimedAmount,
        'status': status,
        'adminDecision': adminDecision,
        'resolvedInFavorOf': resolvedInFavorOf ?? adminDecision,
        'finalDeductionAmount': finalDeductionAmount,
        'requiresExtraPayment': requiresExtraPayment,
        'extraChargeAmount': extraChargeAmount,
        'adminNotes': adminNotes,
        'hostConfirmed': hostConfirmed,
        'renterConfirmed': renterConfirmed,
        'hostConfirmedAt': hostConfirmedAt != null
            ? Timestamp.fromDate(hostConfirmedAt!)
            : null,
        'renterConfirmedAt': renterConfirmedAt != null
            ? Timestamp.fromDate(renterConfirmedAt!)
            : null,
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
        adminDecision: map['adminDecision'] as String?,
        resolvedInFavorOf: map['resolvedInFavorOf'] as String?,
        finalDeductionAmount: map['finalDeductionAmount'] != null
            ? (map['finalDeductionAmount'] as num).toDouble()
            : null,
        requiresExtraPayment: map['requiresExtraPayment'] as bool? ?? false,
        extraChargeAmount: (map['extraChargeAmount'] ?? 0).toDouble(),
        adminNotes: map['adminNotes'] as String?,
        hostConfirmed: map['hostConfirmed'] as bool? ?? false,
        renterConfirmed: map['renterConfirmed'] as bool? ?? false,
        hostConfirmedAt: map['hostConfirmedAt'] != null
            ? (map['hostConfirmedAt'] as Timestamp).toDate()
            : null,
        renterConfirmedAt: map['renterConfirmedAt'] != null
            ? (map['renterConfirmedAt'] as Timestamp).toDate()
            : null,
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
      case 'decided':
        return 'Awaiting Confirmation';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Open';
    }
  }
}
