import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/drawing_tool.dart';
import '../models/whiteboard_stroke.dart';
import '../models/whiteboard_session.dart';
import '../services/whiteboard_service.dart';

/// State class for whiteboard
class WhiteboardState {
  final WhiteboardSession? session;
  final List<WhiteboardStroke> strokes;
  final Map<String, UserPresence> userPresence;
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final bool isLoading;
  final String? error;
  final bool isConnected;
  final WhiteboardStroke? currentStroke;

  const WhiteboardState({
    this.session,
    this.strokes = const [],
    this.userPresence = const {},
    this.selectedTool = DrawingTool.pen,
    this.selectedColor = Colors.black,
    this.strokeWidth = 2.0,
    this.isLoading = false,
    this.error,
    this.isConnected = false,
    this.currentStroke,
  });

  WhiteboardState copyWith({
    WhiteboardSession? session,
    List<WhiteboardStroke>? strokes,
    Map<String, UserPresence>? userPresence,
    DrawingTool? selectedTool,
    Color? selectedColor,
    double? strokeWidth,
    bool? isLoading,
    String? error,
    bool? isConnected,
    WhiteboardStroke? currentStroke,
  }) {
    return WhiteboardState(
      session: session ?? this.session,
      strokes: strokes ?? this.strokes,
      userPresence: userPresence ?? this.userPresence,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isConnected: isConnected ?? this.isConnected,
      currentStroke: currentStroke ?? this.currentStroke,
    );
  }
}

/// Whiteboard provider
class WhiteboardNotifier extends StateNotifier<WhiteboardState> {
  WhiteboardNotifier() : super(const WhiteboardState());

  final WhiteboardService _whiteboardService = WhiteboardService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream subscriptions
  StreamSubscription<WhiteboardStroke>? _strokeSubscription;
  StreamSubscription<Map<String, UserPresence>>? _presenceSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  /// Initialize whiteboard for a chat
  Future<void> initializeWhiteboard({
    required String chatId,
    required String chatType,
    required List<String> participants,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get or create session
      final session = await _whiteboardService.getOrCreateSession(
        chatId: chatId,
        chatType: chatType,
        participants: participants,
      );

      // Join the session
      await _whiteboardService.joinSession(
        session.sessionId,
        currentUser.uid,
        currentUser.displayName ?? 'Unknown User',
        avatarUrl: currentUser.photoURL,
      );

      // Load existing strokes
      final existingStrokes = await _whiteboardService.loadStrokes(session.sessionId);

      // Set up real-time listeners
      _setupListeners(session.sessionId);

      state = state.copyWith(
        session: session,
        strokes: existingStrokes,
        isLoading: false,
        isConnected: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      debugPrint('Error initializing whiteboard: $e');
    }
  }

  /// Set up real-time listeners
  void _setupListeners(String sessionId) {
    // Listen to new strokes
    _strokeSubscription = _whiteboardService
        .getStrokeStream(sessionId)
        .listen((stroke) {
      final updatedStrokes = List<WhiteboardStroke>.from(state.strokes)
        ..add(stroke);
      state = state.copyWith(strokes: updatedStrokes);
    });

    // Listen to user presence
    _presenceSubscription = _whiteboardService
        .getPresenceStream(sessionId)
        .listen((presence) {
      state = state.copyWith(userPresence: presence);
    });

    // Listen to connection status
    _connectionSubscription = _whiteboardService.connectionStatus.listen((isConnected) {
      state = state.copyWith(isConnected: isConnected);
    });
  }

  /// Select drawing tool
  void selectTool(DrawingTool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  /// Select color
  void selectColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  /// Set stroke width
  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width);
  }

  /// Start drawing a stroke from canvas input
  void startStrokeFromCanvas(WhiteboardStroke canvasStroke) {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Create a new stroke with proper user info
    final stroke = canvasStroke.copyWith(
      userId: currentUser.uid,
      userName: currentUser.displayName ?? 'Unknown User',
    );

    debugPrint('Starting stroke: tool=${stroke.tool}, points=${stroke.points.length}, isShape=${stroke.tool.isShape}');
    state = state.copyWith(currentStroke: stroke);
  }

  /// Start drawing a stroke
  void startStroke(List<Offset> points) {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final toolConfig = ToolConfiguration(
      tool: state.selectedTool,
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      opacity: state.selectedTool.defaultOpacity,
      strokeCap: state.selectedTool.strokeCap,
      blendMode: state.selectedTool.blendMode,
    );

    final stroke = WhiteboardStroke.create(
      points: points,
      toolConfig: toolConfig,
      userId: currentUser.uid,
      userName: currentUser.displayName ?? 'Unknown User',
    );

    state = state.copyWith(currentStroke: stroke);
  }

  /// Update current stroke with new points
  void updateCurrentStroke(List<Offset> points) {
    if (state.currentStroke == null) return;

    final updatedStroke = state.currentStroke!.copyWith(points: points);
    debugPrint('Updating stroke: tool=${updatedStroke.tool}, points=${points.length}');
    state = state.copyWith(currentStroke: updatedStroke);
    
    // Special handling for eraser tool
    if (state.selectedTool == DrawingTool.eraser) {
      _handleEraserStroke(points);
    }
  }
  
