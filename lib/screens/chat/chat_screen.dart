import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  ConversationModel? _conversation;
  bool _isHost = false;
  String? _otherPartyPhone;

  @override
  void initState() {
    super.initState();
    _loadConversationAndMarkRead();
  }

  Future<void> _loadConversationAndMarkRead() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (snap.exists) {
        final convo = ConversationModel.fromMap(snap.data()!, snap.id);
        final isHost = widget.currentUserId == convo.hostId;
        setState(() {
          _conversation = convo;
          _isHost = isHost;
        });

        // Fetch the other party's phone number
        final otherPartyId = isHost ? convo.renterId : convo.hostId;
        try {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherPartyId)
              .get();
          if (userSnap.exists && mounted) {
            setState(() {
              _otherPartyPhone = userSnap.data()?['phoneNumber'] as String?;
            });
          }
        } catch (_) {}

        await _chatService.resetUnreadCount(
          conversationId: widget.conversationId,
          isHost: _isHost,
        );
      }
    } catch (e) {
      debugPrint('Error loading conversation: $e');
    }
  }

  Future<void> _dialPhone() async {
    final phone = _otherPartyPhone;
    if (phone == null || phone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the phone dialer.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _conversation == null) return;

    _textCtrl.clear();
    _scrollToBottom();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        senderId: widget.currentUserId,
        senderIsHost: _isHost,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
          );
        }
        
        final doc = snap.data!;
        if (!doc.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: const Center(child: Text('Conversation not found.')),
          );
        }

        _conversation = ConversationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        _isHost = widget.currentUserId == _conversation!.hostId;

        final otherName = _conversation!.otherPartyNameFor(widget.currentUserId);
        final otherPhoto = _conversation!.otherPartyPhotoFor(widget.currentUserId);

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.white,
            titleSpacing: 0,
            leading: const BackButton(color: Colors.black),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  backgroundImage: (otherPhoto != null && otherPhoto.isNotEmpty)
                      ? NetworkImage(otherPhoto)
                      : null,
                  child: (otherPhoto == null || otherPhoto.isEmpty)
                      ? Text(
                          otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF7C3AED),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        otherName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _conversation!.carName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF7C3AED),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: Color(0xFF7C3AED)),
                tooltip: 'Call',
                onPressed: _dialPhone,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      stream: _chatService.getMessages(widget.conversationId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error loading messages: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
                        }
                        
                        final messages = snapshot.data ?? [];
                        
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollCtrl.hasClients) {
                            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                          }
                        });

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'Start your conversation with $otherName',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 80, 16, 100), // Extra top padding for floating status
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            if (msg.isSystem) {
                              return _SystemMessageBubble(message: msg);
                            }
                            final isMe = msg.senderId == widget.currentUserId;
                            return _ChatBubble(message: msg, isMe: isMe);
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Input Area
                  _buildInputArea(),
                ],
              ),

              // Floating Status Pill
              _buildFloatingStatus(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingStatus() {
    final status = _conversation?.bookingStatus ?? 'pre-booking';
    final bool isDead = status == 'cancelled' || status == 'rejected';
    final bool isComplete = status == 'completed';
    final Color color = isDead ? Colors.red : (isComplete ? Colors.green : const Color(0xFF7C3AED));

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusLabel(status),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'WAITING FOR APPROVAL';
      case 'approved': return 'BOOKING CONFIRMED';
      case 'active': return 'ACTIVE TRIP';
      case 'completed': return 'TRIP COMPLETED';
      case 'cancelled': return 'BOOKING CANCELLED';
      case 'rejected': return 'BOOKING REJECTED';
      default: return 'GENERAL INQUIRY';
    }
  }

  Widget _buildInputArea() {
    final bool isActive = _conversation?.isActive ?? true;

    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: Colors.grey.shade400, size: 24),
            const SizedBox(height: 8),
            Text(
              'This conversation is locked because the listing was deleted or an account was banned.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _textCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                maxLength: 1000,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isMe 
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    )
                  : null,
              color: isMe ? null : Colors.white,
              borderRadius: BorderRadius.circular(22).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(22),
                bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe 
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.15) 
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              _formatTime(message.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final MessageModel message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300.withValues(alpha: 0.5)),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
