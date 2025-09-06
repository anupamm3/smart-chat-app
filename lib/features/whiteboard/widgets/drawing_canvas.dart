import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/drawing_tool.dart';
import '../models/whiteboard_stroke.dart';

/// Custom painter for rendering whiteboard strokes
class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final WhiteboardStroke? currentStroke;
  final Size canvasSize;

  WhiteboardPainter({
    required this.strokes,
    this.currentStroke,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, size);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, size);
    }
  }

  void _drawStroke(Canvas canvas, WhiteboardStroke stroke, Size size) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Apply tool-specific paint properties
    switch (stroke.tool) {
      case DrawingTool.highlighter:
        paint.blendMode = BlendMode.multiply;
        paint.color = stroke.color.withOpacity(0.4);
        break;
      case DrawingTool.eraser:
        paint.blendMode = BlendMode.clear;
        paint.style = PaintingStyle.stroke;
        break;
      case DrawingTool.pen:
      default:
        paint.blendMode = BlendMode.srcOver;
        break;
    }

    // Draw based on stroke type
    if (stroke.tool.isShape) {
      _drawShape(canvas, paint, stroke, size);
    } else {
      _drawFreeform(canvas, paint, stroke, size);
    }
  }

  void _drawShape(Canvas canvas, Paint paint, WhiteboardStroke stroke, Size size) {
    if (stroke.points.length < 2) return;

    final start = _scalePoint(stroke.points.first, size);
    final end = _scalePoint(stroke.points.last, size);

    switch (stroke.tool) {
      case DrawingTool.rectangle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawRect(rect, paint);
        break;
        
      case DrawingTool.circle:
        final center = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
        final radius = (end - start).distance / 2;
        canvas.drawCircle(center, radius, paint);
        break;
        
      case DrawingTool.line:
        canvas.drawLine(start, end, paint);
        break;
        
      case DrawingTool.arrow:
        _drawArrow(canvas, paint, start, end);
        break;
        
      default:
        break;
    }
  }

  void _drawFreeform(Canvas canvas, Paint paint, WhiteboardStroke stroke, Size size) {
    if (stroke.points.isEmpty) return;

    final path = Path();
    final scaledPoints = stroke.points.map((p) => _scalePoint(p, size)).toList();

    if (scaledPoints.length == 1) {
      // Single point - draw a small circle
      canvas.drawCircle(scaledPoints.first, paint.strokeWidth / 2, paint);
      return;
    }

    // Create smooth path through points
    path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);

    for (int i = 1; i < scaledPoints.length; i++) {
      final current = scaledPoints[i];

      if (i == scaledPoints.length - 1) {
        // Last point - draw line to it
        path.lineTo(current.dx, current.dy);
      } else {
        // Smooth curve using quadratic bezier
        final next = scaledPoints[i + 1];
        final controlPoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          controlPoint.dx,
          controlPoint.dy,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset start, Offset end) {
    // Draw main line
    canvas.drawLine(start, end, paint);

    // Calculate arrow head
    const arrowLength = 20.0;
    const arrowAngle = 0.5; // radians

    final direction = end - start;
    final length = direction.distance;
    if (length == 0) return;

    final unitVector = direction / length;
    
    // Arrow head points
    final arrowHead1 = end - 
        Offset(
          arrowLength * (unitVector.dx * math.cos(arrowAngle) - unitVector.dy * math.sin(arrowAngle)),
          arrowLength * (unitVector.dx * math.sin(arrowAngle) + unitVector.dy * math.cos(arrowAngle)),
        );
    
    final arrowHead2 = end - 
        Offset(
          arrowLength * (unitVector.dx * math.cos(-arrowAngle) - unitVector.dy * math.sin(-arrowAngle)),
          arrowLength * (unitVector.dx * math.sin(-arrowAngle) + unitVector.dy * math.cos(-arrowAngle)),
        );

    // Draw arrow head
    canvas.drawLine(end, arrowHead1, paint);
    canvas.drawLine(end, arrowHead2, paint);
  }

  Offset _scalePoint(Offset point, Size size) {
    // Scale point from normalized coordinates (0-1) to canvas size
    return Offset(
      point.dx * size.width,
      point.dy * size.height,
    );
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
           oldDelegate.currentStroke != currentStroke ||
           oldDelegate.canvasSize != canvasSize;
  }
}

