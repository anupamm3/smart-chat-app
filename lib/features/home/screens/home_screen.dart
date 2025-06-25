import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final size = MediaQuery.of(context).size;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

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
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(
          'Start New Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          // TODO: Implement new chat logic or navigation
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User info card
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                    builder: (context, snapshot) {
                      String displayName = user.displayName ?? '';
                      String photoUrl = user.photoURL ?? '';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final userModel = UserModel.fromMap(userData);
                        displayName = userModel.name;
                        photoUrl = userModel.profilePic;
                      }
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty
                                    ? Icon(Icons.person, size: 32, color: colorScheme.primary)
                                    : null,
                                backgroundColor: colorScheme.primaryContainer,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Text(
                                  displayName.isNotEmpty ? displayName : 'User',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Recent chats card
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Card(
                      key: ValueKey(user.uid),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: SizedBox(
                          height: size.height * 0.55,
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

                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                                    builder: (context, userSnapshot) {
                                      String otherUserName = 'Unknown';
                                      String otherUserPic = '';
                                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                        final otherUser = UserModel.fromMap(userData);
                                        otherUserName = otherUser.name;
                                        otherUserPic = otherUser.profilePic;
                                      }

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: otherUserPic.isNotEmpty
                                              ? NetworkImage(otherUserPic)
                                              : null,
                                          child: otherUserPic.isEmpty
                                              ? Icon(Icons.person, color: colorScheme.primary)
                                              : null,
                                          backgroundColor: colorScheme.primaryContainer,
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
                                        trailing: lastMessageTime != null
                                            ? Text(
                                                '${lastMessageTime.hour.toString().padLeft(2, '0')}:${lastMessageTime.minute.toString().padLeft(2, '0')}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                                                ),
                                              )
                                            : null,
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/chat',
                                            arguments: {
                                              'chatId': chat.id,
                                              'otherUserId': otherUserId,
                                              'otherUserName': otherUserName,
                                            },
                                          );
                                        },
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}