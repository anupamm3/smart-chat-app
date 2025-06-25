import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
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

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
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
        smsCode: code,
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
            name: user.phoneNumber ?? '',
            email: '',
            profilePic: '',
            phoneNumber: user.phoneNumber ?? '',
            createdAt: DateTime.now(),
          );
          await userDoc.set(userModel.toMap());
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } else {
        setState(() => _error = "Verification failed. Try again.");
      }
    } catch (e) {
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
      },
      codeAutoRetrievalTimeout: (_) {
        setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
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
                  // OTP input fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return Container(
                        width: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: TextEditingController(
                            text: _otpController.text.length > i ? _otpController.text[i] : '',
                          ),
                          onChanged: (val) {
                            if (val.isNotEmpty && i < 5) {
                              _otpController.text = _otpController.text.padRight(i, ' ') + val;
                              FocusScope.of(context).nextFocus();
                            } else if (val.isEmpty && i > 0) {
                              FocusScope.of(context).previousFocus();
                            }
                          },
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: colorScheme.surface.withAlpha(isDark ? (0.45 * 255).toInt() : (0.65 * 255).toInt()),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          enabled: !_isLoading,
                        ),
                      );
                    }),
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
                  // Verify button
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}