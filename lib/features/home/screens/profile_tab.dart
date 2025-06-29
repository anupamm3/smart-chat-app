import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  final User user;
  const ProfileTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final userModel = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        return UserProfileScreen(user: userModel);
      },
    );
  }
}