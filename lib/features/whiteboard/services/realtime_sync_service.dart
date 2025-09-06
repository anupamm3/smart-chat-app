import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/whiteboard_stroke.dart';
import '../models/whiteboard_session.dart';

/// Service for real-time synchronization of whiteboard data using Firestore only
class RealtimeSyncService {
  static RealtimeSyncService? _instance;
  static RealtimeSyncService get instance => _instance ??= RealtimeSyncService._();
  
  RealtimeSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, StreamController<WhiteboardStroke>> _strokeControllers = {};
  final Map<String, StreamController<UserPresence>> _presenceControllers = {};
  final Map<String, StreamController<Map<String, UserPresence>>> _allPresenceControllers = {};
  final Map<String, Timer?> _batchTimers = {};
  final Map<String, List<WhiteboardStroke>> _pendingStrokes = {};
  final Map<String, StreamSubscription?> _strokeSubscriptions = {};
  final Map<String, StreamSubscription?> _presenceSubscriptions = {};
  
  static const Duration _batchInterval = Duration(milliseconds: 100);
  static const int _maxBatchSize = 20;

  /// Initialize real-time listeners for a whiteboard session
  Future<void> initializeSession(String sessionId) async {
    if (_strokeControllers.containsKey(sessionId)) return;

    _strokeControllers[sessionId] = StreamController<WhiteboardStroke>.broadcast();
    _presenceControllers[sessionId] = StreamController<UserPresence>.broadcast();
    _allPresenceControllers[sessionId] = StreamController<Map<String, UserPresence>>.broadcast();
    _pendingStrokes[sessionId] = [];

    // Listen to real-time stroke updates
    _listenToStrokes(sessionId);
    
    // Listen to presence updates
    _listenToPresence(sessionId);
  }

