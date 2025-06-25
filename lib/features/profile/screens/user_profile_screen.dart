import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  File? _localImage;
  
  bool get isSelf {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.user.uid;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _localImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String statusText = (widget.user.status ?? "Hey there! I am using Smart Chat.").toString();
    final String username = widget.user.name; // Replace with actual username if available

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

    // Phone formatting: "+91 1234567890" -> "+91 1234567890"
    String formattedPhone(String phone) {
      if (phone.startsWith('+') && phone.length > 3) {
        final cc = phone.substring(0, 3);
        final rest = phone.substring(3);
        return '$cc $rest';
      }
      return phone;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surface,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Image with tap
                  GestureDetector(
                    onTap: showProfileImageDialog,
                    child: Hero(
                      tag: 'profile_image_${widget.user.uid}',
                      child: CircleAvatar(
                        radius: 60,
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
                          icon: const Icon(Icons.edit),
                          label: Text(
                            "Edit",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _pickImage(),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 36),
                  // First row: Person icon, Name & Username
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person, color: colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Name",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Second row: Info icon, About & Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "About",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Third row: Call icon, Phone & Number
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
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedPhone(widget.user.phoneNumber),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 36),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        "Start Chat",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, widget.user); // Or navigate to chat screen directly
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}