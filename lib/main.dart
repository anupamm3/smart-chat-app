import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_chat_app/constants.dart';
import 'package:smart_chat_app/features/auth/controller/auth_controller.dart';
import 'package:smart_chat_app/features/groups/screens/group_chat_screen.dart';
import 'package:smart_chat_app/features/groups/screens/group_contact_picker_screen.dart';
import 'package:smart_chat_app/features/home/screens/groups_tab.dart';
import 'package:smart_chat_app/features/profile/screens/user_profile_screen.dart';
import 'package:smart_chat_app/features/users/screens/new_chat_screen.dart';
import 'package:smart_chat_app/firebase_options.dart';
import 'package:smart_chat_app/models/contact_model.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'package:smart_chat_app/providers/theme_provider.dart';
import 'package:smart_chat_app/features/settings/settings_screen.dart';
import 'features/auth/screens/phone_onboarding_screen.dart';
import 'features/auth/screens/otp_verification_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/chat/screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(child: SmartChatApp()));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize Firebase: $e'),
        ),
      ),
    ));
  }
}

class SmartChatApp extends ConsumerWidget {
  const SmartChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authAsync = ref.watch(authStateChangesProvider);
    
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
      home: authAsync.when(
        data: (user) {
          if (user != null) {
            return const HomeScreen();
          }
          return const PhoneOnboardingScreen();
        },
        loading: () => const BrandedSplashScreen(),
        error: (err, stack) => Scaffold(
          body: Center(child: Text('Auth error: $err')),
        ),
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

class BrandedSplashScreen extends StatelessWidget {
  const BrandedSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha((255 * 0.75).toInt()) // Light overlay in dark mode
                      : Colors.black.withAlpha((255 * 0.04).toInt()), // Subtle shadow in light mode
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Lottie.asset(
                    'assets/lottie/chat_icon.json',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SmartChat',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            // Animated loader (can be replaced with Lottie or custom animation)
            CircularProgressIndicator(
              color: colorScheme.onSurface,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}