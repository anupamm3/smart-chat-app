import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? photoUrl;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  GroupModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.members,
    required this.createdBy,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      members: List<String>.from(map['members'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
    );
  }
}