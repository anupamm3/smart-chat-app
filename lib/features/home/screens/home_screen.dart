import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/user_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    final chatQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats yet'));
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
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
                      child: otherUserPic.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(otherUserName),
                    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: lastMessageTime != null
                        ? Text(
                            '${lastMessageTime.hour.toString().padLeft(2, '0')}:${lastMessageTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
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
    );
  }
}