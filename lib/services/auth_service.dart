import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Google Sign-In. Returns Firebase [User] on success, null on failure.
  static Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore, else save new user
        final userDoc = _firestore.collection('users').doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          final userModel = UserModel(
            uid: user.uid,
            name: user.displayName ?? '',
            email: user.email ?? '',
            profilePic: user.photoURL ?? '',
            phoneNumber: user.phoneNumber ?? '',
            createdAt: DateTime.now(),
          );
          await userDoc.set(userModel.toMap());
        }
      }
      return user;
    } catch (e) {
      return null;
    }
  }

  /// Phone Sign-In: returns User on success, null on failure
  static Future<User?> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        final userDoc = _firestore.collection('users').doc(user.uid);
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
      }
      return user;
    } catch (e) {
      return null;
    }
  }

  /// Sign out from Firebase and Google
  static Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}