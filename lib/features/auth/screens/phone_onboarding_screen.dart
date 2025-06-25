import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
  bool _showInput = false; // For animation

  @override
  void initState() {
    super.initState();
    // Delay to trigger animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showInput = true);
    });
  }

  void _sendOtp() async {
    HapticFeedback.lightImpact(); // Haptic feedback on button press
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
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Terms of Service"),
                                  content: const Text(
                                    "Welcome to SmartChat!\n\n"
                                    "By using this application, you agree to the following terms:\n\n"
                                    "1. You are solely responsible for the messages you send and receive.\n"
                                    "2. Do not use this app for any illegal, abusive, or harmful purposes.\n"
                                    "3. Your phone number will be used to create a user identity for communication.\n"
                                    "4. SmartChat does not share your data with third parties.\n"
                                    "5. The app may require access to contacts or media for future features (with your consent).\n"
                                    "6. Continued use of the app means you accept updates to these terms.\n\n"
                                    "If you do not agree with these terms, please do not use the app.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text("Close"),
                                    ),
                                  ],
                                ),
                              );
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
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Privacy Policy"),
                                  content: const SingleChildScrollView(
                                    child: Text(
                                      "Privacy Policy for SmartChat\n\n"
                                      "SmartChat respects your privacy and is committed to protecting your personal information. This Privacy Policy outlines how we handle your data:\n\n"
                                      "1. Information We Collect:\n"
                                      "   - Your phone number for authentication and account creation.\n"
                                      "   - Basic user data like name and profile picture if you choose to provide it.\n"
                                      "   - Messages you send and receive are stored securely in Firebase.\n\n"
                                      "2. How We Use Your Information:\n"
                                      "   - To provide and improve messaging functionality.\n"
                                      "   - To personalize your experience within the app.\n"
                                      "   - To enhance app security and user authenticity.\n\n"
                                      "3. Data Sharing:\n"
                                      "   - We do not sell or share your personal data with third parties.\n"
                                      "   - Your data is stored securely in Firebase services provided by Google.\n\n"
                                      "4. Security:\n"
                                      "   - SmartChat uses Firebase Authentication and Firestore with security rules to protect user data.\n"
                                      "   - All communication is encrypted via HTTPS.\n\n"
                                      "5. Permissions:\n"
                                      "   - The app may request access to contacts or media (with your explicit permission) for enhanced features.\n\n"
                                      "6. Updates:\n"
                                      "   - We may update this policy from time to time. Continued use of the app indicates acceptance of the latest version.\n\n"
                                      "If you have any questions or concerns about this policy, please contact us.\n\n"
                                      "Last updated: June 2025",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text("Close"),
                                    ),
                                  ],
                                ),
                              );
                            },
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Phone input container
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showInput ? 1.0 : 0.0,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      transform: _showInput
                          ? Matrix4.identity()
                          : Matrix4.translationValues(0, 40, 0),
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
                      child: IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'IN',
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (phone) {
                          setState(() {
                            _countryCode = phone.countryCode;
                          });
                        },
                        enabled: !isLoading,
                      ),
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
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _showInput ? 1.0 : 0.0,
                    child: SizedBox(
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