  /// Handle eraser stroke - remove intersecting strokes
  void _handleEraserStroke(List<Offset> eraserPoints) {
    if (eraserPoints.isEmpty) return;
    
    final eraserRadius = state.strokeWidth / 100; // Convert to normalized coordinates
    final strokesToRemove = <String>[];
    
    for (final stroke in state.strokes) {
      bool shouldRemove = false;
      for (final eraserPoint in eraserPoints) {
        for (final strokePoint in stroke.points) {
          final distance = (eraserPoint - strokePoint).distance;
          if (distance <= eraserRadius) {
            shouldRemove = true;
            break;
          }
        }
        if (shouldRemove) break;
      }
      if (shouldRemove) {
        strokesToRemove.add(stroke.id);
      }
    }
    
    // Remove intersecting strokes
    if (strokesToRemove.isNotEmpty) {
      final updatedStrokes = state.strokes
          .where((stroke) => !strokesToRemove.contains(stroke.id))
          .toList();
      state = state.copyWith(strokes: updatedStrokes);
      
      // Also remove from server
      for (final strokeId in strokesToRemove) {
        _removeStrokeFromServer(strokeId);
      }
    }
  }
  
  /// Remove stroke from server without updating local state
  Future<void> _removeStrokeFromServer(String strokeId) async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _whiteboardService.removeStroke(
        state.session!.sessionId,
        strokeId,
        currentUser.uid,
      );
    } catch (e) {
      debugPrint('Error removing stroke from server: $e');
    }
  }

  /// Complete current stroke
  Future<void> completeStroke() async {
    if (state.currentStroke == null || state.session == null) return;

    try {
      // For eraser tool, we don't save the eraser stroke itself
      if (state.selectedTool == DrawingTool.eraser) {
        state = state.copyWith(currentStroke: null);
        return;
      }
      
      await _whiteboardService.addStroke(
        state.session!.sessionId,
        state.currentStroke!,
      );

      // Add to local strokes immediately for responsiveness
      final updatedStrokes = List<WhiteboardStroke>.from(state.strokes)
        ..add(state.currentStroke!);

      state = state.copyWith(
        strokes: updatedStrokes,
        currentStroke: null,
      );
    } catch (e) {
      debugPrint('Error completing stroke: $e');
      state = state.copyWith(
        currentStroke: null,
        error: 'Failed to save stroke',
      );
    }
  }

  /// Cancel current stroke
  void cancelStroke() {
    state = state.copyWith(currentStroke: null);
  }

  /// Remove a stroke
  Future<void> removeStroke(String strokeId) async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _whiteboardService.removeStroke(
        state.session!.sessionId,
        strokeId,
        currentUser.uid,
      );

      // Remove from local strokes immediately
      final updatedStrokes = state.strokes
          .where((stroke) => stroke.id != strokeId)
          .toList();

      state = state.copyWith(strokes: updatedStrokes);
    } catch (e) {
      debugPrint('Error removing stroke: $e');
      state = state.copyWith(error: 'Failed to remove stroke');
    }
  }

  /// Clear all strokes
  Future<void> clearWhiteboard() async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Clear local state immediately for responsiveness
      state = state.copyWith(strokes: [], currentStroke: null);
      
      // Then clear on server
      await _whiteboardService.clearWhiteboard(
        state.session!.sessionId,
        currentUser.uid,
      );
    } catch (e) {
      debugPrint('Error clearing whiteboard: $e');
      state = state.copyWith(error: 'Failed to clear whiteboard');
    }
  }

  /// Update cursor position
  Future<void> updateCursorPosition(Offset position) async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _whiteboardService.updateCursorPosition(
        state.session!.sessionId,
        currentUser.uid,
        position,
      );
    } catch (e) {
      // Don't show error for cursor updates as they're not critical
      debugPrint('Error updating cursor position: $e');
    }
  }

  /// Undo last stroke by current user
  Future<void> undoLastStroke() async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Find the last stroke by current user
    final userStrokes = state.strokes
        .where((stroke) => stroke.userId == currentUser.uid)
        .toList();

    if (userStrokes.isEmpty) return;

    final lastStroke = userStrokes.last;
    await removeStroke(lastStroke.id);
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    if (state.session == null) return {};

    final currentUser = _auth.currentUser;
    final myStrokes = currentUser != null
        ? state.strokes.where((s) => s.userId == currentUser.uid).length
        : 0;

    return {
      'totalStrokes': state.strokes.length,
      'myStrokes': myStrokes,
      'otherStrokes': state.strokes.length - myStrokes,
      'activeUsers': state.userPresence.values.where((u) => u.isActive).length,
      'sessionDuration': state.session!.lastModified
          .difference(state.session!.createdAt)
          .inMinutes,
    };
  }

  /// Check if user can perform action
  bool canPerformAction(String action) {
    if (state.session == null) return false;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    return _whiteboardService.hasPermission(
      state.session!,
      currentUser.uid,
      action,
    );
  }

  /// Leave whiteboard session
  Future<void> leaveSession() async {
    if (state.session == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _whiteboardService.leaveSession(
        state.session!.sessionId,
        currentUser.uid,
      );
    } catch (e) {
      debugPrint('Error leaving session: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _strokeSubscription?.cancel();
    _presenceSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider definitions
final whiteboardProvider = StateNotifierProvider<WhiteboardNotifier, WhiteboardState>((ref) {
  return WhiteboardNotifier();
});

// Computed providers
final currentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final activeUsersProvider = Provider<List<UserPresence>>((ref) {
  final state = ref.watch(whiteboardProvider);
  return state.userPresence.values
      .where((presence) => presence.isActive)
      .toList();
});

final canDrawProvider = Provider<bool>((ref) {
  final notifier = ref.read(whiteboardProvider.notifier);
  return notifier.canPerformAction('draw');
});

final canClearProvider = Provider<bool>((ref) {
  final notifier = ref.read(whiteboardProvider.notifier);
  return notifier.canPerformAction('clear');
});

final statisticsProvider = Provider<Map<String, dynamic>>((ref) {
  final notifier = ref.read(whiteboardProvider.notifier);
  return notifier.getStatistics();
});
