import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/features/groups/screens/group_chat_screen.dart';
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
      _ChatsTab(user: user),
      GroupChatScreen(),
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

class _ChatsTab extends StatelessWidget {
  final User user;
  const _ChatsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chatQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageTime', descending: true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SmartChat',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search chats...",
                  hintStyle: GoogleFonts.poppins(
                    color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                  ),
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(),
                enabled: false, // Enable and implement search logic if needed
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(
          'New Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.newChat);
        },
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surface,
                    colorScheme.primaryContainer
                  ]
                : [
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: chatQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: GoogleFonts.poppins(
                        color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                      ),
                    ),
                  );
                }
                final chats = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => Divider(
                    color: colorScheme.outline.withAlpha((0.08 * 255).toInt()),
                    height: 0,
                  ),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final data = chat.data() as Map<String, dynamic>;
                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUserId = participants.firstWhere(
                      (id) => id != user.uid,
                      orElse: () => '',
                    );
                    if (otherUserId.isEmpty) return const SizedBox.shrink();
                    final lastMessage = data['lastMessage'] ?? '';
                    final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
                    final unreadCount = data['unreadCounts']?[user.uid]?.toString() ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                      builder: (context, userSnapshot) {
                        String otherUserName = 'Unknown';
                        String otherUserPic = '';
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final otherUser = UserModel.fromMap(userData);
                          otherUserName = otherUser.name;
                          otherUserPic = otherUser.photoUrl;
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: colorScheme.surface.withAlpha(isDark ? (0.55 * 255).toInt() : (0.85 * 255).toInt()),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: otherUserPic.isNotEmpty
                                  ? NetworkImage(otherUserPic)
                                  : null,
                              backgroundColor: colorScheme.primaryContainer,
                              child: otherUserPic.isEmpty
                                  ? Icon(Icons.person, color: colorScheme.primary)
                                  : null,
                            ),
                            title: Text(
                              otherUserName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (lastMessageTime != null)
                                  Text(
                                    "${lastMessageTime.hour.toString().padLeft(2, '0')}:${lastMessageTime.minute.toString().padLeft(2, '0')}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                                    ),
                                  ),
                                if (unreadCount != '' && unreadCount != '0')
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount,
                                      style: GoogleFonts.poppins(
                                        color: colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () async {
                              final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
                              if (!context.mounted) return;
                              if (userDoc.exists) {
                                final otherUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.chat,
                                  arguments: otherUser,
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}