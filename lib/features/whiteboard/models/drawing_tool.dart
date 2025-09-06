import 'package:flutter/material.dart';

/// Enum defining available drawing tools
enum DrawingTool {
  pen,
  highlighter,
  eraser,
  line,
  rectangle,
  circle,
  arrow,
}

/// Extension for DrawingTool with properties and utilities
extension DrawingToolExtension on DrawingTool {
  /// Get the display name for the tool
  String get displayName {
    switch (this) {
      case DrawingTool.pen:
        return 'Pen';
      case DrawingTool.highlighter:
        return 'Highlighter';
      case DrawingTool.eraser:
        return 'Eraser';
      case DrawingTool.line:
        return 'Line';
      case DrawingTool.rectangle:
        return 'Rectangle';
      case DrawingTool.circle:
        return 'Circle';
      case DrawingTool.arrow:
        return 'Arrow';
    }
  }

  /// Get the icon for the tool
  IconData get icon {
    switch (this) {
      case DrawingTool.pen:
        return Icons.edit;
      case DrawingTool.highlighter:
        return Icons.highlight;
      case DrawingTool.eraser:
        return Icons.cleaning_services;
      case DrawingTool.line:
        return Icons.horizontal_rule;
      case DrawingTool.rectangle:
        return Icons.crop_3_2_outlined;
      case DrawingTool.circle:
        return Icons.circle_outlined;
      case DrawingTool.arrow:
        return Icons.arrow_right_alt;
    }
  }

  /// Get default stroke width for the tool
  double get defaultStrokeWidth {
    switch (this) {
      case DrawingTool.pen:
        return 2.0;
      case DrawingTool.highlighter:
        return 8.0;
      case DrawingTool.eraser:
        return 12.0;
      case DrawingTool.line:
        return 2.0;
      case DrawingTool.rectangle:
        return 2.0;
      case DrawingTool.circle:
        return 2.0;
      case DrawingTool.arrow:
        return 2.0;
    }
  }

  /// Get default opacity for the tool
  double get defaultOpacity {
    switch (this) {
      case DrawingTool.pen:
        return 1.0;
      case DrawingTool.highlighter:
        return 0.6;
      case DrawingTool.eraser:
        return 1.0;
      case DrawingTool.line:
        return 1.0;
      case DrawingTool.rectangle:
        return 1.0;
      case DrawingTool.circle:
        return 1.0;
      case DrawingTool.arrow:
        return 1.0;
    }
  }

  /// Check if tool supports fill
  bool get supportsFill {
    switch (this) {
      case DrawingTool.pen:
      case DrawingTool.highlighter:
      case DrawingTool.eraser:
      case DrawingTool.line:
      case DrawingTool.arrow:
        return false;
      case DrawingTool.rectangle:
      case DrawingTool.circle:
        return true;
    }
  }

  /// Check if tool is a shape tool
  bool get isShape {
    switch (this) {
      case DrawingTool.pen:
      case DrawingTool.highlighter:
      case DrawingTool.eraser:
        return false;
      case DrawingTool.line:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.arrow:
        return true;
    }
  }

  /// Get stroke cap style for the tool
  StrokeCap get strokeCap {
    switch (this) {
      case DrawingTool.pen:
      case DrawingTool.line:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.arrow:
        return StrokeCap.round;
      case DrawingTool.highlighter:
        return StrokeCap.square;
      case DrawingTool.eraser:
        return StrokeCap.round;
    }
  }

  /// Get blend mode for the tool
  BlendMode get blendMode {
    switch (this) {
      case DrawingTool.pen:
      case DrawingTool.highlighter:
      case DrawingTool.line:
      case DrawingTool.rectangle:
      case DrawingTool.circle:
      case DrawingTool.arrow:
        return BlendMode.srcOver;
      case DrawingTool.eraser:
        return BlendMode.clear;
    }
  }
}

/// Tool configuration class
class ToolConfiguration {
  final DrawingTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool isFilled;
  final StrokeCap strokeCap;
  final BlendMode blendMode;

  const ToolConfiguration({
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    this.isFilled = false,
    required this.strokeCap,
    required this.blendMode,
  });

  /// Create default configuration for a tool
  factory ToolConfiguration.defaultFor(DrawingTool tool) {
    return ToolConfiguration(
      tool: tool,
      color: tool == DrawingTool.highlighter ? Colors.yellow : Colors.black,
      strokeWidth: tool.defaultStrokeWidth,
      opacity: tool.defaultOpacity,
      isFilled: false,
      strokeCap: tool.strokeCap,
      blendMode: tool.blendMode,
    );
  }

  /// Copy with new values
  ToolConfiguration copyWith({
    DrawingTool? tool,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isFilled,
    StrokeCap? strokeCap,
    BlendMode? blendMode,
  }) {
    return ToolConfiguration(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isFilled: isFilled ?? this.isFilled,
      strokeCap: strokeCap ?? this.strokeCap,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  /// Get effective color with opacity
  Color get effectiveColor {
    return color.withOpacity(opacity);
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'tool': tool.index,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'isFilled': isFilled,
      'strokeCap': strokeCap.index,
      'blendMode': blendMode.index,
    };
  }

  /// Create from map
  factory ToolConfiguration.fromMap(Map<String, dynamic> map) {
    return ToolConfiguration(
      tool: DrawingTool.values[map['tool'] ?? 0],
      color: Color(map['color'] ?? 0xFF000000),
      strokeWidth: map['strokeWidth']?.toDouble() ?? 2.0,
      opacity: map['opacity']?.toDouble() ?? 1.0,
      isFilled: map['isFilled'] ?? false,
      strokeCap: StrokeCap.values[map['strokeCap'] ?? 1],
      blendMode: BlendMode.values[map['blendMode'] ?? 3],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolConfiguration &&
        other.tool == tool &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        other.opacity == opacity &&
        other.isFilled == isFilled &&
        other.strokeCap == strokeCap &&
        other.blendMode == blendMode;
  }

  @override
  int get hashCode {
    return tool.hashCode ^
        color.hashCode ^
        strokeWidth.hashCode ^
        opacity.hashCode ^
        isFilled.hashCode ^
        strokeCap.hashCode ^
        blendMode.hashCode;
  }
}
