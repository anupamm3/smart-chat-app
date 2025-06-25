import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider.select((state) => state.isLoading));

    return Scaffold(
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: () async {
                  final success = await ref.read(authControllerProvider.notifier).signInWithGoogle();
                  if (success && context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              ),
      ),
    );
  }
}