/// Interactive drawing canvas widget
class DrawingCanvas extends StatefulWidget {
  final List<WhiteboardStroke> strokes;
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final Function(WhiteboardStroke) onStrokeCompleted;
  final Function(WhiteboardStroke) onStrokeUpdated;
  final Function(Offset) onCursorMoved;
  final bool isEnabled;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onStrokeCompleted,
    required this.onStrokeUpdated,
    required this.onCursorMoved,
    this.isEnabled = true,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  WhiteboardStroke? _currentStroke;
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        return MouseRegion(
          onHover: widget.isEnabled ? _handleMouseMove : null,
          cursor: _getCursor(),
          child: Listener(
            onPointerDown: widget.isEnabled ? _handlePointerDown : null,
            onPointerMove: widget.isEnabled ? _handlePointerMove : null,
            onPointerUp: widget.isEnabled ? _handlePointerUp : null,
            onPointerCancel: widget.isEnabled ? _handlePointerCancel : null,
            child: CustomPaint(
              painter: WhiteboardPainter(
                strokes: widget.strokes,
                currentStroke: null, // Don't show current stroke here, it's in the strokes list
                canvasSize: size,
              ),
              size: size,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
          ),
        );
      },
    );
  }

  MouseCursor _getCursor() {
    switch (widget.selectedTool) {
      case DrawingTool.eraser:
        return SystemMouseCursors.grab;
      case DrawingTool.pen:
      case DrawingTool.highlighter:
        return SystemMouseCursors.precise;
      case DrawingTool.line:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.arrow:
        return SystemMouseCursors.move;
    }
  }

  void _handleMouseMove(PointerHoverEvent event) {
    if (!_isDrawing && widget.isEnabled) {
      final normalizedPos = _normalizePosition(event.localPosition);
      if (normalizedPos != Offset.zero) {
        widget.onCursorMoved(normalizedPos);
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.isEnabled) return;

    final normalizedPos = _normalizePosition(event.localPosition);
    
    final toolConfig = ToolConfiguration(
      tool: widget.selectedTool,
      color: widget.selectedColor,
      strokeWidth: widget.strokeWidth,
      opacity: widget.selectedTool.defaultOpacity,
      strokeCap: widget.selectedTool.strokeCap,
      blendMode: widget.selectedTool.blendMode,
    );
    
    final stroke = WhiteboardStroke.create(
      points: [normalizedPos],
      toolConfig: toolConfig,
      userId: '', // Will be set by the provider
      userName: '', // Will be set by the provider
    );

    _isDrawing = true;
    _currentStroke = stroke;
    widget.onStrokeUpdated(stroke);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDrawing || _currentStroke == null) return;

    final normalizedPos = _normalizePosition(event.localPosition);

    if (widget.selectedTool.isShape) {
      // For shapes, only keep start and current point
      _currentStroke = _currentStroke!.copyWith(
        points: [_currentStroke!.points.first, normalizedPos],
      );
    } else {
      // For freeform drawing, add points
      final updatedPoints = List<Offset>.from(_currentStroke!.points)..add(normalizedPos);
      _currentStroke = _currentStroke!.copyWith(points: updatedPoints);
    }

    widget.onStrokeUpdated(_currentStroke!);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isDrawing || _currentStroke == null) return;

    final normalizedPos = _normalizePosition(event.localPosition);

    // Finalize the stroke
    if (widget.selectedTool.isShape) {
      _currentStroke = _currentStroke!.copyWith(
        points: [_currentStroke!.points.first, normalizedPos],
      );
    } else {
      final updatedPoints = List<Offset>.from(_currentStroke!.points);
      if (updatedPoints.last != normalizedPos) {
        updatedPoints.add(normalizedPos);
      }
      _currentStroke = _currentStroke!.copyWith(points: updatedPoints);
    }

    widget.onStrokeCompleted(_currentStroke!);
    
    _currentStroke = null;
    _isDrawing = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _currentStroke = null;
    _isDrawing = false;
  }

  Offset _normalizePosition(Offset position) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;

    final size = renderBox.size;
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    
    return Offset(
      (position.dx / size.width).clamp(0.0, 1.0),
      (position.dy / size.height).clamp(0.0, 1.0),
    );
  }
}
