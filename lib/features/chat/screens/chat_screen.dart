import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/chat/controller/chat_controller.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/message_model.dart';
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
  String? _localContactName;

  @override
  void initState() {
    super.initState();
    // Mark messages as seen when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider(widget.receiver)).markMessagesAsSeen();
      _fetchLocalContactName();
    });
  }

  Future<void> _fetchLocalContactName() async {
    // Check permission status first
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
      if (!status.isGranted) {
        // Optionally show a dialog and open app settings if denied forever
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }
    }

    // Now safe to fetch contacts
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final phone = widget.receiver.phoneNumber.replaceAll(RegExp(r'\D'), '');
    for (final contact in contacts) {
      for (final item in contact.phones) {
        final contactPhone = item.number.replaceAll(RegExp(r'\D'), '');
        if (contactPhone.endsWith(phone)) {
          setState(() {
            _localContactName = contact.displayName;
          });
          return;
        }
      }
    }
  }

  void _sendMessage(ChatController chatController) async {
    await chatController.sendMessage(_controller.text);
    _controller.clear();
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatController = ref.watch(chatControllerProvider(widget.receiver));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.receiver));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: colorScheme.primary),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.profile,
                  arguments: widget.receiver,
                );
              },
              child: CircleAvatar(
                backgroundImage: widget.receiver.photoUrl.isNotEmpty
                    ? NetworkImage(widget.receiver.photoUrl)
                    : null,
                backgroundColor: colorScheme.primaryContainer,
                child: widget.receiver.photoUrl.isEmpty
                    ? Icon(Icons.person, color: colorScheme.primary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localContactName?.isNotEmpty == true
                    ? _localContactName!
                    : (widget.receiver.name.isNotEmpty
                        ? widget.receiver.name
                        : widget.receiver.phoneNumber),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    colorScheme.surfaceContainerHighest.withAlpha((0.95 * 255).toInt()),
                    colorScheme.surface.withAlpha((0.95 * 255).toInt()),
                    colorScheme.primary.withAlpha((0.10 * 255).toInt()),
                  ]
                : [
                    colorScheme.primary.withAlpha((0.08 * 255).toInt()),
                    colorScheme.surface.withAlpha((0.98 * 255).toInt()),
                    colorScheme.surfaceContainerHighest.withAlpha((0.95 * 255).toInt()),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
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
            SafeArea(
              child: Padding(
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
                    FloatingActionButton(
                      mini: true,
                      onPressed: () => _sendMessage(chatController),
                      backgroundColor: colorScheme.primary,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}