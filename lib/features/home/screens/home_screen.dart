import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/features/home/screens/chats_tab.dart';
import 'package:smart_chat_app/features/home/screens/groups_tab.dart';
import 'package:smart_chat_app/features/home/screens/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIdx = 0;
  int _previousIdx = 0;

  // Create the tabs list
  List<Widget> _getTabs(User user) {
    return [
      ChatsTab(user: user),
      const GroupsTab(),
      ProfileTab(user: user)
    ];
  }

  // Animate to selected tab
  void _onTabSelected(int index) {
    setState(() {
      _previousIdx = _currentIdx;
      _currentIdx = index;
    });
  }

  // Custom slide transition
  Widget _slideTransition(Widget child, Animation<double> animation) {
    // Determine slide direction based on index change
    final isMovingForward = _currentIdx > _previousIdx;
    
    return SlideTransition(
      position: Tween<Offset>(
        begin: isMovingForward 
            ? const Offset(1.0, 0.0)  // Slide from right (moving forward)
            : const Offset(-1.0, 0.0), // Slide from left (moving backward)
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
      )),
      child: child,
    );
  }

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

    final tabs = _getTabs(user);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.fastOutSlowIn,
        switchOutCurve: Curves.fastOutSlowIn,
        transitionBuilder: _slideTransition,
        child: Container(
          key: ValueKey<int>(_currentIdx),
          child: tabs[_currentIdx],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIdx,
        onDestinationSelected: _onTabSelected,
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