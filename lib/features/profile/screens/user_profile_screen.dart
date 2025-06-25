import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileScreen extends StatelessWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  bool get isSelf {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == user.uid;
  }

  String get maskedPhone {
    if (user.phoneNumber.length < 6) return user.phoneNumber;
    // Mask all but last 4 digits
    return user.phoneNumber.replaceRange(0, user.phoneNumber.length - 4, '*' * (user.phoneNumber.length - 4));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String statusText = (user.status ?? '').toString();
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                backgroundColor: colorScheme.primaryContainer,
                child: user.photoUrl.isEmpty
                    ? Icon(Icons.person, size: 56, color: colorScheme.primary)
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                user.name.isNotEmpty ? user.name : user.phoneNumber,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                maskedPhone,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (statusText.isNotEmpty)
                Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt()),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (!isSelf) ...[
                const SizedBox(height: 32),
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
                    Navigator.pop(context, user); // Or navigate to chat screen directly
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}