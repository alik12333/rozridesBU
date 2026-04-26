import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();

  List<ConversationModel> _conversations = [];
  StreamSubscription<List<ConversationModel>>? _sub;
  String? _activeUserId;

  List<ConversationModel> get conversations => _conversations;

  int get totalUnreadCount {
    if (_activeUserId == null) return 0;
    return _conversations.fold(
      0,
      (sum, c) => sum + c.unreadCountFor(_activeUserId!),
    );
  }

  void listenToConversations(String userId) {
    if (_activeUserId == userId) return;
    _activeUserId = userId;
    _sub?.cancel();
    _sub = _service.getConversationsForUser(userId).listen((list) {
      _conversations = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('ChatProvider stream error: $e');
    });
  }

  void stopListening() {
    _sub?.cancel();
    _activeUserId = null;
    _conversations = [];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
