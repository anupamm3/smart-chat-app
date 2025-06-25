import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Groups',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Center(
        child: Text(
          "Group chats will appear here",
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
          ),
        ),
      ),
    );
  }
}