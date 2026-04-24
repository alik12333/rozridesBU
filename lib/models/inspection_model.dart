import 'package:cloud_firestore/cloud_firestore.dart';

// ─── InspectionItem ───────────────────────────────────────────────────────────

class InspectionItem {
  final String area;
  final bool hasDamage;
  final String notes;
  final List<String> photoUrls;

  const InspectionItem({
    required this.area,
    this.hasDamage = false,
    this.notes = '',
    this.photoUrls = const [],
  });

  InspectionItem copyWith({
    String? area,
    bool? hasDamage,
    String? notes,
    List<String>? photoUrls,
  }) =>
      InspectionItem(
        area: area ?? this.area,
        hasDamage: hasDamage ?? this.hasDamage,
        notes: notes ?? this.notes,
        photoUrls: photoUrls ?? this.photoUrls,
      );

  Map<String, dynamic> toMap() => {
        'area': area,
        'hasDamage': hasDamage,
        'notes': notes,
        'photoUrls': photoUrls,
      };

  factory InspectionItem.fromMap(Map<String, dynamic> map) => InspectionItem(
        area: map['area'] as String? ?? '',
        hasDamage: map['hasDamage'] as bool? ?? false,
        notes: map['notes'] as String? ?? '',
        photoUrls: List<String>.from(map['photoUrls'] ?? []),
      );

  static InspectionItem empty(String area) =>
      InspectionItem(area: area, photoUrls: []);
}

// ─── Inspection area keys ─────────────────────────────────────────────────────

class InspectionAreas {
  static const front = 'front';
  static const rear = 'rear';
  static const leftSide = 'leftSide';
  static const rightSide = 'rightSide';
  static const interior = 'interior';

  static const all = [front, rear, leftSide, rightSide, interior];

  static String label(String key) {
    switch (key) {
      case front: return 'Exterior Front';
      case rear: return 'Exterior Rear';
      case leftSide: return 'Exterior Left Side';
      case rightSide: return 'Exterior Right Side';
      case interior: return 'Interior';
      default: return key;
    }
  }
}

// ─── PreTripInspection ────────────────────────────────────────────────────────

class PreTripInspection {
  final String bookingId;
  final double depositCollected;
  final String fuelLevel;
  final int odometerReading;
  final bool hostSigned;
  final bool renterSigned;
  final DateTime? completedAt;
  final Map<String, InspectionItem> items;

  static const fuelLevels = ['Full', '3/4', '1/2', '1/4', 'Empty'];

  const PreTripInspection({
    required this.bookingId,
    this.depositCollected = 0,
    this.fuelLevel = 'Full',
    this.odometerReading = 0,
    this.hostSigned = false,
    this.renterSigned = false,
    this.completedAt,
    required this.items,
  });

  factory PreTripInspection.blank(String bookingId) => PreTripInspection(
        bookingId: bookingId,
        items: {
          for (final a in InspectionAreas.all) a: InspectionItem.empty(a),
        },
      );

  PreTripInspection copyWith({
    String? bookingId,
    double? depositCollected,
    String? fuelLevel,
    int? odometerReading,
    bool? hostSigned,
    bool? renterSigned,
    DateTime? completedAt,
    Map<String, InspectionItem>? items,
  }) =>
      PreTripInspection(
        bookingId: bookingId ?? this.bookingId,
        depositCollected: depositCollected ?? this.depositCollected,
        fuelLevel: fuelLevel ?? this.fuelLevel,
        odometerReading: odometerReading ?? this.odometerReading,
        hostSigned: hostSigned ?? this.hostSigned,
        renterSigned: renterSigned ?? this.renterSigned,
        completedAt: completedAt ?? this.completedAt,
        items: items ?? this.items,
      );

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'depositCollected': depositCollected,
        'fuelLevel': fuelLevel,
        'odometerReading': odometerReading,
        'hostSigned': hostSigned,
        'renterSigned': renterSigned,
        'completedAt': completedAt != null
            ? Timestamp.fromDate(completedAt!)
            : FieldValue.serverTimestamp(),
        'items': items.map((k, v) => MapEntry(k, v.toMap())),
      };

  factory PreTripInspection.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as Map<String, dynamic>? ?? {};
    return PreTripInspection(
      bookingId: map['bookingId'] as String? ?? '',
      depositCollected: (map['depositCollected'] ?? 0).toDouble(),
      fuelLevel: map['fuelLevel'] as String? ?? 'Full',
      odometerReading: (map['odometerReading'] ?? 0) as int,
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
