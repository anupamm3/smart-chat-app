import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/whiteboard_session.dart';
import '../models/whiteboard_stroke.dart';
import 'realtime_sync_service.dart';

/// Main service for whiteboard business logic and session management
class WhiteboardService {
  static WhiteboardService? _instance;
  static WhiteboardService get instance => _instance ??= WhiteboardService._();
  
  WhiteboardService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RealtimeSyncService _syncService = RealtimeSyncService.instance;

  /// Create a new whiteboard session for a chat
  Future<WhiteboardSession> createSession({
    required String chatId,
    required String chatType,
    required List<String> participants,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is authorized to create whiteboard for this chat
      if (!participants.contains(currentUser.uid)) {
        throw Exception('User not authorized to create whiteboard for this chat');
      }

      final session = WhiteboardSession.create(
        chatId: chatId,
        chatType: chatType,
        participants: participants,
        createdBy: currentUser.uid,
        metadata: metadata,
      );

      // Save session metadata to Firestore
      await _firestore
          .collection('whiteboards')
          .doc(session.sessionId)
          .set(session.toFirestore());

      // Initialize real-time synchronization
      await _syncService.initializeSession(session.sessionId);

      return session;
    } catch (e) {
      debugPrint('Error creating whiteboard session: $e');
      rethrow;
    }
  }

  /// Get existing session or create new one for a chat
  Future<WhiteboardSession> getOrCreateSession({
    required String chatId,
    required String chatType,
    required List<String> participants,
  }) async {
    try {
      // First, try to find existing session for this chat
      final existingSession = await getSessionForChat(chatId);
      if (existingSession != null) {
        // Initialize sync service if not already done
        await _syncService.initializeSession(existingSession.sessionId);
        return existingSession;
      }

      // Create new session if none exists
      return await createSession(
        chatId: chatId,
        chatType: chatType,
        participants: participants,
      );
    } catch (e) {
      debugPrint('Error getting or creating session: $e');
      rethrow;
    }
  }

  /// Get session for a specific chat
  Future<WhiteboardSession?> getSessionForChat(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection('whiteboards')
          .where('chatId', isEqualTo: chatId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final sessionData = snapshot.docs.first.data();
      return WhiteboardSession.fromFirestore(sessionData);
    } catch (e) {
      debugPrint('Error getting session for chat: $e');
      return null;
    }
  }

  /// Get session by ID
  Future<WhiteboardSession?> getSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;

      return WhiteboardSession.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  /// Join a whiteboard session
  Future<void> joinSession(String sessionId, String userId, String userName, {String? avatarUrl}) async {
    try {
      // Verify user is authorized to join
      final session = await getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      if (!session.isParticipant(userId)) {
        throw Exception('User not authorized to join this session');
      }

      // Set user as active in presence
      await _syncService.setUserActive(sessionId, userId, userName, avatarUrl: avatarUrl);

      // Update session last modified time
      await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .update({'lastModified': Timestamp.now()});

    } catch (e) {
      debugPrint('Error joining session: $e');
      rethrow;
    }
  }

  /// Leave a whiteboard session
  Future<void> leaveSession(String sessionId, String userId) async {
    try {
      await _syncService.setUserInactive(sessionId, userId);
    } catch (e) {
      debugPrint('Error leaving session: $e');
    }
  }

  /// Add a stroke to the whiteboard
  Future<void> addStroke(String sessionId, WhiteboardStroke stroke) async {
    try {
      await _syncService.addStroke(sessionId, stroke);
      
      // Update session last modified time
      await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .update({'lastModified': Timestamp.now()});

    } catch (e) {
      debugPrint('Error adding stroke: $e');
      rethrow;
    }
  }

  /// Remove a stroke from the whiteboard
  Future<void> removeStroke(String sessionId, String strokeId, String userId) async {
    try {
      // Verify user has permission to remove stroke
      // For now, allow any participant to remove any stroke
      // In the future, you might want to restrict to stroke owner or admin
      await _syncService.removeStroke(sessionId, strokeId);
    } catch (e) {
      debugPrint('Error removing stroke: $e');
      rethrow;
    }
  }

