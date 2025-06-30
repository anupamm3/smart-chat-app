import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';

class UserModel {
  final String uid;
  final String phoneNumber; // Store full international number
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

  // Get local phone number for display and matching
  String get localPhoneNumber => PhoneUtils.toLocalNumber(phoneNumber);

  // Get formatted phone number for display
  String get displayPhoneNumber => PhoneUtils.formatForDisplay(phoneNumber);

  // Check if phone number is valid
  bool get hasValidPhoneNumber => PhoneUtils.isPhoneNumber(phoneNumber);

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] is Timestamp 
              ? (data['lastSeen'] as Timestamp).toDate()
              : data['lastSeen'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'])
                  : DateTime.now())
          : DateTime.now(),
      groups: List<String>.from(data['groups'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber, // Store full international number in Firestore
      'name': name,
      'bio': bio,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen), // Store as Timestamp for Firestore
      'groups': groups,
      'friends': friends,
      'blockedUsers': blockedUsers,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    String? bio,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? groups,
    List<String>? friends,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      groups: groups ?? this.groups,
      friends: friends ?? this.friends,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  // Helper method to check if this user matches a phone number
  bool matchesPhoneNumber(String otherPhoneNumber) {
    return PhoneUtils.areNumbersEqual(phoneNumber, otherPhoneNumber);
  }

  // Helper method to get display name priority: name > local phone > "Unknown"
  String get displayName {
    if (name.isNotEmpty) {
      return name;
    } else if (phoneNumber.isNotEmpty) {
      return displayPhoneNumber;
    }
    return 'Unknown';
  }

  // Helper method to get initials for avatar
  String get initials {
    if (name.isNotEmpty) {
      final words = name.trim().split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    }
    
    if (localPhoneNumber.isNotEmpty) {
      return localPhoneNumber.substring(localPhoneNumber.length - 1);
    }
    
    return '?';
  }

  // Override toString for debugging
  @override
  String toString() {
    return 'UserModel{uid: $uid, name: $name, phoneNumber: $phoneNumber, isOnline: $isOnline}';
  }

  // Override equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}