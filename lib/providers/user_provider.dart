import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Repository for user-related Firestore operations.
class UserRepository {
  final _users = FirebaseFirestore.instance.collection('users');

  /// Fetch a user by UID. Returns null if not found.
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!..['uid'] = doc.id;
    return UserModel.fromMap(data);
  }

  /// Listen to user document changes.
  Stream<UserModel?> watchUserById(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!..['uid'] = doc.id;
      return UserModel.fromMap(data);
    });
  }
}

/// Provides the UserRepository instance.
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// Async provider for fetching a user once by UID.
final userProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  final repo = ref.read(userRepositoryProvider);
  return repo.getUserById(uid);
});

/// Stream provider for listening to user changes by UID.
final userStreamProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  final repo = ref.read(userRepositoryProvider);
  return repo.watchUserById(uid);
});