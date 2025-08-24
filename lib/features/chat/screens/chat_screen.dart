import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/features/chat/controller/chat_controller.dart';
import 'package:smart_chat_app/models/chatbot_model.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/message_model.dart';
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/services/media_cache_service.dart';
import 'package:smart_chat_app/services/media_optimization_service.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';
import 'package:smart_chat_app/widgets/message_bubble.dart';

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

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin{
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ContactService _contactService = ContactService();
  Map<String, String> _contactMapping = {};
  bool _contactsLoaded = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  bool get _isChatbotChat => ChatbotModel.isChatbotUser(widget.receiver.uid);
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  Timer? _typingTimer;

  bool _isReceiverOnline = false;
  DateTime? _receiverLastSeen;
  StreamSubscription<DocumentSnapshot>? _onlineStatusSubscription;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
    // Mark messages as seen when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider(widget.receiver)).markMessagesAsSeen();
      _loadContacts();
      if (_isChatbotChat) {
        _startTypingListener();
      }
    });
    _listenToOnlineStatus();
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _typingTimer?.cancel();
    _onlineStatusSubscription?.cancel();
    super.dispose();
  }

  void _listenToOnlineStatus() {
    _onlineStatusSubscription = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.receiver.uid)
      .snapshots()
      .listen((doc) {
        if (doc.exists && doc.data() != null) {
          setState(() {
            _isReceiverOnline = doc['isOnline'] ?? false;
            final lastSeenTimestamp = doc['lastSeen'];
            if (lastSeenTimestamp != null) {
              _receiverLastSeen = (lastSeenTimestamp is Timestamp)
                  ? lastSeenTimestamp.toDate()
                  : null;
            }
          });
        }
      });
  }

  String _getLastSeenText() {
    if (_receiverLastSeen == null) return '';
    final now = DateTime.now();
    final difference = now.difference(_receiverLastSeen!);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${_receiverLastSeen!.day}/${_receiverLastSeen!.month}/${_receiverLastSeen!.year} at ${_receiverLastSeen!.hour.toString().padLeft(2, '0')}:${_receiverLastSeen!.minute.toString().padLeft(2, '0')}';
    }
  }

  void _startTypingListener() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final chatController = ref.read(chatControllerProvider(widget.receiver));
      if (chatController.isTyping) {
        if (!_typingAnimationController.isAnimating) {
          _typingAnimationController.repeat();
        }
      } else {
        _typingAnimationController.stop();
        _typingAnimationController.reset();
      }
    });
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
    if (_isChatbotChat) {
      return ChatbotModel.getChatbotUser().name;
    }
    return _contactService.getDisplayName(
      widget.receiver.phoneNumber,
      widget.receiver.name,
      _contactMapping,
    );
  }
  
  bool _isPhoneLike(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return cleaned.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleaned);
  }

  void _sendMessage(ChatController chatController) async {
    final messageText = _controller.text.trim();
    if (messageText.isEmpty) return;

    // 🔧 FIXED: Clear text field immediately before sending
    _controller.clear();
    
    try {
      // This will now complete quickly since chatbot response is non-blocking
      await chatController.sendMessage(messageText);
      ref.invalidate(chatMessagesProvider(widget.receiver));
      
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // If sending the user message fails, optionally restore text
      debugPrint('Failed to send message: $e');
      // Uncomment if you want to restore text on failure:
      // _controller.text = messageText;
    }
  }
  Future<void> _onScheduleMessagePressed() async {
    final colorScheme = Theme.of(context).colorScheme;
    final chatController = ref.read(chatControllerProvider(widget.receiver));
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isChatbotChat) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Scheduled messages are not available for AI chats', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

  // NEW MEDIA FUNCTIONALITY
  void _showMediaPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withAlpha((0.3 * 255).toInt()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Send Media',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MediaPickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: colorScheme.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _MediaPickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _MediaPickerOption(
                    icon: Icons.description,
                    label: 'Document',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _showImagePreview(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();
        
        if (fileSize > 50 * 1024 * 1024) { // 50MB limit
          _showErrorSnackBar('Video file too large. Maximum size is 50MB.');
          return;
        }
        
        await _uploadAndSendMedia(file, 'video');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'ppt', 'pptx'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileSize = await file.length();
        
        if (fileSize > 10 * 1024 * 1024) { // 10MB limit for documents
          _showErrorSnackBar('Document too large. Maximum size is 10MB.');
          return;
        }
        
        await _uploadAndSendMedia(file, 'document', fileName: result.files.first.name);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick document: $e');
    }
  }

  Future<void> _showImagePreview(File imageFile) async {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController captionController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text('Send Image', style: GoogleFonts.poppins()),
                  backgroundColor: colorScheme.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: captionController,
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Add a caption...',
                              hintStyle: GoogleFonts.poppins(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Send', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    if (confirmed == true) {
      await _uploadAndSendMedia(imageFile, 'image', caption: captionController.text.trim());
    }
  }

  Future<void> _uploadAndSendMedia(File file, String mediaType, {String? caption, String? fileName}) async {
    if (_isUploading) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final chatController = ref.read(chatControllerProvider(widget.receiver));
      final currentUser = FirebaseAuth.instance.currentUser!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Optimize image if it's an image
      File fileToUpload = file;
      if (mediaType == 'image') {
        fileToUpload = await MediaOptimizationService.optimizeImage(file);
      }
      
      // Create file path
      final extension = fileToUpload.path.split('.').last;
      final storagePath = 'chats/${chatController.chatId}/$mediaType/${currentUser.uid}_$timestamp.$extension';
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = storageRef.putFile(fileToUpload);
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() => _uploadProgress = progress);
      });
      
      // Wait for upload completion
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      // Pre-cache the uploaded media
      await MediaCacheService().getMedia(downloadUrl, forceRefresh: true);
      
      // Get file size
      final fileSize = await fileToUpload.length();
      
      // Send media message
      await chatController.sendMediaMessage(
        downloadUrl,
        mediaType,
        fileName,
        fileSize,
        null, // thumbnail - implement later for videos
        caption,
      );
      
      ref.invalidate(chatMessagesProvider(widget.receiver));
      
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
      // Clean up optimized file if different from original
      if (fileToUpload.path != file.path) {
        await fileToUpload.delete();
      }
      
    } catch (e) {
      _showErrorSnackBar('Failed to send media: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI is thinking',
                      style: GoogleFonts.poppins(
                        color: colorScheme.secondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      height: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(3, (index) {
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300 + (index * 100)),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withValues(alpha: 0.4 + (0.6 * _typingAnimation.value)),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
                  AppRoutes.userProfile,
                  arguments: widget.receiver,
                );
              },
              child: _isChatbotChat
                  ? CircleAvatar(
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: colorScheme.secondary,
                        size: 24,
                      ),
                    )
                  : CircleAvatar(
                backgroundImage: widget.receiver.photoUrl.isNotEmpty
                    ? NetworkImage(widget.receiver.photoUrl)
                    : null,
                backgroundColor: colorScheme.primaryContainer,
                child: widget.receiver.photoUrl.isEmpty
                    ? (!_isPhoneLike(_displayName) &&
                            _displayName.trim().isNotEmpty &&
                            RegExp(r'[A-Za-z]').hasMatch(_displayName.trim()[0]))
                        ? Text(
                            _displayName.trim()[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Icon(Icons.person, color: colorScheme.primary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: _isChatbotChat ? colorScheme.secondary : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isChatbotChat)
                    Row(
                      children: [
                        if (_isReceiverOnline)
                          Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 10,
                          ),
                        if (_isReceiverOnline)
                          const SizedBox(width: 4),
                        Text(
                          _isReceiverOnline
                              ? 'Online'
                              : (_receiverLastSeen != null
                                  ? 'Last seen ${_getLastSeenText()}'
                                  : 'Offline'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _isReceiverOnline ? Colors.green : null,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  if (_isChatbotChat)
                    Text(
                      'Powered by Gemini AI',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: colorScheme.secondary.withAlpha((0.7 * 255).toInt()),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        actions: _isChatbotChat
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upload progress indicator
            if (_isUploading)
              Container(
                padding: const EdgeInsets.all(8),
                color: colorScheme.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_upload, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Uploading... ${(_uploadProgress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ],
                ),
              ),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isChatbotChat) ...[
                            Icon(
                              Icons.smart_toy_rounded,
                              size: 64,
                              color: colorScheme.secondary.withAlpha((0.5 * 255).toInt()),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Hi! I\'m your AI Assistant',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ask me anything! I can help with questions,\ncreative writing, problem solving, and more.',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            Text(
                              'No messages yet',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
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
                              mediaUrl: msg.mediaUrl,
                              mediaType: msg.mediaType,
                              fileName: msg.fileName,
                              fileSize: msg.fileSize,
                              mediaThumbnail: msg.mediaThumbnail,
                            );
                          },
                        ),
                      ),
                      if (_isChatbotChat && chatController.isTyping)
                        _buildTypingIndicator(colorScheme),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Attachment button
                  Material(
                    color: colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUploading ? null : _showMediaPicker,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.attach_file,
                          color: _isUploading 
                            ? colorScheme.onSurface.withAlpha((0.4 * 255).toInt())
                            : colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: _isChatbotChat 
                            ? 'Ask me anything...' 
                            : 'Type a message...',
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
                  if (!_isChatbotChat)
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
                  if (!_isChatbotChat) const SizedBox(width: 8),
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

class _MediaPickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaPickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}