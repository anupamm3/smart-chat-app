import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: Colors.red[600],
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: Colors.green[600],
      behavior: SnackBarBehavior.floating,
    ),
  );
}