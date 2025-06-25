import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_chat_app/services/auth_service.dart';

class AuthState {
  final bool isLoading;
  AuthState({this.isLoading = false});

  AuthState copyWith({bool? isLoading}) => AuthState(
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState());

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) onError,
  }) async {
    state = state.copyWith(isLoading: true);
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        state = state.copyWith(isLoading: false);
      },
      verificationFailed: (FirebaseAuthException e) {
        state = state.copyWith(isLoading: false);
        onError(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        state = state.copyWith(isLoading: false);
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<bool> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      state = state.copyWith(isLoading: true);
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final user = await AuthService.signInWithPhoneCredential(credential);
      state = state.copyWith(isLoading: false);
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true);
      final user = await AuthService.signInWithGoogle();
      state = state.copyWith(isLoading: false);
      return user != null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }
}

// StreamProvider for auth state
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

// StateNotifierProvider for AuthController
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());