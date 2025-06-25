import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';
import 'package:smart_chat_app/features/users/screens/new_chat_screen.dart';
import 'package:smart_chat_app/firebase_options.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'features/auth/screens/phone_onboarding_screen.dart';
import 'features/auth/screens/otp_verification_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/chat/screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: SmartChatApp(),
    ),
  );
}

class SmartChatApp extends StatelessWidget {
  const SmartChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartChat',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorSchemeSeed: Colors.blue,
      ),
      themeMode: ThemeMode.system,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const PhoneOnboardingScreen();
        },
      ),
      routes: {
        AppRoutes.onboarding: (context) => const PhoneOnboardingScreen(),
        AppRoutes.otp: (context) => const OTPVerificationScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.chat: (context) {
          final user = ModalRoute.of(context)!.settings.arguments as UserModel;
          return ChatScreen(receiver: user);
        },
        AppRoutes.newChat: (context) => const NewChatScreen(),
        AppRoutes.profile: (context) {
          final user = ModalRoute.of(context)!.settings.arguments as UserModel;
          return UserProfileScreen(user: user);
        },
      },
    );
  }
}