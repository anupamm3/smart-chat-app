import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';
import 'package:smart_chat_app/utils/contact_utils.dart'; // Add this import

class ChatsTab extends StatefulWidget {
  final User user;
  const ChatsTab({super.key, required this.user});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ContactService _contactService = ContactService();
  
  // Add these new variables for contact synchronization
  Map<String, String> _contactMapping = {};
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      _contactMapping = await _contactService.getContactMapping(widget.user.uid);
      setState(() => _contactsLoaded = true);
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() => _contactsLoaded = true);
    }
  }

  // Simplified methods using ContactService
  String _getDisplayName(String phoneNumber, String registeredName) {
    return _contactService.getDisplayName(phoneNumber, registeredName, _contactMapping);
  }

  bool _hasContactName(String phoneNumber) {
    return _contactService.hasContactName(phoneNumber, _contactMapping);
  }

  String _getInitials(String displayName, String phoneNumber) {
    return _contactService.getInitials(displayName, phoneNumber);
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
          'SmartChat',
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
                      return Center(
                        child: Text(
                          'No chats yet',
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                          ),
                        ),
                      );
                    }
          
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _buildChatListWithUserData(snapshot.data!.docs),
                      builder: (context, chatListSnapshot) {
                        if (chatListSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
          
                        if (!chatListSnapshot.hasData || chatListSnapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              'No chats yet',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                              ),
                            ),
                          );
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
                            child: Text(
                              _searchQuery.isEmpty ? 'No chats yet' : 'No chats found for "$_searchQuery"',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                              ),
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
          print('Skipping chat ${chat.id} - no other user found');
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
          userPhone = otherUser.phoneNumber; // Full international number
          userPic = otherUser.photoUrl;

          // Use contact name resolution
          displayName = _getDisplayName(userPhone, registeredName);
        } else {
          // Handle testing numbers or users without Firestore documents
          print('No user document for $otherUserId - treating as phone number');
          userExists = false;
          userPhone = otherUserId;
          displayName = _getDisplayName(userPhone, '');
        }

        print('Adding chat ${chat.id} with user: $displayName ($otherUserId) [exists: $userExists]');

        chatList.add({
          'chatData': data,
          'otherUserId': otherUserId,
          'userName': displayName, // Now uses contact name if available
          'userPhone': userPhone,
          'localPhone': PhoneUtils.toLocalNumber(userPhone), // Add local phone for search
          'userPic': userPic,
          'registeredName': registeredName,
          'isContactName': _hasContactName(userPhone),
          'userExists': userExists,
        });
      } catch (e) {
        print('Error processing chat ${chat.id}: $e');
        continue;
      }
    }

    print('Total chats processed: ${chatList.length}');
    return chatList;
  }

  Widget _buildChatListTile(BuildContext context, Map<String, dynamic> chatData, ColorScheme colorScheme, bool isDark) {
    final data = chatData['chatData'] as Map<String, dynamic>;
    final otherUserId = chatData['otherUserId'] as String;
    final userName = chatData['userName'] as String;
    final userPhone = chatData['userPhone'] as String;
    final localPhone = chatData['localPhone'] as String;
    final userPic = chatData['userPic'] as String;
    final isContactName = chatData['isContactName'] as bool? ?? false;
    final userExists = chatData['userExists'] as bool? ?? true;

    final lastMessage = data['lastMessage']?.toString().trim() ?? '';
    final displayMessage = lastMessage.isEmpty ? 'Tap to start conversation' : lastMessage;
    
    final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
    final unreadCount = data['unreadCounts']?[widget.user.uid]?.toString() ?? '';

    final initials = _getInitials(userName, userPhone);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface.withAlpha(isDark ? (0.55 * 255).toInt() : (0.85 * 255).toInt()),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: userPic.isNotEmpty ? NetworkImage(userPic) : null,
              backgroundColor: colorScheme.primaryContainer,
              child: userPic.isEmpty
                  ? Text(
                      initials,
                      style: GoogleFonts.poppins(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            // Show indicator for users without Firestore document
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
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Show warning icon for non-registered users
            if (!userExists)
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