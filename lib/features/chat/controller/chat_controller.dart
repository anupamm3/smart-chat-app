import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_chat_app/models/message_model.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/chatbot_model.dart';
import 'package:smart_chat_app/services/media_cache_service.dart';
import 'package:smart_chat_app/config/chatbot_config.dart';
import 'dart:async';
import 'dart:math';

class ChatController {
  final UserModel receiver;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  late final String chatId;

  // NEW: Chatbot functionality properties
  bool get isChatbotChat => ChatbotModel.isChatbotUser(receiver.uid);
  Timer? _typingTimer;
  bool _isTyping = false;

  ChatController({required this.receiver}) {
    chatId = _generateChatId(currentUser.uid, receiver.uid);
  }

  String _generateChatId(String uid1, String uid2) {
    final sortedUids = [uid1, uid2]..sort();
    return sortedUids.join('_');
  }

  // EXISTING: Keep all existing messageStream logic unchanged
  Stream<List<MessageModel>> messageStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs.map((doc) {
            final m = MessageModel.fromMap(doc.data());
            return m;
          }).where((m) {
            if (m.type == 'scheduled' && !m.sent) {
              return m.senderId == currentUser.uid;
            }
            return true;
          }).toList();

          // Preload media for recent messages
          _preloadRecentMedia(messages);
          
