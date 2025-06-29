import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/home/screens/chats_tab.dart';
import 'package:smart_chat_app/features/home/screens/groups_tab.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIdx = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Not signed in'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
                },
                child: const Text('Login here'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> tabs = [
      ChatsTab(user: user),
      GroupsTab(),
      FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final userModel = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
          return UserProfileScreen(user: userModel);
        },
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: tabs[_currentIdx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIdx,
        onDestinationSelected: (idx) => setState(() => _currentIdx = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        height: 64,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withAlpha((0.08 * 255).toInt()),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}