import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/groups/controller/group_chat_controller.dart';
import 'package:smart_chat_app/models/contact_model.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final groupsAsync = ref.watch(groupListProvider(currentUserId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'Group Chats',
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
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search groups...",
                  hintStyle: GoogleFonts.poppins(
                    color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                  ),
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
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
          child: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (groups) {
              final filteredGroups = _searchQuery.isEmpty
                  ? groups
                  : groups
                      .where((g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();
              return filteredGroups.isEmpty
                  ? Center(
                      child: Text(
                        "No groups found",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: filteredGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return Material(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: CircleAvatar(
                              backgroundImage: group.photoUrl != null && group.photoUrl!.isNotEmpty
                                  ? NetworkImage(group.photoUrl!)
                                  : null,
                              backgroundColor: colorScheme.primaryContainer,
                              child: group.photoUrl == null || group.photoUrl!.isEmpty
                                  ? Icon(Icons.groups, color: colorScheme.primary)
                                  : null,
                            ),
                            title: Text(
                              group.name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              group.lastMessage ?? 'No messages yet',
                              style: GoogleFonts.poppins(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              group.lastMessageTime != null
                                  ? TimeOfDay.fromDateTime(group.lastMessageTime!).format(context)
                                  : '',
                              style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.groupChatRoom,
                                arguments: {
                                  'groupId': group.id,
                                  'groupName': group.name,
                                  'groupPhotoUrl': group.photoUrl,
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Fetch and filter contacts using the modular utility
          final matchedContacts = await fetchMatchedContacts(currentUserId);
          if (!mounted) return;
          // Convert to your ContactModel or pass as needed
          final contacts = matchedContacts.map((mc) {
            // If you have a ContactModel, adapt this mapping
            return ContactModel(
              id: mc.user.uid,
              phoneNumber: mc.user.phoneNumber,
              displayName: mc.contactName ?? mc.user.name,
            );
          }).toList();
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.groupContactPicker,
            arguments: {'contacts': contacts},
          );
          if (!mounted) return;
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Group created!', style: GoogleFonts.poppins())),
            );
          }
        },
        icon: const Icon(Icons.group_add),
        label: Text('Create Group', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }
}