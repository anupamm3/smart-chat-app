import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _loading = true;
  List<UserModel> _matchedUsers = [];
  final ContactService _contactService = ContactService();
  Map<String, String> _contactMapping = {};
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _fetchContactsAndUsers();
  }

  Future<void> _fetchContactsAndUsers() async {
    if (_currentUserId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      // Get contacts and mapping from service
      final matchedContacts = await fetchMatchedContacts(_currentUserId);
      _contactMapping = await _contactService.getContactMapping(_currentUserId);
      
      setState(() {
        _matchedUsers = matchedContacts.map((mc) => mc.user).toList();
        _loading = false;
      });

    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // Simplified methods using ContactService
  String _getDisplayName(UserModel user) {
    return _contactService.getDisplayName(user.phoneNumber, user.name, _contactMapping);
  }

  bool _hasContactName(UserModel user) {
    return _contactService.hasContactName(user.phoneNumber, _contactMapping);
  }

  String _getInitials(UserModel user) {
    final displayName = _getDisplayName(user);
    return _contactService.getInitials(displayName, user.phoneNumber);
  }

  List<UserModel> get _filteredUsers {
    return _contactService.filterUsers(_matchedUsers, _search, _contactMapping);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'Start New Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          "Invite",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Invite feature coming soon!",
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _fetchContactsAndUsers,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val),
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Search contacts...",
                    hintStyle: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                    ),
                    prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                            ),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceBright.withAlpha((0.45 * 255).toInt()),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? colorScheme.outline.withAlpha(120)
                            : colorScheme.primary.withAlpha(120),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? colorScheme.outline.withAlpha(120)
                            : colorScheme.primary.withAlpha(120),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Contact list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? _buildEmptyState(colorScheme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildContactTile(context, user, colorScheme, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _search.isNotEmpty ? Icons.search_off : Icons.person_off_outlined,
            size: 64,
            color: colorScheme.primary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty 
                ? "No contacts found for \"$_search\""
                : "No contacts found using SmartChat",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _search.isNotEmpty
                ? "Try searching with a different name or number"
                : "Invite your friends to join SmartChat",
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, UserModel user, ColorScheme colorScheme, bool isDark) {
    final displayName = _getDisplayName(user);
    final hasContactName = _hasContactName(user);
    final initials = _getInitials(user);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withAlpha(isDark ? (0.18 * 255).toInt() : (0.10 * 255).toInt()),
          width: 1,
        ),
      ),
      color: isDark
        ? colorScheme.surfaceContainerLow.withAlpha((0.9 * 255).toInt())
        : colorScheme.surfaceContainerLow.withAlpha((0.95 * 255).toInt()),
      shadowColor: colorScheme.primary.withAlpha((0.15 * 255).toInt()),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 26,
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          backgroundColor: colorScheme.primaryContainer,
          child: user.photoUrl.isEmpty
              ? Text(
                  initials,
                  style: GoogleFonts.poppins(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show contact status
            Text(
              hasContactName ? "In your contacts" : "SmartChat user",
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                fontSize: 12,
              ),
            ),
            // Show phone number if searching and it matches
            if (_search.isNotEmpty && (user.localPhoneNumber.contains(_search.toLowerCase()) || user.displayPhoneNumber.toLowerCase().contains(_search.toLowerCase())))
              Text(
                user.displayPhoneNumber,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        onTap: () => _startChat(user),
      ),
    );
  }

  void _startChat(UserModel user) {
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: user,
    );
  }
}