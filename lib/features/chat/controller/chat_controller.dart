import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/message_model.dart';
import 'package:smart_chat_app/models/user_model.dart';

class ChatController {
  final UserModel receiver;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  late final String chatId;

  ChatController({required this.receiver}) {
    chatId = _generateChatId(currentUser.uid, receiver.uid);
  }

  String _generateChatId(String uid1, String uid2) {
    final sortedUids = [uid1, uid2]..sort();
    return sortedUids.join('_');
  }

  Stream<List<MessageModel>> messageStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
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
  }

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
      await doc.reference.update({'status': 'seen'});
    }

    // Reset unread count for this user in the chat doc
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .update({'unreadCounts.${currentUser.uid}': 0});
  }
}