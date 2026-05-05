import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String carId;
  final String hostId;
  final String renterId;

  // Denormalized car fields
  final String carName;
  final String carPhoto;
  final String carLocation;
  final GeoPoint? location;

  // Trip dates
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;

  // Pricing
  final double pricePerDay;
  final double totalRent;
  final double securityDeposit;

  // Cash payment tracking map
  final Map<String, dynamic> cashPayments;

  // Denormalized renter display name (so host can show it without extra fetch)
  final String renterName;

  // Status
  /// One of: pending, confirmed, active, completed, cancelled, rejected, expired
  final String status;

  final String messageToHost;
  final String cancellationPolicy;
  final String? cancellationReason;
  final String? rejectionReason;

  // Review tracking
  final Map<String, dynamic> reviewStatus;

  // Trip lifecycle timestamps
  final DateTime? tripStartedAt;
  final DateTime? tripEndedAt;

  // Two-stage handover flags
  /// True when host has completed pre-trip inspection; renter must now press "Start Trip".
  final bool preHandoverCompleted;
  /// True when host has submitted the post-trip return; renter must now confirm settlement.
  final bool postHandoverCompleted;
  /// The settlement proposed by the host at return (damageDeduction, depositRefund, rentAmount).
  final Map<String, dynamic>? proposedSettlement;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Auto-expiry time = createdAt + 24 hours
  final DateTime expiresAt;

  BookingModel({
    required this.id,
    required this.carId,
    required this.hostId,
    required this.renterId,
    required this.carName,
    required this.carPhoto,
    required this.carLocation,
    this.location,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.pricePerDay,
    required this.totalRent,
    required this.securityDeposit,
    required this.cashPayments,
    required this.renterName,
    required this.status,
    required this.messageToHost,
    required this.cancellationPolicy,
    this.cancellationReason,
    this.rejectionReason,
    required this.reviewStatus,
    this.tripStartedAt,
    this.tripEndedAt,
    this.preHandoverCompleted = false,
    this.postHandoverCompleted = false,
    this.proposedSettlement,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  /// Whether this pending booking has passed its 24-hour response window.
  bool get isExpired =>
      status == 'pending' && DateTime.now().isAfter(expiresAt);

  /// The dynamically calculated end date based on when the trip actually started.
  /// If the trip hasn't started, it falls back to the scheduled endDate.
  DateTime get actualEndDate {
    if (tripStartedAt != null && totalDays > 0) {
      return tripStartedAt!.add(Duration(days: totalDays));
    }
    return endDate;
  }

  /// Reserved for future driver-assignment logic.
  bool get requiresDriverAssignment => false;

  /// Legacy alias kept so older screens compiled before the rename still work.
  double get totalAmount => totalRent;

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    final createdAt =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final defaultCashPayments = {
      'depositPaidToHost': false,
      'depositPaidAmount': 0,
      'depositPaidAt': null,
      'rentPaidToHost': false,
      'rentPaidAmount': 0,
      'rentPaidAt': null,
      'depositRefundedToRenter': false,
      'depositRefundedAmount': 0,
      'depositRefundedAt': null,
      'damageDeduction': 0,
    };

    final defaultReviewStatus = {
      'renterSubmitted': false,
      'hostSubmitted': false,
    };

    try {
      return BookingModel(
        id: id,
        carId: map['carId'] ?? '',
        hostId: map['hostId'] ?? '',
        renterId: map['renterId'] ?? '',
        carName: map['carName'] ?? '',
        carPhoto: map['carPhoto'] ?? '',
        carLocation: map['carLocation'] ?? '',
        location: map['location'] as GeoPoint?,
        startDate: (map['startDate'] is Timestamp) ? (map['startDate'] as Timestamp).toDate() : DateTime.now(),
        endDate: (map['endDate'] is Timestamp) ? (map['endDate'] as Timestamp).toDate() : DateTime.now(),
        totalDays: map['totalDays'] ?? 0,
        pricePerDay: (map['pricePerDay'] ?? 0).toDouble(),
        totalRent: (map['totalRent'] ?? map['totalAmount'] ?? 0).toDouble(),
        securityDeposit: (map['securityDeposit'] ?? 0).toDouble(),
        cashPayments: Map<String, dynamic>.from(
            map['cashPayments'] as Map? ?? defaultCashPayments),
        renterName: map['renterName'] ?? '',
        status: map['status'] ?? 'pending',
        messageToHost: map['messageToHost'] ?? '',
        cancellationPolicy: map['cancellationPolicy'] ?? 'flexible',
        cancellationReason: map['cancellationReason'],
        rejectionReason: map['rejectionReason'] ?? map['declineReason'],
        reviewStatus: Map<String, dynamic>.from(
            map['reviewStatus'] as Map? ?? defaultReviewStatus),
        tripStartedAt: (map['tripStartedAt'] is Timestamp) ? (map['tripStartedAt'] as Timestamp).toDate() : null,
        tripEndedAt: (map['tripEndedAt'] is Timestamp) ? (map['tripEndedAt'] as Timestamp).toDate() : null,
        preHandoverCompleted: map['preHandoverCompleted'] as bool? ?? false,
        postHandoverCompleted: map['postHandoverCompleted'] as bool? ?? false,
        proposedSettlement: map['proposedSettlement'] != null
            ? Map<String, dynamic>.from(map['proposedSettlement'] as Map)
            : null,
        createdAt: createdAt,
        updatedAt: (map['updatedAt'] is Timestamp)
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        expiresAt: (map['expiresAt'] is Timestamp)
            ? (map['expiresAt'] as Timestamp).toDate()
            : createdAt.add(const Duration(hours: 24)),
      );
    } catch (e) {
      // Log error internally or rethrow without printing to console in production
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': id,
      'carId': carId,
      'hostId': hostId,
      'renterId': renterId,
      'carName': carName,
      'carPhoto': carPhoto,
      'carLocation': carLocation,
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'pricePerDay': pricePerDay,
      'totalRent': totalRent,
      'securityDeposit': securityDeposit,
      'cashPayments': cashPayments,
      'renterName': renterName,
      'status': status,
      'messageToHost': messageToHost,
      'cancellationPolicy': cancellationPolicy,
      'cancellationReason': cancellationReason,
      'rejectionReason': rejectionReason,
      'reviewStatus': reviewStatus,
      'tripStartedAt':
          tripStartedAt != null ? Timestamp.fromDate(tripStartedAt!) : null,
      'tripEndedAt':
          tripEndedAt != null ? Timestamp.fromDate(tripEndedAt!) : null,
      'preHandoverCompleted': preHandoverCompleted,
      'postHandoverCompleted': postHandoverCompleted,
      'proposedSettlement': proposedSettlement,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  BookingModel copyWith({
    String? status,
    String? renterName,
    String? cancellationReason,
    String? rejectionReason,
    DateTime? updatedAt,
    DateTime? tripStartedAt,
    DateTime? tripEndedAt,
    GeoPoint? location,
    Map<String, dynamic>? cashPayments,
    Map<String, dynamic>? reviewStatus,
    bool? preHandoverCompleted,
    bool? postHandoverCompleted,
    Map<String, dynamic>? proposedSettlement,
  }) {
    return BookingModel(
      id: id,
      carId: carId,
      hostId: hostId,
      renterId: renterId,
      carName: carName,
      carPhoto: carPhoto,
      carLocation: carLocation,
      location: location ?? this.location,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      pricePerDay: pricePerDay,
      totalRent: totalRent,
      securityDeposit: securityDeposit,
      cashPayments: cashPayments ?? this.cashPayments,
      renterName: renterName ?? this.renterName,
      status: status ?? this.status,
      messageToHost: messageToHost,
      cancellationPolicy: cancellationPolicy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      tripStartedAt: tripStartedAt ?? this.tripStartedAt,
      tripEndedAt: tripEndedAt ?? this.tripEndedAt,
      preHandoverCompleted: preHandoverCompleted ?? this.preHandoverCompleted,
      postHandoverCompleted: postHandoverCompleted ?? this.postHandoverCompleted,
      proposedSettlement: proposedSettlement ?? this.proposedSettlement,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt,
    );
  }
}
