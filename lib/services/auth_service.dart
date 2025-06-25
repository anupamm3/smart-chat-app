import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_chat_app/models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    } on FirebaseAuthException catch (e) {
      // You can log or handle specific FirebaseAuth errors here
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return null;
    } on FirebaseException catch (e) {
      // Handle Firestore errors
      print('FirebaseException: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      // Handle any other errors
      print('Unknown error in signInWithPhoneCredential: $e');
      return null;
    }
  }

  /// Sign out from Firebase
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
    }
  }
}