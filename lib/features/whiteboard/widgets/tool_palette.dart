import 'package:flutter/material.dart';
import '../models/drawing_tool.dart';

/// Widget for selecting drawing tools
class ToolPalette extends StatelessWidget {
  final DrawingTool selectedTool;
  final Function(DrawingTool) onToolSelected;
  final bool isVertical;
  final double? iconSize;
  final Color? selectedColor;
  final Color? backgroundColor;

  const ToolPalette({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    this.isVertical = true,
    this.iconSize,
    this.selectedColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = DrawingTool.values;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isVertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildToolButtons(context, tools),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildToolButtons(context, tools),
            ),
    );
  }

  List<Widget> _buildToolButtons(BuildContext context, List<DrawingTool> tools) {
    return tools.map((tool) {
      return _ToolButton(
        tool: tool,
        isSelected: tool == selectedTool,
        onPressed: () => onToolSelected(tool),
        iconSize: iconSize,
        selectedColor: selectedColor,
      );
    }).toList();
  }
}

/// Individual tool button widget
class _ToolButton extends StatelessWidget {
  final DrawingTool tool;
  final bool isSelected;
  final VoidCallback onPressed;
  final double? iconSize;
  final Color? selectedColor;

  const _ToolButton({
    required this.tool,
    required this.isSelected,
    required this.onPressed,
    this.iconSize,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconSize = iconSize ?? 24.0;
    final effectiveSelectedColor = selectedColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: isSelected 
            ? effectiveSelectedColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            width: effectiveIconSize + 16,
            height: effectiveIconSize + 16,
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(
                      color: effectiveSelectedColor,
                      width: 2.0,
                    )
                  : null,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              tool.icon,
              size: effectiveIconSize,
              color: isSelected
                  ? effectiveSelectedColor
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable tool palette that can be collapsed/expanded
class ExpandableToolPalette extends StatefulWidget {
  final DrawingTool selectedTool;
  final Function(DrawingTool) onToolSelected;
  final bool initiallyExpanded;
  final String? title;
  final Color? selectedColor;
  final Color? backgroundColor;

  const ExpandableToolPalette({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    this.initiallyExpanded = true,
    this.title,
    this.selectedColor,
    this.backgroundColor,
  });

  @override
  State<ExpandableToolPalette> createState() => _ExpandableToolPaletteState();
}

class _ExpandableToolPaletteState extends State<ExpandableToolPalette>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and expand/collapse button
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12.0),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.title != null) ...[
                    Text(
                      widget.title!,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8.0),
                  ],
                  Icon(
                    widget.selectedTool.icon,
                    size: 20.0,
                    color: widget.selectedColor ?? theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.expand_more,
                      size: 20.0,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Tool palette (expandable)
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: ToolPalette(
              selectedTool: widget.selectedTool,
              onToolSelected: widget.onToolSelected,
              selectedColor: widget.selectedColor,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating tool palette that can be positioned anywhere
class FloatingToolPalette extends StatefulWidget {
  final DrawingTool selectedTool;
  final Function(DrawingTool) onToolSelected;
  final Offset initialPosition;
  final bool isDraggable;
  final Color? selectedColor;
  final Color? backgroundColor;
  final VoidCallback? onClose;

  const FloatingToolPalette({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    this.initialPosition = const Offset(20.0, 100.0),
    this.isDraggable = true,
    this.selectedColor,
    this.backgroundColor,
    this.onClose,
  });

  @override
  State<FloatingToolPalette> createState() => _FloatingToolPaletteState();
}

class _FloatingToolPaletteState extends State<FloatingToolPalette> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: widget.isDraggable
          ? Draggable(
              feedback: Material(
                child: _buildPalette(context, isDragging: true),
              ),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  _position = details.offset;
                });
              },
              child: _buildPalette(context),
            )
          : _buildPalette(context),
    );
  }

  Widget _buildPalette(BuildContext context, {bool isDragging = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12.0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ToolPalette(
            selectedTool: widget.selectedTool,
            onToolSelected: widget.onToolSelected,
            selectedColor: widget.selectedColor,
            backgroundColor: widget.backgroundColor,
          ),
          if (widget.onClose != null)
            Positioned(
              right: -8,
              top: -8,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
