import 'package:cloud_firestore/cloud_firestore.dart';
import 'inspection_model.dart';

// ─── ComparisonResult ─────────────────────────────────────────────────────────

class ComparisonResult {
  final bool hasNewDamage;
  final List<String> newDamageAreas;
  final Map<String, String> newDamageNotes; // area key → description
  final bool hasFuelIssue;
  final int kmDriven;

  const ComparisonResult({
    required this.hasNewDamage,
    required this.newDamageAreas,
    required this.newDamageNotes,
    required this.hasFuelIssue,
    required this.kmDriven,
  });

  bool get hasAnyIssue => hasNewDamage || hasFuelIssue;
}

/// Returns a [ComparisonResult] by comparing a pre-trip and post-trip inspection.
ComparisonResult compareInspections(
  PreTripInspection pre,
  PostTripInspection post,
) {
  final newDamageAreas = <String>[];
  final newDamageNotes = <String, String>{};

  for (final area in InspectionAreas.all) {
    final preItem = pre.items[area];
    final postItem = post.items[area];
    if (preItem == null || postItem == null) continue;
    // New damage = no pre-existing damage but damage found post-trip
    if (!preItem.hasDamage && postItem.hasDamage) {
      newDamageAreas.add(area);
      newDamageNotes[area] = postItem.notes;
    }
  }

  final fuelOrder = PreTripInspection.fuelLevels; // ['Full','3/4','1/2','1/4','Empty']
  final preIdx = fuelOrder.indexOf(pre.fuelLevel);
  final postIdx = fuelOrder.indexOf(post.fuelLevel);
  final hasFuelIssue = postIdx > preIdx; // higher index = less fuel

  final kmDriven = (post.odometerReading - pre.odometerReading).clamp(0, 999999);

  return ComparisonResult(
    hasNewDamage: newDamageAreas.isNotEmpty,
    newDamageAreas: newDamageAreas,
    newDamageNotes: newDamageNotes,
    hasFuelIssue: hasFuelIssue,
    kmDriven: kmDriven,
  );
}

// ─── CashSettlement ───────────────────────────────────────────────────────────

class CashSettlement {
  final double rentPaid;
  final double depositRefunded;
  final double damageDeduction;

  const CashSettlement({
    required this.rentPaid,
    required this.depositRefunded,
    required this.damageDeduction,
  });
}

// ─── PostTripInspection ───────────────────────────────────────────────────────

class PostTripInspection {
  final String bookingId;
  final DateTime returnConfirmedAt;
  final String fuelLevel;
  final int odometerReading;
  final bool newDamageFound;
  final List<String> newDamageAreas;
  final bool fuelLevelChanged;
  final int kmDriven;
  final bool hostSigned;
  final bool renterSigned;
  final DateTime? completedAt;
  final Map<String, InspectionItem> items;

  static const fuelLevels = PreTripInspection.fuelLevels;

  const PostTripInspection({
    required this.bookingId,
    required this.returnConfirmedAt,
    this.fuelLevel = 'Full',
    this.odometerReading = 0,
    this.newDamageFound = false,
    this.newDamageAreas = const [],
    this.fuelLevelChanged = false,
    this.kmDriven = 0,
    this.hostSigned = false,
    this.renterSigned = false,
    this.completedAt,
    required this.items,
  });

  factory PostTripInspection.blank(String bookingId) => PostTripInspection(
        bookingId: bookingId,
        returnConfirmedAt: DateTime.now(),
        items: {
          for (final a in InspectionAreas.all) a: InspectionItem.empty(a),
        },
      );

  PostTripInspection copyWith({
    String? bookingId,
    DateTime? returnConfirmedAt,
    String? fuelLevel,
    int? odometerReading,
    bool? newDamageFound,
    List<String>? newDamageAreas,
    bool? fuelLevelChanged,
    int? kmDriven,
    bool? hostSigned,
    bool? renterSigned,
    DateTime? completedAt,
    Map<String, InspectionItem>? items,
  }) =>
      PostTripInspection(
        bookingId: bookingId ?? this.bookingId,
        returnConfirmedAt: returnConfirmedAt ?? this.returnConfirmedAt,
        fuelLevel: fuelLevel ?? this.fuelLevel,
        odometerReading: odometerReading ?? this.odometerReading,
        newDamageFound: newDamageFound ?? this.newDamageFound,
        newDamageAreas: newDamageAreas ?? this.newDamageAreas,
        fuelLevelChanged: fuelLevelChanged ?? this.fuelLevelChanged,
        kmDriven: kmDriven ?? this.kmDriven,
        hostSigned: hostSigned ?? this.hostSigned,
        renterSigned: renterSigned ?? this.renterSigned,
        completedAt: completedAt ?? this.completedAt,
        items: items ?? this.items,
      );

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'returnConfirmedAt': Timestamp.fromDate(returnConfirmedAt),
        'fuelLevel': fuelLevel,
        'odometerReading': odometerReading,
        'newDamageFound': newDamageFound,
        'newDamageAreas': newDamageAreas,
        'fuelLevelChanged': fuelLevelChanged,
        'kmDriven': kmDriven,
        'hostSigned': hostSigned,
        'renterSigned': renterSigned,
        'completedAt': completedAt != null
            ? Timestamp.fromDate(completedAt!)
            : FieldValue.serverTimestamp(),
        'items': items.map((k, v) => MapEntry(k, v.toMap())),
      };

  factory PostTripInspection.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as Map<String, dynamic>? ?? {};
    return PostTripInspection(
      bookingId: map['bookingId'] as String? ?? '',
      returnConfirmedAt: map['returnConfirmedAt'] != null
          ? (map['returnConfirmedAt'] as Timestamp).toDate()
          : DateTime.now(),
      fuelLevel: map['fuelLevel'] as String? ?? 'Full',
      odometerReading: (map['odometerReading'] ?? 0) as int,
      newDamageFound: map['newDamageFound'] as bool? ?? false,
      newDamageAreas: List<String>.from(map['newDamageAreas'] ?? []),
      fuelLevelChanged: map['fuelLevelChanged'] as bool? ?? false,
      kmDriven: (map['kmDriven'] ?? 0) as int,
      hostSigned: map['hostSigned'] as bool? ?? false,
      renterSigned: map['renterSigned'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      items: rawItems.map(
          (k, v) => MapEntry(k, InspectionItem.fromMap(v as Map<String, dynamic>))),
    );
  }
}
