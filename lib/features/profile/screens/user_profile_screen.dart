import 'dart:io' show File;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/models/user_model.dart';
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
      print('Error loading contacts: $e');
    }
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
          .child('$userId.jpg');

      // Upload file
      final uploadTask = await storageRef.putFile(imageFile);
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
          .child('$userId.jpg');
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
      print('Error refreshing profile: $e');
      if (!mounted) return;
      showError(context, 'Failed to refresh profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String aboutText = _currentAbout.isNotEmpty
        ? _currentAbout
        : "Hey there! I am using Smart Chat.";

    // Get display name using ContactService for non-self profiles
    String displayName = _currentName;
    bool hasContactName = false;
    
    if (!isSelf) {
      hasContactName = _contactService.hasContactName(widget.user.phoneNumber, _contactMapping);
    }

    void showProfileImageDialog() {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: _localImage != null
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
        title: Text(
          'Profile',
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
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
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
          child: RefreshIndicator(
            onRefresh: _refreshProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image with tap
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        GestureDetector(
                          onTap: showProfileImageDialog,
                          child: Hero(
                            tag: 'profile_image_${widget.user.uid}',
                            child: CircleAvatar(
                              radius: 75,
                              backgroundImage: _localImage != null
                                  ? FileImage(_localImage!)
                                  : (widget.user.photoUrl.isNotEmpty
                                      ? NetworkImage(widget.user.photoUrl)
                                      : null) as ImageProvider?,
                              backgroundColor: colorScheme.primaryContainer,
                              child: (_localImage == null && widget.user.photoUrl.isEmpty)
                                  ? Icon(Icons.person, size: 60, color: colorScheme.primary)
                                  : null,
                            ),
                          ),
                        ),
                        if (isSelf && (widget.user.photoUrl.isNotEmpty || _localImage != null))
                          Positioned(
                            top: -2,
                            right: -2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary, // Match your theme
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
                    // Edit button (only for self)
                    if (isSelf)
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
            
                    // Name Section with inline editing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person, color: colorScheme.primary, size: 32),
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
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (isSelf && !_isEditingName && !_isUpdatingName) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isEditingName = true;
                                          _nameController.text = _currentName;
                                        });
                                        // Auto focus after rebuild
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
                              
                              // Content area
                              if (_isEditingName) ...[
                                // Edit mode
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
                                        setState(() {}); // Update counter
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
                                  displayName, // Shows contact name for others, actual name for self
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
            
                    // About Section with inline editing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary, size: 32),
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
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (isSelf && !_isEditingAbout && !_isUpdatingAbout) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isEditingAbout = true;
                                          _aboutController.text = _currentAbout;
                                        });
                                        // Auto focus after rebuild
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
                              
                              // Content area
                              if (_isEditingAbout) ...[
                                // Edit mode
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
                                        setState(() {}); // Update counter
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
                                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
            
                    // Phone Section (read-only)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.call, color: colorScheme.primary, size: 32),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Phone",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              PhoneUtils.formatForDisplay(widget.user.phoneNumber),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}