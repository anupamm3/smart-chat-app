import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePic,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profilePic: map['photoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': profilePic,
    };
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      profilePic: user.photoURL ?? '',
    );
  }
}