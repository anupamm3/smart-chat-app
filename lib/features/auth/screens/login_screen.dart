import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phoneController = TextEditingController();
  final smsController = TextEditingController();
  String? verificationId;
  String error = '';
  String countryCode = '+91'; // Default country code

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider.select((state) => state.isLoading));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [colorScheme.surfaceContainerHighest, colorScheme.surface, colorScheme.primaryContainer]
                : [colorScheme.primaryContainer, colorScheme.surface, colorScheme.surfaceContainerHighest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: size.height * 0.98,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to SmartChat',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chat smarter. Schedule. Connect. Enjoy.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 400),
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withAlpha((isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt())),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.08),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
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
                                  icon: Image.asset(
                                    'assets/icons/google-icon.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.login),
                                  ),
                                  label: const Text('Sign in with Google'),
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          final success = await ref.read(authControllerProvider.notifier).signInWithGoogle();
                                          if (success && context.mounted) {
                                            Navigator.pushReplacementNamed(context, '/home');
                                          }
                                        },
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: colorScheme.outline.withValues(alpha: 0.3),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: colorScheme.outline.withValues(alpha: 0.3),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                if (verificationId == null) ...[
                                  Row(
                                    children: [
                                      // Simple country code picker (expand with a package if needed)
                                      DropdownButton<String>(
                                        value: countryCode,
                                        borderRadius: BorderRadius.circular(12),
                                        style: GoogleFonts.poppins(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        underline: Container(),
                                        items: const [
                                          DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                                          DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                                          DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61')),
                                        ],
                                        onChanged: isLoading
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  countryCode = val ?? '+91';
                                                });
                                              },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: GoogleFonts.poppins(),
                                          decoration: InputDecoration(
                                            labelText: 'Phone Number',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                      elevation: 0,
                                    ),
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            ref.read(authControllerProvider.notifier).signInWithPhone(
                                              phoneNumber: '$countryCode${phoneController.text.trim()}',
                                              codeSent: (vId) {
                                                setState(() {
                                                  verificationId = vId;
                                                  error = '';
                                                });
                                              },
                                              onError: (err) {
                                                setState(() {
                                                  error = err;
                                                });
                                              },
                                            );
                                          },
                                    child: const Text('Continue with Phone'),
                                  ),
                                ] else ...[
                                  TextFormField(
                                    controller: smsController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.poppins(),
                                    decoration: InputDecoration(
                                      labelText: 'Enter SMS Code',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                      elevation: 0,
                                    ),
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            final success = await ref.read(authControllerProvider.notifier).verifySmsCode(
                                              verificationId: verificationId!,
                                              smsCode: smsController.text.trim(),
                                            );
                                            if (success && context.mounted) {
                                              Navigator.pushReplacementNamed(context, '/home');
                                            } else {
                                              setState(() {
                                                error = 'Invalid code';
                                              });
                                            }
                                          },
                                    child: const Text('Verify Code'),
                                  ),
                                ],
                                if (isLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                if (error.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      error,
                                      style: GoogleFonts.poppins(
                                        color: colorScheme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}