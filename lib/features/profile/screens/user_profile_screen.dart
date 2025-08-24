import 'dart:io' show File;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/models/chatbot_model.dart'; // NEW: Import ChatbotModel
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/services/contact_services.dart';
import 'package:smart_chat_app/utils/contact_utils.dart';
import 'package:smart_chat_app/utils/snackbar_utils.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  File? _localImage;
  final ContactService _contactService = ContactService();
  Map<String, String> _contactMapping = {};
  
  // Edit mode states
  bool _isEditingName = false;
  bool _isEditingAbout = false;
  bool _isUpdatingName = false;
  bool _isUpdatingAbout = false;
  
  // Text controllers
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  
  // Current values (updated after successful save)
  late String _currentName;
  late String _currentAbout;

  // NEW: Chatbot detection
  bool get _isChatbotProfile => ChatbotModel.isChatbotUser(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _currentName = widget.user.name;
    _currentAbout = widget.user.bio;
    _nameController = TextEditingController(text: _currentName);
    _aboutController = TextEditingController(text: _currentAbout);
    if (!isSelf) {
      _loadContacts();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  bool get isSelf {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.user.uid;
  }

  Future<void> _loadContacts() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        _contactMapping = await _contactService.getContactMapping(currentUserId);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Failed to load contacts: ${e.toString()}');
      }
    }
  }

  // NEW: Build chatbot avatar widget
  Widget _buildChatbotAvatar({required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background gradient for extra visual appeal
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary.withAlpha((0.1 * 255).toInt()),
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                ),
              ),
              // Try to use asset image first, fallback to icon
              Image.asset(
                'assets/images/virtualAssistant.png',
                width: radius * 1.4,
                height: radius * 1.4,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to robot icon if image fails to load
                  return Icon(
                    Icons.smart_toy_rounded,
                    size: radius * 1.2,
                    color: Theme.of(context).colorScheme.secondary,
                  );
                },
              ),
              // Optional: Add a subtle border
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withAlpha(77),
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Build regular user avatar
  Widget _buildUserAvatar({required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: _localImage != null
          ? FileImage(_localImage!)
          : (widget.user.photoUrl.isNotEmpty
              ? NetworkImage(widget.user.photoUrl)
              : null) as ImageProvider?,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: (_localImage == null && widget.user.photoUrl.isEmpty)
          ? Icon(Icons.person, size: radius * 0.8, color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }
  
  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() {
      _localImage = imageFile;
    });

    try {
      final userId = widget.user.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(userId)
          .child('profile.jpg');

      // Upload file
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'photoUrl': downloadUrl});

      if (!mounted) return;

      setState(() {});
      showSuccess(context, 'Profile picture updated!');
    } catch (e) {
      showError(context, 'Failed to upload profile picture: $e');
    }
  }

  Future<File?> compressImage(File file) async {
    final targetPath = file.path.replaceFirst('.jpg', '_compressed.jpg');
    final xfile  = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80, 
      minWidth: 600,
      minHeight: 600,
    );
    return xfile != null ? File(xfile.path) : null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      File tempImage = File(picked.path);

      // Compress the image
      final compressed = await compressImage(tempImage);
      if (compressed != null) tempImage = compressed;

      if(!mounted) return;

      // Show confirm dialog
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Profile Picture'),
          content: Image.file(tempImage, height: 180),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (shouldUpload == true) {
        await _uploadProfileImage(tempImage);
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      final userId = widget.user.uid;
      // Remove from Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(userId)
          .child('profile.jpg');
      await storageRef.delete().catchError((_) {});

      // Remove from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'photoUrl': ''});

      if (!mounted) return;
      setState(() {
        _localImage = null;
      });
      showSuccess(context, 'Profile photo removed!');
    } catch (e) {
      if (!mounted) return;
      showError(context, 'Failed to remove profile photo: $e');
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    
    // Validation
    if (newName.isEmpty) {
      showError(context, 'Name cannot be empty');
      return;
    }
    
    if (newName.length < 2) {
      showError(context, 'Name must be at least 2 characters');
      return;
    }
    
    if (newName.length > 50) {
      showError(context, 'Name must be less than 50 characters');
      return;
    }
    
    // Check if value actually changed
    if (newName == _currentName) {
      setState(() {
        _isEditingName = false;
      });
      return;
    }

    setState(() {
      _isUpdatingName = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'name': newName});
      
      setState(() {
        _currentName = newName;
        _isEditingName = false;
        _isUpdatingName = false;
      });
      if (!mounted) return;
      showSuccess(context, 'Name updated successfully');
    } catch (e) {
      setState(() {
        _isUpdatingName = false;
      });
      showError(context, 'Failed to update name: $e');
    }
  }

  Future<void> _updateAbout() async {
    final newAbout = _aboutController.text.trim();
    
    // Validation
    if (newAbout.length > 200) {
      showError(context, 'About must be less than 200 characters');
      return;
    }
    
    // Check if value actually changed
    if (newAbout == _currentAbout) {
      setState(() {
        _isEditingAbout = false;
      });
      return;
    }

    setState(() {
      _isUpdatingAbout = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'bio': newAbout});
      
      setState(() {
        _currentAbout = newAbout;
        _isEditingAbout = false;
        _isUpdatingAbout = false;
      });
      if (!mounted) return;
      showSuccess(context, 'About updated successfully');
    } catch (e) {
      setState(() {
        _isUpdatingAbout = false;
      });
      showError(context, 'Failed to update about: $e');
    }
  }

  void _cancelNameEdit() {
    setState(() {
      _nameController.text = _currentName;
      _isEditingName = false;
    });
  }

  void _cancelAboutEdit() {
    setState(() {
      _aboutController.text = _currentAbout;
      _isEditingAbout = false;
    });
  }

  Future<void> _refreshProfile() async {
    try {
      // Refresh user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      
      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final updatedUser = UserModel.fromMap(userData);
        
        setState(() {
          _currentName = updatedUser.name;
          _currentAbout = updatedUser.bio;
          _nameController.text = _currentName;
          _aboutController.text = _currentAbout;
        });
      }
      
      // Refresh contacts if viewing someone else's profile
      if (!isSelf) {
        await _loadContacts();
      }
    } catch (e) {
      debugPrint('Error refreshing profile: $e');
      if (!mounted) return;
      showError(context, 'Failed to refresh profile');
    }
  }

  void showProfileImageDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _isChatbotProfile
              ? Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(150),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/virtualAssistant.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.smart_toy_rounded,
                            size: 150,
                            color: colorScheme.secondary,
                          );
                        },
                      ),
                    ],
                  ),
                )
              : _localImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_localImage!, fit: BoxFit.contain),
                    )
                  : widget.user.photoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(widget.user.photoUrl, fit: BoxFit.contain),
                        )
                      : Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(90),
                          ),
                          child: Icon(Icons.person, size: 120, color: colorScheme.primary),
                        ),
        );
      },
    );
  }

  Widget _buildProfileContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final String aboutText = _isChatbotProfile 
        ? "🤖 I'm your AI assistant powered by Gemini! I can help you with questions, creative tasks, problem-solving, and friendly conversation. Ask me anything!"
        : (_currentAbout.isNotEmpty ? _currentAbout : "Hey there! I am using Smart Chat.");

    String displayName = _currentName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Image with tap - UPDATED
          Stack(
            alignment: Alignment.topRight,
            children: [
              GestureDetector(
                onTap: showProfileImageDialog,
                child: Hero(
                  tag: 'profile_image_${widget.user.uid}',
                  child: _isChatbotProfile
                      ? _buildChatbotAvatar(radius: 75)
                      : _buildUserAvatar(radius: 75),
                ),
              ),
              // NEW: Hide edit/remove buttons for chatbot
              if (isSelf && !_isChatbotProfile && (widget.user.photoUrl.isNotEmpty || _localImage != null))
                Positioned(
                  top: -2,
                  right: -2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(32, 32),
                      elevation: 1,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Remove Profile Photo'),
                          content: const Text('Are you sure you want to remove your profile photo?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _removeProfilePhoto();
                      }
                    },
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          // Edit button (only for self and not chatbot) - UPDATED
          if (isSelf && !_isChatbotProfile)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 1,
                  ),
                  label: Text(
                    "Edit Photo",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _pickImage,
                ),
              ),
            )
          else
            const SizedBox(height: 36),
  
          // Name Section with inline editing - UPDATED
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isChatbotProfile ? Icons.smart_toy_rounded : Icons.person, 
                color: _isChatbotProfile ? colorScheme.secondary : colorScheme.primary, 
                size: 32
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Name",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: _isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface,
                          ),
                        ),
                        // NEW: Hide edit for chatbot
                        if (isSelf && !_isChatbotProfile && !_isEditingName && !_isUpdatingName) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEditingName = true;
                                _nameController.text = _currentName;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  FocusScope.of(context).requestFocus(FocusNode());
                                }
                              });
                            },
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: colorScheme.primary.withAlpha((0.7 * 255).toInt()),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Content area - UPDATED
                    if (_isEditingName && !_isChatbotProfile) ...[
                      // Edit mode (hidden for chatbot)
                      Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            enabled: !_isUpdatingName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              hintText: 'Enter your name',
                              hintStyle: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                              ),
                              counterText: '${_nameController.text.length}/50',
                              counterStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                            maxLength: 50,
                            onSubmitted: (_) => _updateName(),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_isUpdatingName)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                )
                              else ...[
                                GestureDetector(
                                  onTap: _cancelNameEdit,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.outline.withAlpha((0.2 * 255).toInt()),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _updateName,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Save',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      // Display mode
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: (_isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface).withAlpha((0.8 * 255).toInt()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
  
          // About Section with inline editing - UPDATED
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline, 
                color: _isChatbotProfile ? colorScheme.secondary : colorScheme.primary, 
                size: 32
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "About",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: _isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface,
                          ),
                        ),
                        // NEW: Hide edit for chatbot
                        if (isSelf && !_isChatbotProfile && !_isEditingAbout && !_isUpdatingAbout) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEditingAbout = true;
                                _aboutController.text = _currentAbout;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  FocusScope.of(context).requestFocus(FocusNode());
                                }
                              });
                            },
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: colorScheme.primary.withAlpha((0.7 * 255).toInt()),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Content area - UPDATED
                    if (_isEditingAbout && !_isChatbotProfile) ...[
                      // Edit mode (hidden for chatbot)
                      Column(
                        children: [
                          TextField(
                            controller: _aboutController,
                            autofocus: true,
                            enabled: !_isUpdatingAbout,
                            maxLines: 3,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                              hintText: 'Hey there! I am using Smart Chat.',
                              hintStyle: GoogleFonts.poppins(
                                color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                              ),
                              counterText: '${_aboutController.text.length}/200',
                              counterStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                            maxLength: 200,
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_isUpdatingAbout)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                )
                              else ...[
                                GestureDetector(
                                  onTap: _cancelAboutEdit,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.outline.withAlpha((0.2 * 255).toInt()),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _updateAbout,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Save',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      // Display mode
                      Text(
                        aboutText,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: (_isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface).withAlpha((0.8 * 255).toInt()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
  
          // Phone Section (read-only) - UPDATED
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isChatbotProfile ? Icons.computer : Icons.call, 
                color: _isChatbotProfile ? colorScheme.secondary : colorScheme.primary, 
                size: 32
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isChatbotProfile ? "Type" : "Phone",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isChatbotProfile 
                        ? "AI Assistant • Powered by Gemini" 
                        : PhoneUtils.formatForDisplay(widget.user.phoneNumber),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: (_isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface).withAlpha((0.8 * 255).toInt()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
        title: Text(
          _isChatbotProfile ? 'AI Assistant Profile' : 'Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _isChatbotProfile ? colorScheme.secondary : colorScheme.onSurface,
          ),
        ),
        // NEW: Hide settings for chatbot profile
        actions: _isChatbotProfile 
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
            : [
                IconButton(
                  icon: Icon(Icons.settings, color: colorScheme.onSurface),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                ),
              ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    _isChatbotProfile ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest,
                    colorScheme.surface,
                    _isChatbotProfile ? colorScheme.secondaryContainer : colorScheme.primaryContainer
                  ]
                : [
                    _isChatbotProfile ? colorScheme.secondaryContainer : colorScheme.primaryContainer,
                    colorScheme.surface,
                    _isChatbotProfile ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isSelf
              ? RefreshIndicator(
                  onRefresh: _refreshProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _buildProfileContent(),
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _buildProfileContent(),
                ),
        ),
      ),
    );
  }
}