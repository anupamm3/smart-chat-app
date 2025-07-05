import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';
import 'package:smart_chat_app/providers/user_provider.dart';

class ProfileTab extends ConsumerWidget {
  final User user;
  const ProfileTab({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStreamProvider(user.uid));
    return userAsync.when(
      data: (userModel) {
        if (userModel == null) {
          return const Scaffold(
            body: Center(child: Text('User not found')),
          );
        }
        return UserProfileScreen(user: userModel);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}