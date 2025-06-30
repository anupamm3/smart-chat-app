import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';
import 'dart:developer' as developer;

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs in with a phone credential and ensures a user document exists in Firestore.
  /// Returns the Firebase [User] on success, or null on failure.
  static Future<User?> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        final userDoc = _firestore.collection('users').doc(user.uid);
        final doc = await userDoc.get();
        if (!doc.exists) {
          // Create a new user document with all required fields.
          final userModel = UserModel(
            uid: user.uid,
            phoneNumber: user.phoneNumber ?? '',
            name: '', // Set default or prompt for name later
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
      }
      return user;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException during phone sign in',
        name: 'AuthService',
        error: '${e.code} - ${e.message}',
      );
      return null;
    } on FirebaseException catch (e) {
      developer.log(
        'FirebaseException during phone sign in',
        name: 'AuthService',
        error: '${e.code} - ${e.message}',
      );
      return null;
    } catch (e) {
      developer.log(
        'Unknown error during phone sign in',
        name: 'AuthService',
        error: e.toString(),
      );
      return null;
    }
  }

  /// Signs out the current user from Firebase Auth.
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      developer.log(
        'Error during sign out',
        name: 'AuthService',
        error: e.toString(),
      );
    }
  }
}