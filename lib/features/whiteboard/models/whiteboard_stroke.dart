import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'drawing_tool.dart';

/// Represents a single drawing stroke on the whiteboard
class WhiteboardStroke {
  final String id;
  final String userId;
  final String userName;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;
  final DateTime timestamp;
  final double opacity;
  final bool isFilled;
  final StrokeCap strokeCap;
  final BlendMode blendMode;

  const WhiteboardStroke({
    required this.id,
    required this.userId,
    required this.userName,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.timestamp,
    this.opacity = 1.0,
    this.isFilled = false,
    this.strokeCap = StrokeCap.round,
    this.blendMode = BlendMode.srcOver,
  });

  /// Create a new stroke with generated ID
  factory WhiteboardStroke.create({
    required String userId,
    required String userName,
    required List<Offset> points,
    required ToolConfiguration toolConfig,
  }) {
    // Safely get user ID suffix (avoid range errors)
    final userIdSuffix = userId.length >= 6 ? userId.substring(0, 6) : userId;
    
    return WhiteboardStroke(
      id: DateTime.now().millisecondsSinceEpoch.toString() + userIdSuffix,
      userId: userId,
      userName: userName,
      points: points,
      color: toolConfig.color,
      strokeWidth: toolConfig.strokeWidth,
      tool: toolConfig.tool,
      timestamp: DateTime.now(),
      opacity: toolConfig.opacity,
      isFilled: toolConfig.isFilled,
      strokeCap: toolConfig.strokeCap,
      blendMode: toolConfig.blendMode,
    );
  }

  /// Get effective color with opacity applied
  Color get effectiveColor => color.withOpacity(opacity);

  /// Get bounding box of the stroke
  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    
    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = minX < point.dx ? minX : point.dx;
      minY = minY < point.dy ? minY : point.dy;
      maxX = maxX > point.dx ? maxX : point.dx;
      maxY = maxY > point.dy ? maxY : point.dy;
    }

    return Rect.fromLTRB(
      minX - strokeWidth / 2,
      minY - strokeWidth / 2,
      maxX + strokeWidth / 2,
      maxY + strokeWidth / 2,
    );
  }

  /// Check if point is within stroke bounds (for selection/editing)
  bool containsPoint(Offset point, {double tolerance = 10.0}) {
    return boundingBox.inflate(tolerance).contains(point);
  }

  /// Get path for drawing
  Path get path {
    final path = Path();
    if (points.isEmpty) return path;

    if (tool.isShape) {
      return _createShapePath();
    } else {
      return _createFreeformPath();
    }
  }

  /// Create path for shape tools
  Path _createShapePath() {
    final path = Path();
    if (points.length < 2) return path;

    final start = points.first;
    final end = points.last;

    switch (tool) {
      case DrawingTool.line:
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
        break;
      case DrawingTool.rectangle:
        final rect = Rect.fromPoints(start, end);
        if (isFilled) {
          path.addRect(rect);
        } else {
          path.addRect(rect);
        }
        break;
      case DrawingTool.circle:
        final center = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
        final radius = (end - start).distance / 2;
        if (isFilled) {
          path.addOval(Rect.fromCircle(center: center, radius: radius));
        } else {
          path.addOval(Rect.fromCircle(center: center, radius: radius));
        }
        break;
      case DrawingTool.arrow:
        _createArrowPath(path, start, end);
        break;
      default:
        break;
    }
    return path;
  }

  /// Create path for freeform drawing
  Path _createFreeformPath() {
    final path = Path();
    if (points.isEmpty) return path;

    if (points.length == 1) {
      // Single point - draw a small circle
      path.addOval(Rect.fromCircle(center: points.first, radius: strokeWidth / 2));
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = points[i - 1];

      if (i == 1) {
        path.lineTo(current.dx, current.dy);
      } else {
        // Use quadratic bezier for smooth curves
        final controlPoint = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(previous.dx, previous.dy, controlPoint.dx, controlPoint.dy);
      }
    }

    return path;
  }

  /// Create arrow path
  void _createArrowPath(Path path, Offset start, Offset end) {
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);

    // Calculate arrow head
    final direction = (end - start).direction;
    final arrowLength = strokeWidth * 3;
    final arrowAngle = 0.5; // radians

    final arrowPoint1 = end + Offset.fromDirection(direction + arrowAngle + 3.14159, arrowLength);
    final arrowPoint2 = end + Offset.fromDirection(direction - arrowAngle + 3.14159, arrowLength);

    path.moveTo(end.dx, end.dy);
    path.lineTo(arrowPoint1.dx, arrowPoint1.dy);
    path.moveTo(end.dx, end.dy);
    path.lineTo(arrowPoint2.dx, arrowPoint2.dy);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'tool': tool.index,
      'timestamp': Timestamp.fromDate(timestamp),
      'opacity': opacity,
      'isFilled': isFilled,
      'strokeCap': strokeCap.index,
      'blendMode': blendMode.index,
    };
  }

  /// Create from Firestore document
  factory WhiteboardStroke.fromFirestore(Map<String, dynamic> data) {
    final pointsData = data['points'] as List<dynamic>? ?? [];
    final points = pointsData.map((p) => Offset(p['x']?.toDouble() ?? 0.0, p['y']?.toDouble() ?? 0.0)).toList();

    return WhiteboardStroke(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      points: points,
      color: Color(data['color'] ?? 0xFF000000),
      strokeWidth: data['strokeWidth']?.toDouble() ?? 2.0,
      tool: DrawingTool.values[data['tool'] ?? 0],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      opacity: data['opacity']?.toDouble() ?? 1.0,
      isFilled: data['isFilled'] ?? false,
      strokeCap: StrokeCap.values[data['strokeCap'] ?? 1],
      blendMode: BlendMode.values[data['blendMode'] ?? 3],
    );
  }

  /// Copy with modifications
  WhiteboardStroke copyWith({
    String? id,
    String? userId,
    String? userName,
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    DrawingTool? tool,
    DateTime? timestamp,
    double? opacity,
    bool? isFilled,
    StrokeCap? strokeCap,
    BlendMode? blendMode,
  }) {
    return WhiteboardStroke(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      timestamp: timestamp ?? this.timestamp,
      opacity: opacity ?? this.opacity,
      isFilled: isFilled ?? this.isFilled,
      strokeCap: strokeCap ?? this.strokeCap,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WhiteboardStroke && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WhiteboardStroke(id: $id, userId: $userId, tool: $tool, points: ${points.length})';
  }
}

/// Represents a batch of strokes for efficient synchronization
class StrokeBatch {
  final List<WhiteboardStroke> strokes;
  final DateTime timestamp;
  final String batchId;

  const StrokeBatch({
    required this.strokes,
    required this.timestamp,
    required this.batchId,
  });

  factory StrokeBatch.create(List<WhiteboardStroke> strokes) {
    return StrokeBatch(
      strokes: strokes,
      timestamp: DateTime.now(),
      batchId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'strokes': strokes.map((s) => s.toFirestore()).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'batchId': batchId,
    };
  }

  factory StrokeBatch.fromFirestore(Map<String, dynamic> data) {
    final strokesData = data['strokes'] as List<dynamic>? ?? [];
    final strokes = strokesData.map((s) => WhiteboardStroke.fromFirestore(s)).toList();

    return StrokeBatch(
      strokes: strokes,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      batchId: data['batchId'] ?? '',
    );
  }
}
