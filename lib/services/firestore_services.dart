import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/message_model.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save new user data to Firestore
  static Future<bool> saveUserData({
    required UserModel user,
  }) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      // Optionally log error
      return false;
    }
  }

  /// Send a message in a chat
  static Future<bool> sendMessage({
    required String chatId,
    required MessageModel message,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      await _firestore.collection('chats').doc(chatId).set({
        'participants': [message.senderId, message.receiverId],
        'lastMessage': message.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      // Optionally log error
      return false;
    }
  }

  /// Fetch messages between two users (by chatId)
  static Stream<List<MessageModel>> fetchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  /// Fetch recent chats for HomeScreen (for a user)
  static Stream<QuerySnapshot> fetchRecentChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Check and send scheduled messages for a chat
  static Future<void> checkAndSendScheduledMessages(String chatId) async {
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
}