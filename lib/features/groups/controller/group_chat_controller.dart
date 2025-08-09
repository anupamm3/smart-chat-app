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