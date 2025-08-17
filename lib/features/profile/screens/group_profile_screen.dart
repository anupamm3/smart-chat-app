import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/utils/snackbar_utils.dart';

class GroupProfileScreen extends StatefulWidget {
  final String groupId;

  const GroupProfileScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends State<GroupProfileScreen> {
  // Group data
  String _groupName = '';
  String _groupPhotoUrl = '';
  String _creatorId = '';
  List<String> _memberIds = [];
  List<UserModel> _members = [];
  DateTime? _createdAt;
  
  // Loading states
  bool _isLoadingGroup = true;
  bool _isLoadingMembers = true;
  
  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    try {
      // Load group information
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (groupDoc.exists && mounted) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _groupName = groupData['name'] ?? 'Unnamed Group';
          _groupPhotoUrl = groupData['photoUrl'] ?? '';
          _creatorId = groupData['createdBy'] ?? '';
          _memberIds = List<String>.from(groupData['members'] ?? []);
          
          if (groupData['createdAt'] != null) {
            _createdAt = (groupData['createdAt'] as Timestamp).toDate();
          }
          
          _isLoadingGroup = false;
        });

        // Load member details
        await _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroup = false;
          _isLoadingMembers = false;
        });
        showError(context, 'Failed to load group information');
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_memberIds.isEmpty) {
      setState(() => _isLoadingMembers = false);
      return;
    }

    try {
      final List<UserModel> loadedMembers = [];
      
      // Load members in batches to avoid Firestore limitations
      for (int i = 0; i < _memberIds.length; i += 10) {
        final batch = _memberIds.skip(i).take(10).toList();
        
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', whereIn: batch)
            .get();

        for (final doc in usersQuery.docs) {
          try {
            final user = UserModel.fromMap(doc.data());
            loadedMembers.add(user);
          } catch (e) {
            debugPrint('Error parsing user ${doc.id}: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _members = loadedMembers;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
        showError(context, 'Failed to load group members');
      }
    }
  }

  Future<void> _refreshGroupData() async {
    setState(() {
      _isLoadingGroup = true;
      _isLoadingMembers = true;
    });
    await _loadGroupData();
  }

  void _navigateToUserProfile(UserModel user) {
    Navigator.pushNamed(
      context,
      AppRoutes.userProfile,
      arguments: user,
    );
  }

  Widget _buildGroupAvatar({required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: _groupPhotoUrl.isNotEmpty
          ? NetworkImage(_groupPhotoUrl)
          : null,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: _groupPhotoUrl.isEmpty
          ? Icon(
              Icons.groups,
              size: radius * 0.8,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildMemberTile(UserModel member) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCreator = member.uid == _creatorId;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = member.uid == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: () => _navigateToUserProfile(member),
          child: Hero(
            tag: 'profile_image_${member.uid}',
            child: CircleAvatar(
              radius: 24,
              backgroundImage: member.photoUrl.isNotEmpty
                  ? NetworkImage(member.photoUrl)
                  : null,
              backgroundColor: colorScheme.primaryContainer,
              child: member.photoUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 20,
                      color: colorScheme.primary,
                    )
                  : null,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                isCurrentUser ? '${member.name} (You)' : member.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: member.bio.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  member.bio,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: colorScheme.outline,
        ),
        onTap: () => _navigateToUserProfile(member),
      ),
    );
  }

  void _showGroupImageDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _groupPhotoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(_groupPhotoUrl, fit: BoxFit.contain),
                )
              : Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(90),
                  ),
                  child: Icon(
                    Icons.groups,
                    size: 120,
                    color: colorScheme.primary,
                  ),
                ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return 'Created on ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingGroup) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Group Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'Group Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
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
                    colorScheme.primaryContainer,
                  ]
                : [
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Group Image
                  GestureDetector(
                    onTap: _showGroupImageDialog,
                    child: Hero(
                      tag: 'group_image_${widget.groupId}',
                      child: _buildGroupAvatar(radius: 75),
                    ),
                  ),
                  const SizedBox(height: 24),
          
                  // Group Name Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.groups,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Group Name",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _groupName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
          
                  // Group Info Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Group Info",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_members.length} members',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                            if (_createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatDate(_createdAt!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
          
                  // Members Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.people,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Members",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_members.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
          
                            // Members List
                            if (_isLoadingMembers)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_members.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No members found',
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: _members
                                    .map((member) => _buildMemberTile(member))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}