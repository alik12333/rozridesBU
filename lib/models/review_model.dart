import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final String? carId; // null for host_to_renter
  final String type; // renter_to_host | host_to_renter
  final double overallRating; // 1.0–5.0
  final String comment;
  final bool isPublic;
  final bool flagged;
  final String reviewerName;
  final String? reviewerPhoto;
  final DateTime createdAt;

  const ReviewModel({
    required this.reviewId,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    this.carId,
    required this.type,
    required this.overallRating,
    required this.comment,
    this.isPublic = false,
    this.flagged = false,
    required this.reviewerName,
    this.reviewerPhoto,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'reviewId': reviewId,
        'bookingId': bookingId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'carId': carId,
        'type': type,
        'overallRating': overallRating,
        'comment': comment,
        'isPublic': isPublic,
        'flagged': flagged,
        'reviewerName': reviewerName,
        'reviewerPhoto': reviewerPhoto,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) =>
      ReviewModel(
        reviewId: id,
        bookingId: map['bookingId'] as String? ?? '',
        reviewerId: map['reviewerId'] as String? ?? '',
        revieweeId: map['revieweeId'] as String? ?? '',
        carId: map['carId'] as String?,
        type: map['type'] as String? ?? 'renter_to_host',
        overallRating: (map['overallRating'] ?? 0).toDouble(),
        comment: map['comment'] as String? ?? '',
        isPublic: map['isPublic'] as bool? ?? false,
        flagged: map['flagged'] as bool? ?? false,
        reviewerName: map['reviewerName'] as String? ?? 'Anonymous',
        reviewerPhoto: map['reviewerPhoto'] as String?,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
