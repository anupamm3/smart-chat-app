import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/message_model.dart';
import 'package:smart_chat_app/services/firestore_service.dart';

final chatControllerProvider = Provider((ref) => ChatController());

class ChatController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _scheduledChecker;

  // Generate a unique chatId for two users (sorted)
  String getChatId(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  // Send a normal message
  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String receiverId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = MessageModel(
      senderId: user.uid,
      receiverId: receiverId,
      text: text,
      timestamp: DateTime.now(),
      isScheduled: false,
      scheduledTime: null,
    );

    await FirestoreService.sendMessage(
      chatId: chatId,
      message: message,
    );
  }

  // Send a scheduled message
  Future<void> sendScheduledMessage({
    required String chatId,
    required String text,
    required String receiverId,
    required DateTime scheduledTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = MessageModel(
      senderId: user.uid,
      receiverId: receiverId,
      text: text,
      timestamp: null,
      isScheduled: true,
      scheduledTime: scheduledTime,
    );

    await FirestoreService.sendMessage(
      chatId: chatId,
      message: message,
    );
  }

  // Periodically check and send scheduled messages
  void startScheduledMessageChecker(String chatId) {
    _scheduledChecker?.cancel();
    _scheduledChecker = Timer.periodic(const Duration(seconds: 15), (_) {
      FirestoreService.checkAndSendScheduledMessages(chatId);
    });
  }

  void stopScheduledMessageChecker() {
    _scheduledChecker?.cancel();
  }

  // Fetch messages stream for a chat (now returns List<MessageModel>)
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return FirestoreService.fetchMessages(chatId);
  }
}