import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/features/groups/controller/group_chat_controller.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';
import 'package:smart_chat_app/widgets/messege_bubble.dart';

class GroupChatRoomScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupPhotoUrl;

  const GroupChatRoomScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupPhotoUrl,
  });

  @override
  State<GroupChatRoomScreen> createState() => _GroupChatRoomScreenState();
}

class _GroupChatRoomScreenState extends State<GroupChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _scheduledMsgTimer;
  String? _creatorId;
  List<String> _members = [];
  bool _loadingGroup = true;

  @override
  void initState() {
    super.initState();
    _fetchGroupInfo();
    deliverDueScheduledMessages(widget.groupId);
    _scheduledMsgTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => deliverDueScheduledMessages(widget.groupId),
    );
  }

  Future<void> _fetchGroupInfo() async {
    final doc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
    if (doc.exists) {
      setState(() {
        _creatorId = doc['createdBy'] as String?;
        _members = List<String>.from(doc['members'] ?? []);
        _loadingGroup = false;
      });
    }
  }

  Future<void> _deleteGroup() async {
    // Delete group and all its messages
    final batch = FirebaseFirestore.instance.batch();
    final messages = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .get();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(FirebaseFirestore.instance.collection('groups').doc(widget.groupId));
    await batch.commit();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _leaveGroup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    await groupRef.update({
      'members': FieldValue.arrayRemove([userId])
    });
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onScheduleMessagePressed() async {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String scheduledText = '';
    DateTime? scheduledDateTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        final TextEditingController textController = TextEditingController();
        DateTime? pickedDateTime;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Schedule Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    pickedDateTime == null
                        ? 'Pick Date & Time'
                        : '${pickedDateTime?.year}-${pickedDateTime?.month.toString().padLeft(2, '0')}-${pickedDateTime?.day.toString().padLeft(2, '0')} '
                          '${pickedDateTime?.hour.toString().padLeft(2, '0')}:${pickedDateTime?.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.poppins(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          pickedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  scheduledText = textController.text.trim();
                  scheduledDateTime = pickedDateTime;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text('Schedule'),
              ),
            ],
          ),
        );
      },
    );

    if (scheduledText.isNotEmpty && scheduledDateTime != null) {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('scheduledMessages')
          .add({
        'senderId': user.uid,
        'text': scheduledText,
        'scheduledAt': Timestamp.fromDate(scheduledDateTime!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message scheduled!', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _controller.clear();

    final messageRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'senderId': user.uid,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Update last message in group doc
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    // Optionally scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scheduledMsgTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: BackButton(color: colorScheme.primary),
        title: GestureDetector(
          onTap: () {
            // TODO: Navigate to group profile screen with groupId
            // Navigator.pushNamed(context, '/group_profile', arguments: widget.groupId);
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: widget.groupPhotoUrl != null && widget.groupPhotoUrl!.isNotEmpty
                    ? NetworkImage(widget.groupPhotoUrl!)
                    : null,
                backgroundColor: colorScheme.primaryContainer,
                child: (widget.groupPhotoUrl == null || widget.groupPhotoUrl!.isEmpty)
                    ? Icon(Icons.groups, color: colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.groupName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        actions: [
          if (!_loadingGroup)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Group'),
                      content: const Text('Are you sure you want to delete this group? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) await _deleteGroup();
                } else if (value == 'leave') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave Group'),
                      content: const Text('Are you sure you want to leave this group?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                      ],
                    ),
                  );
                  if (confirm == true) await _leaveGroup();
                }
              },
              itemBuilder: (context) {
                if (currentUserId == _creatorId) {
                  return [
                    const PopupMenuItem(value: 'delete', child: Text('Delete Group')),
                  ];
                } else if (_members.contains(currentUserId)) {
                  return [
                    const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
                  ];
                } else {
                  return [];
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('messages')
                    .orderBy('sentAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet',
                        style: GoogleFonts.poppins(
                          color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = docs[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == FirebaseAuth.instance.currentUser?.uid;

                      // Parse timestamp
                      DateTime? timestamp;
                      if (msg['sentAt'] != null) {
                        if (msg['sentAt'] is Timestamp) {
                          timestamp = (msg['sentAt'] as Timestamp).toDate();
                        } else if (msg['sentAt'] is DateTime) {
                          timestamp = msg['sentAt'];
                        }
                      }

                      // For group chat, you may not have delivery/read status, so just show sent tick
                      MessageStatus? status;
                      if (isMe) {
                        status = MessageStatus.sent;
                      }

                      return MessageBubble(
                        text: msg['text'] ?? '',
                        isMe: isMe,
                        timestamp: timestamp,
                        status: status,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: colorScheme.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _onScheduleMessagePressed,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(Icons.schedule, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: colorScheme.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}