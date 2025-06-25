import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true);

      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Store user details in Firestore if not exists
        final userDoc = _firestore.collection('users').doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          await userDoc.set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}

// StreamProvider for auth state
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

// StateNotifierProvider for AuthController
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());