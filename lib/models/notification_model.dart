import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final bool isUnread;
  final String type; // 'info', 'success', 'warning', 'error'

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.type,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      time: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isUnread: data['isUnread'] ?? false,
      type: data['type'] ?? 'info',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(time),
      'isUnread': isUnread,
      'type': type,
    };
  }
}
