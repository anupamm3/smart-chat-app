import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String name;
  final String bio;
  final String photoUrl;
  final bool isOnline;
  final DateTime lastSeen;
  final List<String> groups;
  final List<String> friends;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    required this.groups,
    required this.friends,
    required this.blockedUsers,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      groups: List<String>.from(data['groups'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'bio': bio,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'groups': groups,
      'friends': friends,
      'blockedUsers': blockedUsers,
    };
  }
}
