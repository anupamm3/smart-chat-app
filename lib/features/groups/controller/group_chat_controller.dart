import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_chat_app/models/group_model.dart';

final groupListProvider = StreamProvider.family<List<GroupModel>, String>((ref, currentUserId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .where('members', arrayContains: currentUserId)
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList());
});

Future<void> deliverDueScheduledMessages(String groupId) async {
  final now = DateTime.now();
  final scheduled = await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('scheduledMessages')
      .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
      .get();

  for (final doc in scheduled.docs) {
    final data = doc.data();
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add({
      'senderId': data['senderId'],
      'text': data['text'],
      'sentAt': data['scheduledAt'],
      'scheduled': true,
    });
    await doc.reference.delete();
  }
}