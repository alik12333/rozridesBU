import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String conversationId;
  final String? bookingId; // null for pre-booking chats
  final String carId;
  final String hostId;
  final String renterId;
  final String carName;
  final String hostName;
  final String renterName;
  final String? hostPhoto;
  final String? renterPhoto;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int hostUnreadCount;
  final int renterUnreadCount;
  final bool isActive;
  final String? bookingStatus; // mirrors booking status for UI
  final DateTime createdAt;

  const ConversationModel({
    required this.conversationId,
    this.bookingId,
    required this.carId,
    required this.hostId,
    required this.renterId,
    required this.carName,
    required this.hostName,
    required this.renterName,
    this.hostPhoto,
    this.renterPhoto,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.hostUnreadCount = 0,
    this.renterUnreadCount = 0,
    this.isActive = true,
    this.bookingStatus,
    required this.createdAt,
  });

  int unreadCountFor(String userId) {
    if (userId == hostId) return hostUnreadCount;
    if (userId == renterId) return renterUnreadCount;
    return 0;
  }

  String otherPartyNameFor(String userId) {
    if (userId == hostId) return renterName;
    return hostName;
  }

  String? otherPartyPhotoFor(String userId) {
    if (userId == hostId) return renterPhoto;
    return hostPhoto;
  }

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'bookingId': bookingId,
        'carId': carId,
        'hostId': hostId,
        'renterId': renterId,
        'carName': carName,
        'hostName': hostName,
        'renterName': renterName,
        'hostPhoto': hostPhoto,
        'renterPhoto': renterPhoto,
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'hostUnreadCount': hostUnreadCount,
        'renterUnreadCount': renterUnreadCount,
        'isActive': isActive,
        'bookingStatus': bookingStatus,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      conversationId: id,
      bookingId: map['bookingId'] as String?,
      carId: map['carId'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      renterId: map['renterId'] as String? ?? '',
      carName: map['carName'] as String? ?? '',
      hostName: map['hostName'] as String? ?? 'Host',
      renterName: map['renterName'] as String? ?? 'Renter',
      hostPhoto: map['hostPhoto'] as String?,
      renterPhoto: map['renterPhoto'] as String?,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: (map['lastMessageAt'] is Timestamp)
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      hostUnreadCount: (map['hostUnreadCount'] as num?)?.toInt() ?? 0,
      renterUnreadCount: (map['renterUnreadCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      bookingStatus: map['bookingStatus'] as String?,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final String type; // 'text' | 'system'
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.type,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  bool get isSystem => type == 'system';

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderId': senderId,
        'text': text,
        'type': type,
        'isRead': isRead,
        'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      messageId: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      isRead: map['isRead'] as bool? ?? false,
      readAt: (map['readAt'] is Timestamp)
          ? (map['readAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
