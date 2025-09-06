import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'whiteboard_stroke.dart';

/// Represents an active user's presence on the whiteboard
class UserPresence {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final bool isActive;
  final DateTime lastSeen;
  final Offset? cursorPosition;
  final String? currentTool;

  const UserPresence({
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.isActive,
    required this.lastSeen,
    this.cursorPosition,
    this.currentTool,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'isActive': isActive,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'cursorPosition': cursorPosition != null
          ? {'x': cursorPosition!.dx, 'y': cursorPosition!.dy}
          : null,
      'currentTool': currentTool,
    };
  }

  /// Create from Firestore document
  factory UserPresence.fromFirestore(Map<String, dynamic> data) {
    final cursorData = data['cursorPosition'] as Map<String, dynamic>?;
    final cursorPosition = cursorData != null
        ? Offset(cursorData['x']?.toDouble() ?? 0.0, cursorData['y']?.toDouble() ?? 0.0)
        : null;

    return UserPresence(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatarUrl: data['userAvatarUrl'],
      isActive: data['isActive'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cursorPosition: cursorPosition,
      currentTool: data['currentTool'],
    );
  }

  /// Copy with modifications
  UserPresence copyWith({
    String? userId,
    String? userName,
    String? userAvatarUrl,
    bool? isActive,
    DateTime? lastSeen,
    Offset? cursorPosition,
    String? currentTool,
  }) {
    return UserPresence(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      currentTool: currentTool ?? this.currentTool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPresence && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}

/// Represents a whiteboard session
class WhiteboardSession {
  final String sessionId;
  final String chatId;
  final String chatType; // 'individual' or 'group'
  final List<String> participants;
  final Map<String, UserPresence> activeUsers;
  final List<WhiteboardStroke> strokes;
  final DateTime createdAt;
  final DateTime lastModified;
  final String createdBy;
  final Map<String, dynamic> metadata;

  const WhiteboardSession({
    required this.sessionId,
    required this.chatId,
    required this.chatType,
    required this.participants,
    required this.activeUsers,
    required this.strokes,
    required this.createdAt,
    required this.lastModified,
    required this.createdBy,
    this.metadata = const {},
  });

  /// Create a new whiteboard session
  factory WhiteboardSession.create({
    required String chatId,
    required String chatType,
    required List<String> participants,
    required String createdBy,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final sessionId = '${chatId}_${now.millisecondsSinceEpoch}';

    return WhiteboardSession(
      sessionId: sessionId,
      chatId: chatId,
      chatType: chatType,
      participants: participants,
      activeUsers: {},
      strokes: [],
      createdAt: now,
      lastModified: now,
      createdBy: createdBy,
      metadata: metadata ?? {},
    );
  }

  /// Get total stroke count
  int get strokeCount => strokes.length;

  /// Get active user count
  int get activeUserCount => activeUsers.values.where((user) => user.isActive).length;

  /// Check if user is participant
  bool isParticipant(String userId) => participants.contains(userId);

  /// Check if user is currently active
  bool isUserActive(String userId) => activeUsers[userId]?.isActive ?? false;

  /// Get strokes by user
  List<WhiteboardStroke> getStrokesByUser(String userId) {
    return strokes.where((stroke) => stroke.userId == userId).toList();
  }

  /// Get strokes in time range
  List<WhiteboardStroke> getStrokesInTimeRange(DateTime start, DateTime end) {
    return strokes.where((stroke) => 
      stroke.timestamp.isAfter(start) && stroke.timestamp.isBefore(end)
    ).toList();
  }

  /// Get bounding box of all strokes
  Rect get boundingBox {
    if (strokes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      final strokeBounds = stroke.boundingBox;
      minX = minX < strokeBounds.left ? minX : strokeBounds.left;
      minY = minY < strokeBounds.top ? minY : strokeBounds.top;
      maxX = maxX > strokeBounds.right ? maxX : strokeBounds.right;
      maxY = maxY > strokeBounds.bottom ? maxY : strokeBounds.bottom;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Convert to Firestore document (metadata only)
  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'chatId': chatId,
      'chatType': chatType,
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModified': Timestamp.fromDate(lastModified),
      'createdBy': createdBy,
      'strokeCount': strokeCount,
      'metadata': metadata,
    };
  }

  /// Create from Firestore document (metadata only)
  factory WhiteboardSession.fromFirestore(Map<String, dynamic> data) {
    return WhiteboardSession(
      sessionId: data['sessionId'] ?? '',
      chatId: data['chatId'] ?? '',
      chatType: data['chatType'] ?? 'individual',
      participants: List<String>.from(data['participants'] ?? []),
      activeUsers: {}, // Will be loaded separately
      strokes: [], // Will be loaded separately
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Copy with modifications
  WhiteboardSession copyWith({
    String? sessionId,
    String? chatId,
    String? chatType,
    List<String>? participants,
    Map<String, UserPresence>? activeUsers,
    List<WhiteboardStroke>? strokes,
    DateTime? createdAt,
    DateTime? lastModified,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return WhiteboardSession(
      sessionId: sessionId ?? this.sessionId,
      chatId: chatId ?? this.chatId,
      chatType: chatType ?? this.chatType,
      participants: participants ?? this.participants,
      activeUsers: activeUsers ?? this.activeUsers,
      strokes: strokes ?? this.strokes,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add stroke to session
  WhiteboardSession addStroke(WhiteboardStroke stroke) {
    final updatedStrokes = List<WhiteboardStroke>.from(strokes)..add(stroke);
    return copyWith(
      strokes: updatedStrokes,
      lastModified: DateTime.now(),
    );
  }

  /// Remove stroke from session
  WhiteboardSession removeStroke(String strokeId) {
    final updatedStrokes = strokes.where((stroke) => stroke.id != strokeId).toList();
    return copyWith(
      strokes: updatedStrokes,
      lastModified: DateTime.now(),
    );
  }

  /// Update user presence
  WhiteboardSession updateUserPresence(UserPresence presence) {
    final updatedActiveUsers = Map<String, UserPresence>.from(activeUsers);
    updatedActiveUsers[presence.userId] = presence;
    return copyWith(activeUsers: updatedActiveUsers);
  }

  /// Remove user presence
  WhiteboardSession removeUserPresence(String userId) {
    final updatedActiveUsers = Map<String, UserPresence>.from(activeUsers);
    updatedActiveUsers.remove(userId);
    return copyWith(activeUsers: updatedActiveUsers);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WhiteboardSession && other.sessionId == sessionId;
  }

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() {
    return 'WhiteboardSession(sessionId: $sessionId, chatId: $chatId, participants: ${participants.length}, strokes: ${strokes.length})';
  }
}

/// Whiteboard permission levels
enum WhiteboardPermission {
  view,
  draw,
  admin,
}

extension WhiteboardPermissionExtension on WhiteboardPermission {
  String get displayName {
    switch (this) {
      case WhiteboardPermission.view:
        return 'Viewer';
      case WhiteboardPermission.draw:
        return 'Editor';
      case WhiteboardPermission.admin:
        return 'Admin';
    }
  }

  bool get canDraw => this == WhiteboardPermission.draw || this == WhiteboardPermission.admin;
  bool get canManage => this == WhiteboardPermission.admin;
}
