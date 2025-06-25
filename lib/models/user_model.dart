import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String photoUrl;
  final String phoneNumber;
  final DateTime? createdAt;
  final String? status;

  UserModel({
    required this.uid,
    required this.name,
    required this.photoUrl,
    this.phoneNumber = '',
    this.createdAt,
    this.status,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
      'status': status,
    };
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      photoUrl: user.photoURL ?? '',
      phoneNumber: user.phoneNumber ?? '',
      createdAt: DateTime.now(),
      status: "Hey there! I am using Smart Chat."
    );
  }
}