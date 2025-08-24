import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/router.dart';
import 'package:smart_chat_app/providers/theme_provider.dart';
import 'package:smart_chat_app/widgets/gradient_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return GradientScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withAlpha(isDark ? (0.18 * 255).toInt() : (0.10 * 255).toInt()),
                    width: 1,
                  ),
                ),
                color: isDark
                  ? colorScheme.surfaceContainerLow.withAlpha((0.9 * 255).toInt())
                  : colorScheme.surfaceContainerLow.withAlpha((0.95 * 255).toInt()),
                shadowColor: colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                child: ListTile(
                  leading: Icon(Icons.palette, color: colorScheme.primary),
                  title: Text(
                    'Theme',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Choose your preferred theme',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
                  trailing: SizedBox(
  width: 120,
  child: DropdownButtonFormField<ThemeMode>(
    value: themeMode,
    decoration: InputDecoration(
      filled: true,
      fillColor: colorScheme.surface.withAlpha(isDark ? (0.8 * 255).toInt() : (0.95 * 255).toInt()),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary.withAlpha((0.3 * 255).toInt()),
          width: 1,
        ),
      ),
    ),
    icon: Icon(Icons.arrow_drop_down_rounded, color: colorScheme.primary),
    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: colorScheme.onSurface),
    dropdownColor: colorScheme.surface,
    items: [
      DropdownMenuItem(
        value: ThemeMode.system,
        child: Text('System', style: GoogleFonts.poppins()),
      ),
      DropdownMenuItem(
        value: ThemeMode.light,
        child: Text('Light', style: GoogleFonts.poppins()),
      ),
      DropdownMenuItem(
        value: ThemeMode.dark,
        child: Text('Dark', style: GoogleFonts.poppins()),
      ),
    ],
    onChanged: (mode) {
      if (mode != null) {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      }
    },
  ),
),
                ),
              ),
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withAlpha(isDark ? (0.18 * 255).toInt() : (0.10 * 255).toInt()),
                    width: 1,
                  ),
                ),
                color: isDark
                  ? colorScheme.surfaceContainerLow.withAlpha((0.9 * 255).toInt())
                  : colorScheme.surfaceContainerLow.withAlpha((0.95 * 255).toInt()),
                shadowColor: colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text('Logout', style: GoogleFonts.poppins(color: Colors.redAccent)),
                  onTap: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Confirm', style: TextStyle(color: Colors.redAccent),),
                          ),
                        ],
                      ),
                    );
                    if (shouldLogout == true) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.onboarding,
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}