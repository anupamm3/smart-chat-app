import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/models/message_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  late String chatId;
  late String otherUserId;
  late String otherUserName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    chatId = args?['chatId'] ?? '';
    otherUserId = args?['otherUserId'] ?? '';
    otherUserName = args?['otherUserName'] ?? '';
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final message = {
      'text': text,
      'senderId': user.uid,
      'receiverId': otherUserId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);

    // Update chat's last message info
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUserName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = MessageModel.fromMap(messages[index].data() as Map<String, dynamic>);
                    final isMe = msg.senderId == user.uid;
                    final time = msg.timestamp;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                            if (time != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white70
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}