import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/models/user_model.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;
  int _seconds = 60;
  Timer? _timer;
  String? verificationId;
  String? phone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    verificationId = args?['verificationId'];
    phone = args?['phone'];
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  String get _otpCode =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _verifyOtp() async {
    HapticFeedback.lightImpact();
    if (_otpCode.length != 6 || _otpCode.contains(RegExp(r'[^0-9]'))) {
      setState(() => _error = "Please enter the 6-digit code.");
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: _otpCode,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        // Save user to Firestore if not exists
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          final userModel = UserModel(
            uid: user.uid,
            phoneNumber: user.phoneNumber ?? '',
            name: user.phoneNumber ?? '', // Default to phone, prompt for name later
            bio: '',
            photoUrl: '',
            isOnline: true,
            lastSeen: DateTime.now(),
            groups: [],
            friends: [],
            blockedUsers: [],
          );
          await userDoc.set(userModel.toMap());
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
        }
      } else {
        setState(() => _error = "Verification failed. Try again.");
      }
    } catch (e) {
      debugPrint('OTP verification error: $e');
      setState(() {
        _isLoading = false;
        _error = "Invalid code or verification failed.";
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resendOtp() async {
    if (phone == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone!,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          _error = e.message ?? "Verification failed";
        });
      },
      codeSent: (String newVerificationId, int? resendToken) {
        setState(() {
          verificationId = newVerificationId;
          _isLoading = false;
        });
        _startTimer();
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
      codeAutoRetrievalTimeout: (_) {
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _buildOtpFields(ColorScheme colorScheme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 44,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNodes[i].hasFocus
                  ? colorScheme.primary
                  : colorScheme.outline.withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.outline.withAlpha((0.06 * 255).toInt()),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            enabled: !_isLoading,
            textInputAction: i < 5 ? TextInputAction.next : TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (val) {
              // Handle paste
              if (val.length > 1) {
                final chars = val.split('');
                for (int j = 0; j < 6; j++) {
                  _controllers[j].text = (j < chars.length) ? chars[j] : '';
                }
                _focusNodes[5].requestFocus();
                return;
              }
              // Forward typing
              if (val.isNotEmpty) {
                _controllers[i].text = val[val.length - 1];
                if (i < 5) {
                  _focusNodes[i + 1].requestFocus();
                } else {
                  _focusNodes[i].unfocus();
                }
                _controllers[i].selection = TextSelection.fromPosition(
                  TextPosition(offset: _controllers[i].text.length),
                );
              }
              // Backspace: if field is empty and not first, move focus back
              else if (val.isEmpty && i > 0) {
                _focusNodes[i - 1].requestFocus();
                _controllers[i - 1].selection = TextSelection.fromPosition(
                  TextPosition(offset: _controllers[i - 1].text.length),
                );
              }
            },
            onTap: () {
              _controllers[i].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllers[i].text.length,
              );
            },
            onSubmitted: (_) {
              if (i == 5) _verifyOtp();
            },
            onEditingComplete: () {},
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  const SizedBox(height: 24),
                  Text(
                    "Verify your phone number",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Enter the 6-digit code sent to ${phone ?? ''}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // OTP input fields with animation and improved UX
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: !_isLoading ? 1.0 : 0.5,
                    child: _buildOtpFields(colorScheme, isDark),
                  ),
                  const SizedBox(height: 18),
                  // Timer or resend
                  _seconds > 0
                      ? Text(
                          "Resend code in 00:${_seconds.toString().padLeft(2, '0')}",
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                          ),
                        )
                      : TextButton(
                          onPressed: _isLoading ? null : _resendOtp,
                          child: Text(
                            "Resend OTP",
                            style: GoogleFonts.poppins(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
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
                  // Verify button with animation
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: !_isLoading ? 1.0 : 0.5,
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
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Verify"),
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