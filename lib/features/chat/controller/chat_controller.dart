import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/message_model.dart';

final chatControllerProvider = Provider((ref) => ChatController());

class ChatController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    ).toMap();

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Update chat's last message info
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [user.uid, receiverId],
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    ).toMap();

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Optionally update chat doc for UI
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [user.uid, receiverId],
      'lastMessage': '[Scheduled message]',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Periodically check and send scheduled messages
  void startScheduledMessageChecker(String chatId) {
    _scheduledChecker?.cancel();
    _scheduledChecker = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkAndSendScheduledMessages(chatId);
    });
  }

  void stopScheduledMessageChecker() {
    _scheduledChecker?.cancel();
  }

  Future<void> _checkAndSendScheduledMessages(String chatId) async {
    final now = DateTime.now();
    final scheduledMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isSent', isEqualTo: false)
        .where('scheduledTime', isLessThanOrEqualTo: now)
        .get();

    for (var doc in scheduledMessages.docs) {
      await doc.reference.update({
        'isSent': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final data = doc.data();
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': data['text'],
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
  }

  // Fetch messages stream for a chat
  Stream<QuerySnapshot> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }
}