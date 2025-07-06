import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/chat/controller/chat_controller.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/message_model.dart';
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';
import 'package:smart_chat_app/widgets/messege_bubble.dart';

final chatControllerProvider = Provider.family<ChatController, UserModel>((ref, receiver) {
  return ChatController(receiver: receiver);
});

final chatMessagesProvider = StreamProvider.family<List<MessageModel>, UserModel>((ref, receiver) {
  final controller = ref.watch(chatControllerProvider(receiver));
  return controller.messageStream();
});

class ChatScreen extends ConsumerStatefulWidget {
  final UserModel receiver;
  const ChatScreen({super.key, required this.receiver});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _scheduledMsgTimer;
  final ContactService _contactService = ContactService();
  Map<String, String> _contactMapping = {};
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as seen when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider(widget.receiver)).markMessagesAsSeen();
      _loadContacts();

      // Start periodic check for scheduled messages
      _scheduledMsgTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        ref.read(chatControllerProvider(widget.receiver)).processScheduledMessages();
      });
    });
  }

  @override
  void dispose() {
    _scheduledMsgTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        _contactMapping = await _contactService.getContactMapping(currentUserId);
        setState(() => _contactsLoaded = true);
      }
    } catch (e) {
      setState(() => _contactsLoaded = true);
    }
  }

  String get _displayName {
    if (!_contactsLoaded) return 'Loading...';
    return _contactService.getDisplayName(
      widget.receiver.phoneNumber,
      widget.receiver.name,
      _contactMapping,
    );
  }

  bool get _hasContactName {
    return _contactService.hasContactName(widget.receiver.phoneNumber, _contactMapping);
  }

  String get _initials {
    return _contactService.getInitials(_displayName, widget.receiver.phoneNumber);
  }

  void _sendMessage(ChatController chatController) async {
    await chatController.sendMessage(_controller.text);
    _controller.clear();
    ref.invalidate(chatMessagesProvider(widget.receiver));
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

  Future<void> _onScheduleMessagePressed() async {
    final colorScheme = Theme.of(context).colorScheme;
    final chatController = ref.read(chatControllerProvider(widget.receiver));
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Pick date
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colorScheme,
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    // 2. Pick time
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colorScheme,
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    // Combine date and time
    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final TextEditingController messageController = TextEditingController();

    // 3. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Schedule Message', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: 'Enter your message',
                  hintStyle: GoogleFonts.poppins(),
                ),
                minLines: 1,
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.schedule, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled for: ${scheduledDateTime.toString().substring(0, 16)}',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text('Confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // 4. On confirm, schedule the message
    if (!mounted) return;
    if (confirmed == true && messageController.text.trim().isNotEmpty) {
      await chatController.scheduleMessage(
        messageController.text.trim(),
        scheduledDateTime,
      );
      ref.invalidate(chatMessagesProvider(widget.receiver));
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Message scheduled!', style: GoogleFonts.poppins()),
          backgroundColor: colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatController = ref.watch(chatControllerProvider(widget.receiver));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.receiver));

    return GradientScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: BackButton(color: colorScheme.primary),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.profileTab,
                  arguments: widget.receiver,
                );
              },
              child: CircleAvatar(
                backgroundImage: widget.receiver.photoUrl.isNotEmpty
                    ? NetworkImage(widget.receiver.photoUrl)
                    : null,
                backgroundColor: colorScheme.primaryContainer,
                child: widget.receiver.photoUrl.isEmpty
                    ? Text(
                        _initials,
                        style: GoogleFonts.poppins(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _displayName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (messages) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
        
                  if (messages.isEmpty) {
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
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == chatController.currentUser.uid;
                      final time = msg.timestamp;
                      return MessageBubble(
                        text: msg.text,
                        isMe: isMe,
                        timestamp: time,
                        status: isMe ? msg.status : null,
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
                      onSubmitted: (_) => _sendMessage(chatController),
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
                        child: Icon(
                          Icons.schedule,
                          color: Colors.white,
                          size: 28,
                        ),
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
                      onTap: () => _sendMessage(chatController),
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