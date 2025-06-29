import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/groups/screens/group_chat_screen.dart';
import 'package:smart_chat_app/features/groups/screens/group_contact_picker_screen.dart';
import 'package:smart_chat_app/features/home/screens/groups_tab.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';
import 'package:smart_chat_app/features/users/screens/new_chat_screen.dart';
import 'package:smart_chat_app/firebase_options.dart';
import 'package:smart_chat_app/models/contact_model.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/providers/theme_provider.dart';
import 'package:smart_chat_app/settings/settings_screen.dart';
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

class SmartChatApp extends ConsumerWidget {
  const SmartChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      title: 'SmartChat',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        
        // AppBar theme for consistent look
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ColorScheme.fromSeed(seedColor: Colors.deepPurple).onSurface,
          ),
        ),
        
        // Card theme for gradient backgrounds
        cardTheme: CardThemeData(
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ).onSurface,
          ),
        ),
        
        cardTheme: const CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
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
        AppRoutes.profileTab: (context) {
          final user = ModalRoute.of(context)!.settings.arguments as UserModel;
          return UserProfileScreen(user: user);
        },
        AppRoutes.groupsTab: (context) => const GroupsTab(),
        AppRoutes.groupChat: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return GroupChatRoomScreen(
            groupId: args['groupId'] as String,
            groupName: args['groupName'] as String? ?? '',
            groupPhotoUrl: args['groupPhotoUrl'] as String?,
          );
        },
        AppRoutes.groupContactPicker: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final contacts = args['contacts'] as List<ContactModel>;
          return GroupContactPickerScreen(contacts: contacts);
        },   
        AppRoutes.settings: (context) => const SettingsScreen()   
      },
    );
  }
}