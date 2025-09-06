import 'package:flutter/material.dart';

/// Color picker widget for selecting drawing colors
class ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;
  final List<Color>? customColors;
  final bool showDefaultColors;
  final bool isCompact;
  final double? colorSize;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.customColors,
    this.showDefaultColors = true,
    this.isCompact = false,
    this.colorSize,
  });

  static const List<Color> defaultColors = [
    Colors.black,
    Colors.white,
    Colors.grey,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = customColors ?? defaultColors;
    final effectiveColorSize = colorSize ?? (isCompact ? 32.0 : 40.0);

    return Container(
      padding: EdgeInsets.all(isCompact ? 8.0 : 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? _buildCompactGrid(colors, effectiveColorSize)
          : _buildRegularGrid(colors, effectiveColorSize),
    );
  }

  Widget _buildCompactGrid(List<Color> colors, double size) {
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: colors.map((color) {
        return _ColorButton(
          color: color,
          isSelected: color == selectedColor,
          onPressed: () => onColorSelected(color),
          size: size,
        );
      }).toList(),
    );
  }

  Widget _buildRegularGrid(List<Color> colors, double size) {
    const itemsPerRow = 4;
    final rows = <Widget>[];

    for (int i = 0; i < colors.length; i += itemsPerRow) {
      final rowColors = colors.skip(i).take(itemsPerRow).toList();
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: rowColors.map((color) {
            return Padding(
              padding: const EdgeInsets.all(2.0),
              child: _ColorButton(
                color: color,
                isSelected: color == selectedColor,
                onPressed: () => onColorSelected(color),
                size: size,
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

/// Individual color button widget
class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;
  final double size;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : color == Colors.white
                    ? Colors.grey.shade300
                    : Colors.transparent,
            width: isSelected ? 3.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 8.0,
                spreadRadius: 2.0,
              ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _getContrastColor(color),
                size: size * 0.5,
              )
            : null,
      ),
    );
  }

  Color _getContrastColor(Color background) {
    // Calculate relative luminance
    final luminance = background.computeLuminance();
    // Return black for light colors, white for dark colors
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Advanced color picker with HSV sliders
class AdvancedColorPicker extends StatefulWidget {
  final Color initialColor;
  final Function(Color) onColorChanged;
  final bool showAlpha;

  const AdvancedColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.showAlpha = false,
  });

  @override
  State<AdvancedColorPicker> createState() => _AdvancedColorPickerState();
}

class _AdvancedColorPickerState extends State<AdvancedColorPicker> {
  late HSVColor _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          // Color preview
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: _currentColor.toColor(),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Hue slider
          _ColorSlider(
            label: 'Hue',
            value: _currentColor.hue,
            max: 360.0,
            onChanged: (value) {
              setState(() {
                _currentColor = _currentColor.withHue(value);
              });
              widget.onColorChanged(_currentColor.toColor());
            },
            gradientColors: [
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.pinkAccent,
              Colors.red,
            ],
          ),

          // Saturation slider
          _ColorSlider(
            label: 'Saturation',
            value: _currentColor.saturation,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _currentColor = _currentColor.withSaturation(value);
              });
              widget.onColorChanged(_currentColor.toColor());
            },
            gradientColors: [
              HSVColor.fromAHSV(1.0, _currentColor.hue, 0.0, _currentColor.value).toColor(),
              HSVColor.fromAHSV(1.0, _currentColor.hue, 1.0, _currentColor.value).toColor(),
            ],
          ),

          // Value (brightness) slider
          _ColorSlider(
            label: 'Brightness',
            value: _currentColor.value,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _currentColor = _currentColor.withValue(value);
              });
              widget.onColorChanged(_currentColor.toColor());
            },
            gradientColors: [
              Colors.black,
              HSVColor.fromAHSV(1.0, _currentColor.hue, _currentColor.saturation, 1.0).toColor(),
            ],
          ),

          // Alpha slider (if enabled)
          if (widget.showAlpha)
            _ColorSlider(
              label: 'Opacity',
              value: _currentColor.alpha,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _currentColor = _currentColor.withAlpha(value);
                });
                widget.onColorChanged(_currentColor.toColor());
              },
              gradientColors: [
                _currentColor.toColor().withOpacity(0.0),
                _currentColor.toColor().withOpacity(1.0),
              ],
            ),
        ],
      ),
    );
  }
}

/// Custom slider widget for color values
class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Function(double) onChanged;
  final List<Color> gradientColors;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                max == 1.0 
                    ? '${(value * 100).round()}%'
                    : '${value.round()}°',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Container(
            height: 24.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 24.0,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: 12.0,
                  elevation: 4.0,
                ),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 20.0),
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.2),
              ),
              child: Slider(
                value: value,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact color picker that shows just a few common colors
class CompactColorPicker extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;

  const CompactColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<Color> commonColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.grey,
  ];

  @override
  Widget build(BuildContext context) {
    return ColorPicker(
      selectedColor: selectedColor,
      onColorSelected: onColorSelected,
      customColors: commonColors,
      isCompact: true,
      colorSize: 28.0,
    );
  }
}

/// Color picker dialog
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String? title;
  final bool showAdvanced;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title,
    this.showAdvanced = false,
  });

  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    String? title,
    bool showAdvanced = false,
  }) {
    return showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: initialColor,
        title: title,
        showAdvanced: showAdvanced,
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title != null ? Text(widget.title!) : null,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
            if (widget.showAdvanced) ...[
              const SizedBox(height: 16.0),
              AdvancedColorPicker(
                initialColor: _selectedColor,
                onColorChanged: (color) {
                  setState(() {
                    _selectedColor = color;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
