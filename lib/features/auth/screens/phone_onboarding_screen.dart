import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_chat_app/features/auth/controller/auth_controller.dart';

class PhoneOnboardingScreen extends ConsumerStatefulWidget {
  const PhoneOnboardingScreen({super.key});

  @override
  ConsumerState<PhoneOnboardingScreen> createState() => _PhoneOnboardingScreenState();
}

class _PhoneOnboardingScreenState extends ConsumerState<PhoneOnboardingScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = '+91';
  String? _error;

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 7) {
      setState(() => _error = "Please enter a valid phone number.");
      return;
    }
    setState(() {
      _error = null;
    });

    ref.read(authControllerProvider.notifier).signInWithPhone(
      phoneNumber: '$_countryCode$phone',
      codeSent: (verificationId) {
        Navigator.pushNamed(context, '/otp', arguments: {
          'verificationId': verificationId,
          'phone': '$_countryCode$phone',
        });
      },
      onError: (err) {
        setState(() => _error = err);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App name/logo
                  const SizedBox(height: 24),
                  Icon(Icons.chat_bubble_rounded, size: 64, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    "SmartChat",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // T&C message
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: "By tapping 'Continue', you agree to our "),
                        TextSpan(
                          text: "Terms of Service",
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Show Terms of Service
                            },
                        ),
                        const TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Show Privacy Policy
                            },
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Phone input container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.outline.withAlpha((0.08 * 255).toInt()),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Simple custom country code picker
                        DropdownButton<String>(
                          value: _countryCode,
                          borderRadius: BorderRadius.circular(12),
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                            DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                            DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                            DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61')),
                          ],
                          onChanged: isLoading
                              ? null
                              : (val) {
                                  setState(() {
                                    _countryCode = val ?? '+91';
                                  });
                                },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: "Enter your phone number",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            enabled: !isLoading,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        elevation: 0,
                      ),
                      onPressed: isLoading ? null : _sendOtp,
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Continue"),
                    ),
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