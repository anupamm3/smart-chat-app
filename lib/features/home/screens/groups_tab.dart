import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/features/groups/controller/group_chat_controller.dart';
import 'package:smart_chat_app/models/contact_model.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';

class GroupsTab extends ConsumerStatefulWidget {
  const GroupsTab({super.key});

  @override
  ConsumerState<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<GroupsTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final groupsAsync = ref.watch(groupListProvider(currentUserId));

    return GradientScaffold(
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
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search groups...",
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
                style: GoogleFonts.poppins(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.group_add),
        label: Text(
          'Create Group',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        onPressed: () async {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final matchedContacts = await fetchMatchedContacts(currentUserId);
          if (!mounted) return;
          final contacts = matchedContacts.map((mc) {
            return ContactModel(
              id: mc.user.uid,
              phoneNumber: mc.user.phoneNumber,
              displayName: mc.contactName ?? mc.user.name,
            );
          }).toList();
          final result = await navigator.pushNamed(
            AppRoutes.groupContactPicker,
            arguments: {'contacts': contacts},
          );
          if (!mounted) return;
          if (result == true) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Group created!', style: GoogleFonts.poppins())),
            );
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                'Error: $e',
                style: GoogleFonts.poppins(
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                ),
              ),
            ),
            data: (groups) {
              final filteredGroups = _searchQuery.isEmpty
                  ? groups
                  : groups
                      .where((g) => g.name.toLowerCase().contains(_searchQuery))
                      .toList();
              if (filteredGroups.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No groups yet' : 'No groups found for "$_searchQuery"',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: filteredGroups.length,
                itemBuilder: (context, index) {
                  final group = filteredGroups[index];
                  return _buildGroupListTile(context, group, colorScheme, isDark);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGroupListTile(BuildContext context, dynamic group, ColorScheme colorScheme, bool isDark) {
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
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show member count if searching and group name matches
            if (_searchQuery.isNotEmpty && group.name.toLowerCase().contains(_searchQuery))
              Text(
                '${group.members?.length ?? 0} members',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            Text(
              group.lastMessage ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (group.lastMessageTime != null)
              Text(
                "${group.lastMessageTime!.hour.toString().padLeft(2, '0')}:${group.lastMessageTime!.minute.toString().padLeft(2, '0')}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.groupChat,
            arguments: {
              'groupId': group.id,
              'groupName': group.name,
              'groupPhotoUrl': group.photoUrl,
            },
          );
        },
      ),
    );
  }
}