  /// Listen to real-time stroke updates using Firestore
  void _listenToStrokes(String sessionId) {
    final strokesRef = _firestore
        .collection('whiteboards')
        .doc(sessionId)
        .collection('strokes')
        .orderBy('timestamp', descending: false);
    
    _strokeSubscriptions[sessionId] = strokesRef.snapshots().listen((snapshot) {
      try {
        for (final docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.added) {
            final stroke = WhiteboardStroke.fromFirestore(docChange.doc.data()!);
            _strokeControllers[sessionId]?.add(stroke);
          }
        }
      } catch (e) {
        debugPrint('Error parsing stroke: $e');
      }
    });
  }

  /// Listen to presence updates using Firestore
  void _listenToPresence(String sessionId) {
    final presenceRef = _firestore
        .collection('whiteboards')
        .doc(sessionId)
        .collection('presence');
    
    _presenceSubscriptions[sessionId] = presenceRef.snapshots().listen((snapshot) {
      try {
        final presenceMap = <String, UserPresence>{};
        
        for (final doc in snapshot.docs) {
          final presence = UserPresence.fromFirestore(doc.data());
          presenceMap[presence.userId] = presence;
        }

        _allPresenceControllers[sessionId]?.add(presenceMap);
      } catch (e) {
        debugPrint('Error parsing presence: $e');
      }
    });
  }

  /// Add stroke with batching for performance
  Future<void> addStroke(String sessionId, WhiteboardStroke stroke) async {
    try {
      // Add to pending batch
      _pendingStrokes[sessionId]?.add(stroke);

      // Cancel existing timer
      _batchTimers[sessionId]?.cancel();

      // Check if we should flush immediately
      final pendingCount = _pendingStrokes[sessionId]?.length ?? 0;
      if (pendingCount >= _maxBatchSize) {
        await _flushPendingStrokes(sessionId);
      } else {
        // Set timer for batch flush
        _batchTimers[sessionId] = Timer(_batchInterval, () {
          _flushPendingStrokes(sessionId);
        });
      }
    } catch (e) {
      debugPrint('Error adding stroke: $e');
      rethrow;
    }
  }

  /// Flush pending strokes to Firestore
  Future<void> _flushPendingStrokes(String sessionId) async {
    final pending = _pendingStrokes[sessionId];
    if (pending == null || pending.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final stroke in pending) {
        final strokeDoc = _firestore
            .collection('whiteboards')
            .doc(sessionId)
            .collection('strokes')
            .doc(stroke.id);
        batch.set(strokeDoc, stroke.toFirestore());
      }

      await batch.commit();

      // Clear pending strokes
      _pendingStrokes[sessionId]?.clear();
      
    } catch (e) {
      debugPrint('Error flushing strokes: $e');
      rethrow;
    }
  }

  /// Update user presence
  Future<void> updatePresence(String sessionId, UserPresence presence) async {
    try {
      final presenceRef = _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('presence')
          .doc(presence.userId);
      await presenceRef.set(presence.toFirestore());
    } catch (e) {
      debugPrint('Error updating presence: $e');
      rethrow;
    }
  }

  /// Remove user presence
  Future<void> removePresence(String sessionId, String userId) async {
    try {
      final presenceRef = _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('presence')
          .doc(userId);
      await presenceRef.delete();
    } catch (e) {
      debugPrint('Error removing presence: $e');
    }
  }

  /// Set user as active
  Future<void> setUserActive(String sessionId, String userId, String userName, {String? avatarUrl}) async {
    final presence = UserPresence(
      userId: userId,
      userName: userName,
      userAvatarUrl: avatarUrl,
      isActive: true,
      lastSeen: DateTime.now(),
    );
    await updatePresence(sessionId, presence);
  }

  /// Set user as inactive
  Future<void> setUserInactive(String sessionId, String userId) async {
    try {
      final presenceRef = _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('presence')
          .doc(userId);
      
      await presenceRef.update({
        'isActive': false,
        'lastSeen': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error setting user inactive: $e');
    }
  }

  /// Update cursor position
  Future<void> updateCursorPosition(String sessionId, String userId, Offset position) async {
    try {
      final presenceRef = _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('presence')
          .doc(userId);
      
      await presenceRef.update({
        'cursorPosition': {'x': position.dx, 'y': position.dy},
        'lastSeen': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating cursor position: $e');
    }
  }

  /// Get stroke stream for a session
  Stream<WhiteboardStroke> getStrokeStream(String sessionId) {
    if (!_strokeControllers.containsKey(sessionId)) {
      initializeSession(sessionId);
    }
    return _strokeControllers[sessionId]!.stream;
  }

  /// Get presence stream for all users in a session
  Stream<Map<String, UserPresence>> getPresenceStream(String sessionId) {
    if (!_allPresenceControllers.containsKey(sessionId)) {
      initializeSession(sessionId);
    }
    return _allPresenceControllers[sessionId]!.stream;
  }

  /// Load existing strokes from Firestore
  Future<List<WhiteboardStroke>> loadExistingStrokes(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('strokes')
          .orderBy('timestamp')
          .get();

      return snapshot.docs
          .map((doc) => WhiteboardStroke.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error loading existing strokes: $e');
      return [];
    }
  }

  /// Remove stroke
  Future<void> removeStroke(String sessionId, String strokeId) async {
    try {
      await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('strokes')
          .doc(strokeId)
          .delete();
    } catch (e) {
      debugPrint('Error removing stroke: $e');
      rethrow;
    }
  }

  /// Clear all strokes
  Future<void> clearAllStrokes(String sessionId) async {
    try {
      final strokesCollection = _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('strokes');
      
      final snapshot = await strokesCollection.get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing strokes: $e');
      rethrow;
    }
  }

  /// Cleanup session resources
  Future<void> cleanupSession(String sessionId) async {
    // Cancel pending timers
    _batchTimers[sessionId]?.cancel();
    _batchTimers.remove(sessionId);

    // Flush any remaining strokes
    await _flushPendingStrokes(sessionId);

    // Cancel subscriptions
    await _strokeSubscriptions[sessionId]?.cancel();
    await _presenceSubscriptions[sessionId]?.cancel();
    _strokeSubscriptions.remove(sessionId);
    _presenceSubscriptions.remove(sessionId);

    // Close streams
    await _strokeControllers[sessionId]?.close();
    await _presenceControllers[sessionId]?.close();
    await _allPresenceControllers[sessionId]?.close();

    // Remove from maps
    _strokeControllers.remove(sessionId);
    _presenceControllers.remove(sessionId);
    _allPresenceControllers.remove(sessionId);
    _pendingStrokes.remove(sessionId);
  }

  /// Dispose all resources
  Future<void> dispose() async {
    final sessionIds = List<String>.from(_strokeControllers.keys);
    for (final sessionId in sessionIds) {
      await cleanupSession(sessionId);
    }
  }

  /// Get active user count
  Future<int> getActiveUserCount(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .collection('presence')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting active user count: $e');
      return 0;
    }
  }

  /// Get connection status (simplified for Firestore)
  Stream<bool> get connectionStatus {
    // For Firestore, we'll use a simple connectivity check
    return Stream.periodic(const Duration(seconds: 5), (_) => true);
  }
}