          return messages;
        });
  }

  // EXISTING: Keep unchanged
  void _preloadRecentMedia(List<MessageModel> messages) {
    final recentMessages = messages.take(20).toList(); // Last 20 messages
    final mediaUrls = recentMessages
        .where((m) => m.mediaUrl != null && !m.mediaUrl!.startsWith('local://'))
        .map((m) => m.mediaUrl!)
        .toList();
    
    if (mediaUrls.isNotEmpty) {
      MediaCacheService().preloadMedia(mediaUrls);
    }
  }

  // ENHANCED: Add chatbot response trigger while keeping existing logic
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // EXISTING: Send user message normally
    final message = {
      'text': text.trim(),
      'senderId': currentUser.uid,
      'receiverId': receiver.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [currentUser.uid, receiver.uid],
      'unreadCounts': {
        receiver.uid: FieldValue.increment(1),
        currentUser.uid: 0,
      },
    }, SetOptions(merge: true));

    if (isChatbotChat) {
      // Fire and forget - don't block the UI
      sendMessageToChatbot(text.trim()).catchError((error) {
        debugPrint('Chatbot response error: $error');
        // Send fallback message on error
        _sendChatbotMessage('Sorry, I encountered an error. Please try again! 🤖');
      });
    }
  }

  // NEW: Send message to chatbot and handle AI response
  Future<void> sendMessageToChatbot(String userMessage) async {
    try {
      // Simulate typing indicator
      await _simulateTypingIndicator();

      // Generate chatbot response
      final botResponse = await _generateChatbotResponse(userMessage);

      // Send chatbot response as a message
      await _sendChatbotMessage(botResponse);

    } catch (e) {
      // Handle errors gracefully with fallback message
      final errorMessage = 'Sorry, I\'m having trouble right now. Please try again in a moment! 🤖';
      await _sendChatbotMessage(errorMessage);
    }
  }

  // NEW: Simulate typing delay for realistic chatbot experience
  Future<void> _simulateTypingIndicator() async {
    _isTyping = true;
    
    // Calculate realistic typing delay
    final baseDelay = ChatbotConfig.typingDelayBaseMs;
    final randomDelay = Random().nextInt(1500) + 500; // 500-2000ms
    final totalDelay = (baseDelay + randomDelay).clamp(1000, ChatbotConfig.maxTypingDelayMs);
    
    await Future.delayed(Duration(milliseconds: totalDelay));
    _isTyping = false;
  }

  // NEW: Generate chatbot response using ChatbotModel
  Future<String> _generateChatbotResponse(String userMessage) async {
    try {
      return await ChatbotModel.generateChatbotResponse(userMessage);
    } catch (e) {
      // Return fallback response if AI service fails
      return ChatbotConfig.defaultFallbackMessage;
    }
  }

  // NEW: Send chatbot message to Firestore
  Future<void> _sendChatbotMessage(String botResponse) async {
    final message = {
      'text': botResponse,
      'senderId': receiver.uid, // Chatbot is the sender
      'receiverId': currentUser.uid, // User is the receiver
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'delivered', // Chatbot messages are immediately delivered
      'type': 'chatbot', // Mark as chatbot message
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Update chat metadata
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': botResponse.length > 50 
          ? '${botResponse.substring(0, 50)}...' 
          : botResponse,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [currentUser.uid, receiver.uid],
      'unreadCounts': {
        currentUser.uid: FieldValue.increment(1), // User gets notification
        receiver.uid: 0, // Chatbot doesn't need notifications
      },
    }, SetOptions(merge: true));
  }

  // NEW: Get typing status for UI
  bool get isTyping => _isTyping;

  // NEW: Cleanup method for typing timer
  void dispose() {
    _typingTimer?.cancel();
  }

  // EXISTING: Keep all existing methods unchanged below this line

  /// Call this when the chat screen is opened by the receiver to mark messages as seen
  Future<void> markMessagesAsSeen() async {
    final unreadMessages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isNotEqualTo: 'seen')
        .get();

    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      final type = data['type'];
      final sent = data['sent'];
      // Only mark as seen if it's a normal message or a sent scheduled message
      if (type == null ||
          type == 'text' ||
          type == 'chatbot' || // NEW: Mark chatbot messages as seen too
          (type == 'scheduled' && sent == true)) {
        await doc.reference.update({'status': 'seen'});
      }
    }

    // Reset unread count for this user in the chat doc
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .update({'unreadCounts.${currentUser.uid}': 0});
  }

  // EXISTING: Keep unchanged
  Future<void> scheduleMessage(String text, DateTime scheduledTime) async {
    if (text.trim().isEmpty) return;
    final message = {
      'text': text.trim(),
      'senderId': currentUser.uid,
      'receiverId': receiver.uid,
      'timestamp': null,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'sent': false,
      'type': 'scheduled',
      'status': 'pending',
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': '[Scheduled]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [currentUser.uid, receiver.uid],
    }, SetOptions(merge: true));
  }

  // EXISTING: Keep unchanged
  Future<void> processScheduledMessages() async {
    final now = DateTime.now();

    final scheduledMessages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('type', isEqualTo: 'scheduled')
        .where('sent', isEqualTo: false)
        .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (final doc in scheduledMessages.docs) {
      await doc.reference.update({
        'sent': true,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'type': 'scheduled',
      });
    }
  }

  // EXISTING: Keep all media message methods unchanged

  Future<void> sendMediaMessage(String mediaUrl, String mediaType, String? fileName, int? fileSize, String? thumbnailUrl, String? caption) async {
    final message = {
      'text': caption?.trim() ?? '',
      'senderId': currentUser.uid,
      'receiverId': receiver.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'fileName': fileName,
      'fileSize': fileSize,
      'mediaThumbnail': thumbnailUrl,
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Set appropriate last message based on media type
    String lastMessage;
    switch (mediaType) {
      case 'image':
        lastMessage = '[Image]';
        break;
      case 'video':
        lastMessage = '[Video]';
        break;
      case 'audio':
        lastMessage = '[Audio]';
        break;
      case 'document':
        lastMessage = '[Document]';
        break;
      default:
        lastMessage = '[Media]';
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [currentUser.uid, receiver.uid],
      'unreadCounts': {
        receiver.uid: FieldValue.increment(1),
        currentUser.uid: 0,
      },
    }, SetOptions(merge: true));

    // NEW: Trigger chatbot response for media if it's a chatbot chat
    if (isChatbotChat && caption != null && caption.trim().isNotEmpty) {
      await sendMessageToChatbot(caption.trim());
    } else if (isChatbotChat) {
      // Respond to media without caption
      final mediaResponse = _getMediaResponse(mediaType);
      await Future.delayed(const Duration(seconds: 1));
      await _sendChatbotMessage(mediaResponse);
    }
  }

  // NEW: Generate appropriate responses for media messages
  String _getMediaResponse(String mediaType) {
    switch (mediaType) {
      case 'image':
        return 'Nice image! 📸 What would you like to know about it?';
      case 'video':
        return 'Thanks for sharing the video! 🎥 Anything specific you\'d like to discuss?';
      case 'document':
        return 'I see you\'ve shared a document! 📄 How can I help you with it?';
      case 'audio':
        return 'Thanks for the audio message! 🎵 What can I help you with?';
      default:
        return 'Thanks for sharing! 📎 What would you like to talk about?';
    }
  }

  // EXISTING: Keep unchanged
  Future<void> sendImageMessage(String imageUrl, String? caption) async {
    await sendMediaMessage(imageUrl, 'image', null, null, null, caption);
  }

  // EXISTING: Keep unchanged
  Future<void> sendVideoMessage(String videoUrl, String? thumbnailUrl, String? caption) async {
    await sendMediaMessage(videoUrl, 'video', null, null, thumbnailUrl, caption);
  }

  // EXISTING: Keep unchanged
  Future<void> sendDocumentMessage(String documentUrl, String fileName, int fileSize, String? caption) async {
    await sendMediaMessage(documentUrl, 'document', fileName, fileSize, null, caption);
  }
}