  /// Clear all strokes from the whiteboard
  Future<void> clearWhiteboard(String sessionId, String userId) async {
    try {
      // Verify user has permission to clear whiteboard
      final session = await getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      if (!session.isParticipant(userId)) {
        throw Exception('User not authorized to clear this whiteboard');
      }

      await _syncService.clearAllStrokes(sessionId);
    } catch (e) {
      debugPrint('Error clearing whiteboard: $e');
      rethrow;
    }
  }

  /// Get real-time stroke stream
  Stream<WhiteboardStroke> getStrokeStream(String sessionId) {
    return _syncService.getStrokeStream(sessionId);
  }

  /// Get real-time presence stream
  Stream<Map<String, UserPresence>> getPresenceStream(String sessionId) {
    return _syncService.getPresenceStream(sessionId);
  }

  /// Load existing strokes for a session
  Future<List<WhiteboardStroke>> loadStrokes(String sessionId) async {
    try {
      return await _syncService.loadExistingStrokes(sessionId);
    } catch (e) {
      debugPrint('Error loading strokes: $e');
      return [];
    }
  }

  /// Update cursor position
  Future<void> updateCursorPosition(String sessionId, String userId, Offset position) async {
    try {
      await _syncService.updateCursorPosition(sessionId, userId, position);
    } catch (e) {
      // Don't throw for cursor updates as they're not critical
      debugPrint('Error updating cursor position: $e');
    }
  }

  /// Get active user count
  Future<int> getActiveUserCount(String sessionId) async {
    return await _syncService.getActiveUserCount(sessionId);
  }

  /// Get connection status
  Stream<bool> get connectionStatus => _syncService.connectionStatus;

  /// Export whiteboard as image data
  Future<List<WhiteboardStroke>> exportWhiteboard(String sessionId) async {
    try {
      return await loadStrokes(sessionId);
    } catch (e) {
      debugPrint('Error exporting whiteboard: $e');
      rethrow;
    }
  }

  /// Get whiteboard statistics
  Future<Map<String, dynamic>> getWhiteboardStats(String sessionId) async {
    try {
      final session = await getSession(sessionId);
      if (session == null) return {};

      final strokes = await loadStrokes(sessionId);
      final activeUsers = await getActiveUserCount(sessionId);

      // Calculate statistics
      final strokesByUser = <String, int>{};
      for (final stroke in strokes) {
        strokesByUser[stroke.userId] = (strokesByUser[stroke.userId] ?? 0) + 1;
      }

      return {
        'totalStrokes': strokes.length,
        'activeUsers': activeUsers,
        'participants': session.participants.length,
        'strokesByUser': strokesByUser,
        'createdAt': session.createdAt.toIso8601String(),
        'lastModified': session.lastModified.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting whiteboard stats: $e');
      return {};
    }
  }

  /// Check if user has permission to perform action
  bool hasPermission(WhiteboardSession session, String userId, String action) {
    // Basic permission check - all participants can draw
    if (!session.isParticipant(userId)) return false;

    switch (action) {
      case 'draw':
      case 'erase':
      case 'view':
        return true;
      case 'clear':
      case 'export':
        return true; // For now, all participants can clear/export
      case 'manage':
        return session.createdBy == userId; // Only creator can manage
      default:
        return false;
    }
  }

  /// Delete a whiteboard session
  Future<void> deleteSession(String sessionId, String userId) async {
    try {
      final session = await getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found');
      }

      // Only creator can delete session
      if (session.createdBy != userId) {
        throw Exception('Only session creator can delete the whiteboard');
      }

      // Clean up sync service resources
      await _syncService.cleanupSession(sessionId);

      // Delete all strokes
      await _syncService.clearAllStrokes(sessionId);

      // Delete session metadata
      await _firestore
          .collection('whiteboards')
          .doc(sessionId)
          .delete();

    } catch (e) {
      debugPrint('Error deleting session: $e');
      rethrow;
    }
  }

  /// Get recent whiteboard sessions for user
  Future<List<WhiteboardSession>> getRecentSessions(String userId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('whiteboards')
          .where('participants', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => WhiteboardSession.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent sessions: $e');
      return [];
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _syncService.dispose();
  }
}
