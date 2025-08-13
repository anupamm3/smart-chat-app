import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/chatbot_model.dart'; // Add this import
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';

class ChatsTab extends StatefulWidget {
  final User user;
  const ChatsTab({super.key, required this.user});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> with TickerProviderStateMixin { // Add TickerProviderStateMixin
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();
  
  // Add these new variables for contact synchronization
  Map<String, String> _contactMapping = {};
  bool _contactsLoaded = false;

  // NEW: Animation controllers for FABs
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    
    // NEW: Initialize animation controller
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose(); // NEW: Dispose animation controller
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      _contactMapping = await _contactService.getContactMapping(widget.user.uid);
      setState(() => _contactsLoaded = true);
    } catch (e) {
      setState(() => _contactsLoaded = true);
    }
  }

  // NEW: Navigate to chatbot chat
  void _navigateToChatbot() async {
    try {
      // Create chatbot user instance
      final chatbotUser = ChatbotModel.getChatbotUser().toUserModel();
      
      // Navigate to chat screen with chatbot
      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: chatbotUser,
      );
    } catch (e) {
      // Show error if navigation fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chatbot. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Simplified methods using ContactService
  String _getDisplayName(String phoneNumber, String registeredName) {
    return _contactService.getDisplayName(phoneNumber, registeredName, _contactMapping);
  }

  bool _hasContactName(String phoneNumber) {
    return _contactService.hasContactName(phoneNumber, _contactMapping);
  }
  
  bool _isPhoneLike(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return cleaned.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chatQuery = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: widget.user.uid)
        .orderBy('lastMessageTime', descending: true);

    return GradientScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'Home',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search chats...",
                  hintStyle: GoogleFonts.poppins(
                    color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                  ),
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
            ),
          ),
        ),
      ),
      // NEW: Enhanced FloatingActionButton with Stack for multiple FABs
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // NEW: Chatbot FAB positioned above the main FAB
              Positioned(
                bottom: 80, // 80px above the main FAB
                right: 0,
                child: Transform.scale(
                  scale: _fabAnimation.value,
                  child: FloatingActionButton(
                    heroTag: "chatbot_fab", // Unique hero tag
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    onPressed: _navigateToChatbot,
                    tooltip: 'Chat with AI Assistant',
                    child: const Icon(
                      Icons.smart_toy_rounded, // Robot/AI icon
                      size: 28,
                    ),
                  ),
                ),
              ),
              // EXISTING: Original New Chat FAB (unchanged)
              Positioned(
                bottom: 0,
                right: 0,
                child: Transform.scale(
                  scale: _fabAnimation.value,
                  child: FloatingActionButton.extended(
                    heroTag: "new_chat_fab", // Unique hero tag
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
                ),
              ),
            ],
          );
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: !_contactsLoaded // Add loading state check
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: chatQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(colorScheme, isDark); // NEW: Enhanced empty state
                    }
          
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buildChatListWithUserData(snapshot.data!.docs),
                      builder: (context, chatListSnapshot) {
                        if (chatListSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
          
                        if (!chatListSnapshot.hasData || chatListSnapshot.data!.isEmpty) {
                          return _buildEmptyState(colorScheme, isDark); // NEW: Enhanced empty state
                        }
          
                        // Updated filtering logic to include local phone numbers
                        final filteredChats = chatListSnapshot.data!.where((chatData) {
                          if (_searchQuery.isEmpty) return true;
                          
                          final userName = (chatData['userName'] as String).toLowerCase();
                          final userPhone = (chatData['userPhone'] as String).toLowerCase();
                          final localPhone = (chatData['localPhone'] as String).toLowerCase();
                          
                          return userName.contains(_searchQuery) || userPhone.contains(_searchQuery) || localPhone.contains(_searchQuery);
                        }).toList();
          
                        if (filteredChats.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: colorScheme.onSurface.withAlpha((0.4 * 255).toInt()),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No chats found for "$_searchQuery"',
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _navigateToChatbot,
                                  icon: Icon(Icons.smart_toy_rounded, color: colorScheme.secondary),
                                  label: Text(
                                    'Try chatting with AI Assistant',
                                    style: GoogleFonts.poppins(color: colorScheme.secondary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
          
                        return ListView.separated(
                          itemCount: filteredChats.length,
                          separatorBuilder: (_, __) => Divider(
                            color: colorScheme.outline.withAlpha((0.08 * 255).toInt()),
                            height: 0,
                          ),
                          itemBuilder: (context, index) {
                            final chatData = filteredChats[index];
                            return _buildChatListTile(context, chatData, colorScheme, isDark);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  // NEW: Enhanced empty state with chatbot suggestion
  Widget _buildEmptyState(ColorScheme colorScheme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: colorScheme.onSurface.withAlpha((0.4 * 255).toInt()),
          ),
          const SizedBox(height: 24),
          Text(
            'No chats yet',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with friends or try our AI assistant',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Start new chat button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.newChat);
                },
                icon: const Icon(Icons.add_comment_rounded),
                label: Text(
                  'New Chat',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Chatbot button
              OutlinedButton.icon(
                onPressed: _navigateToChatbot,
                icon: const Icon(Icons.smart_toy_rounded),
                label: Text(
                  'AI Assistant',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.secondary,
                  side: BorderSide(color: colorScheme.secondary),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String userPic,
    required String displayName,
    required ColorScheme colorScheme,
    required bool userExists,
  }) {
    final isPhone = _isPhoneLike(displayName);
    final hasPhoto = userPic.isNotEmpty;
    final firstChar = (!isPhone && displayName.trim().isNotEmpty)
        ? displayName.trim()[0].toUpperCase()
        : '';

    final showLetter = !hasPhoto && !isPhone && RegExp(r'[A-Z]').hasMatch(firstChar);

    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundImage: hasPhoto ? NetworkImage(userPic) : null,
          child: hasPhoto
              ? null
              : showLetter
                  ? Text(
                      firstChar,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.person, color: colorScheme.primary, size: 26),
        ),
        if (!userExists)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
    );
  }

  // Updated method with contact name synchronization
  Future<List<Map<String, dynamic>>> _buildChatListWithUserData(List<QueryDocumentSnapshot> chats) async {
    final List<Map<String, dynamic>> chatList = [];

    for (final chat in chats) {
      try {
        final data = chat.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != widget.user.uid,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) {
          continue;
        }

        // NEW: Special handling for chatbot
        if (ChatbotModel.isChatbotUser(otherUserId)) {
          final chatbot = ChatbotModel.getChatbotUser();
          chatList.add({
            'chatData': data,
            'otherUserId': otherUserId,
            'userName': chatbot.name,
            'userPhone': chatbot.phoneNumber,
            'localPhone': chatbot.phoneNumber,
            'userPic': chatbot.photoUrl,
            'registeredName': chatbot.name,
            'isContactName': false,
            'userExists': true,
            'isChatbot': true, // NEW: Mark as chatbot
          });
          continue;
        }

        // Get other user's data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        String displayName = 'Unknown';
        String userPhone = '';
        String userPic = '';
        String registeredName = '';
        bool userExists = false;

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final otherUser = UserModel.fromMap(userData);
          userExists = true;
          
          registeredName = otherUser.name;
          userPhone = otherUser.phoneNumber;
          userPic = otherUser.photoUrl;

          // Use contact name resolution
          displayName = _getDisplayName(userPhone, registeredName);
        } else {
          // Handle testing numbers or users without Firestore documents
          userExists = false;
          userPhone = otherUserId;
          displayName = _getDisplayName(userPhone, '');
        }

        chatList.add({
          'chatData': data,
          'otherUserId': otherUserId,
          'userName': displayName,
          'userPhone': userPhone,
          'localPhone': PhoneUtils.toLocalNumber(userPhone),
          'userPic': userPic,
          'registeredName': registeredName,
          'isContactName': _hasContactName(userPhone),
          'userExists': userExists,
          'isChatbot': false, // Regular user
        });
      } catch (e) {
        continue;
      }
    }
    return chatList;
  }

  Widget _buildChatListTile(BuildContext context, Map<String, dynamic> chatData, ColorScheme colorScheme, bool isDark) {
    final data = chatData['chatData'] as Map<String, dynamic>;
    final otherUserId = chatData['otherUserId'] as String;
    final userName = chatData['userName'] as String;
    final userPhone = chatData['userPhone'] as String;
    final userPic = chatData['userPic'] as String;
    final userExists = chatData['userExists'] as bool? ?? true;
    final isChatbot = chatData['isChatbot'] as bool? ?? false; // NEW: Check if chatbot

    final lastMessage = data['lastMessage']?.toString().trim() ?? '';
    final displayMessage = lastMessage.isEmpty ? 'Tap to start conversation' : lastMessage;
    
    final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
    final unreadCount = data['unreadCounts']?[widget.user.uid]?.toString() ?? '';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface.withAlpha(isDark ? (0.55 * 255).toInt() : (0.85 * 255).toInt()),
      child: ListTile(
        leading: isChatbot 
            ? CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: colorScheme.secondary,
                  size: 28,
                ),
              )
            : _buildAvatar(
                userPic: userPic,
                displayName: userName,
                colorScheme: colorScheme,
                userExists: userExists,
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isChatbot ? colorScheme.secondary : colorScheme.onSurface, // NEW: Special color for chatbot
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // NEW: Show AI badge for chatbot
            if (isChatbot)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
            // Show warning icon for non-registered users
            if (!userExists && !isChatbot)
              Tooltip(
                message: 'User hasn\'t signed up yet',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: lastMessage.isEmpty 
                    ? colorScheme.onSurface.withAlpha((0.5 * 255).toInt())
                    : colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                fontStyle: lastMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
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
                  color: isChatbot ? colorScheme.secondary : colorScheme.primary, // NEW: Different color for chatbot unread
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount,
                  style: GoogleFonts.poppins(
                    color: isChatbot ? colorScheme.onSecondary : colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () async {
          // NEW: Handle chatbot navigation
          if (isChatbot) {
            _navigateToChatbot();
            return;
          }

          if (userExists) {
            // User has Firestore document, navigate normally
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
          } else {
            // User doesn't have Firestore document, create temporary user model
            if (!context.mounted) return;
            final tempUser = UserModel(
              uid: otherUserId,
              phoneNumber: userPhone,
              name: userName,
              bio: '',
              photoUrl: '',
              isOnline: false,
              lastSeen: DateTime.now(),
              groups: [],
              friends: [],
              blockedUsers: [],
            );
            Navigator.pushNamed(
              context,
              AppRoutes.chat,
              arguments: tempUser,
            );
          }
        },
      ),
    );
  }
}