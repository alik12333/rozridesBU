import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Conversation ID ────────────────────────────────────────────────────────
  // For pre-booking chats: conversationId = "{carId}_{renterId}"
  // For booking chats: we store the bookingId in the conversation doc after booking
  String _preBookingConvId(String carId, String renterId) =>
      '${carId}_$renterId';

  // ── Get or Create Conversation (from listing page) ─────────────────────────
  Future<ConversationModel> getOrCreateConversation({
    required String carId,
    required String carName,
    required String hostId,
    required String hostName,
    String? hostPhoto,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');
    final renterId = currentUser.uid;

    if (renterId == hostId) throw Exception('CANNOT_CHAT_OWN_LISTING');

    final convId = _preBookingConvId(carId, renterId);
    final convRef = _firestore.collection('conversations').doc(convId);

    // Fetch renter info
    String renterName = 'Renter';
    String? renterPhoto;
    try {
      final snap = await _firestore.collection('users').doc(renterId).get();
      renterName = snap.data()?['fullName'] ?? 'Renter';
      renterPhoto = snap.data()?['profilePhoto'] as String?;
    } catch (_) {}

    final snap = await convRef.get();
    if (snap.exists) {
      return ConversationModel.fromMap(snap.data()!, convId);
    }

    // Create a new conversation
    final conversation = ConversationModel(
      conversationId: convId,
      bookingId: null,
      carId: carId,
      hostId: hostId,
      renterId: renterId,
      carName: carName,
      hostName: hostName,
      renterName: renterName,
      hostPhoto: hostPhoto,
      renterPhoto: renterPhoto,
      participants: [hostId, renterId],
      hostUnreadCount: 0,
      renterUnreadCount: 0,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await convRef.set(conversation.toMap());
    return conversation;
  }

  // ── Post a system message (used by booking_service) ────────────────────────
  Future<void> postSystemMessage({
    required String conversationId,
    required String text,
  }) async {
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'messageId': msgRef.id,
      'senderId': 'system',
      'text': text,
      'type': 'system',
      'isRead': true,
      'readAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      _firestore.collection('conversations').doc(conversationId),
      {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  // ── Send a user message ────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required bool senderIsHost,
  }) async {
    final batch = _firestore.batch();
    final convRef =
        _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    batch.set(msgRef, {
      'messageId': msgRef.id,
      'senderId': senderId,
      'text': text,
      'type': 'text',
      'isRead': false,
      'readAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment the OTHER party's unread count
    final unreadField =
        senderIsHost ? 'renterUnreadCount' : 'hostUnreadCount';
    batch.update(convRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      unreadField: FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ── Reset unread count when user opens a chat ──────────────────────────────
  Future<void> resetUnreadCount({
    required String conversationId,
    required bool isHost,
  }) async {
    final field = isHost ? 'hostUnreadCount' : 'renterUnreadCount';
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({field: 0});
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<ConversationModel>> getConversationsForUser(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ConversationModel.fromMap(d.data(), d.id))
          .toList();
      // Sort in memory to avoid requiring a composite index in Firestore
      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime); // descending
      });
      return list;
    });
  }

  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs
          .map((d) => MessageModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // ascending
      return list;
    });
  }

  // ── Link a booking to an existing pre-booking conversation ─────────────────
  Future<void> linkBookingToConversation({
    required String carId,
    required String renterId,
    required String bookingId,
    required String bookingStatus,
  }) async {
    final convId = _preBookingConvId(carId, renterId);
    final convRef = _firestore.collection('conversations').doc(convId);
    final snap = await convRef.get();
    if (snap.exists) {
      await convRef.update({
        'bookingId': bookingId,
        'bookingStatus': bookingStatus,
      });
    }
  }

  // ── Update booking status on conversation (called after status transitions) ─
  Future<void> updateConversationBookingStatus({
    required String conversationId,
    required String bookingStatus,
  }) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({'bookingStatus': bookingStatus});
    } catch (_) {}
  }
}
