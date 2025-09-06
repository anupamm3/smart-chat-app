import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/whiteboard_provider.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/tool_palette.dart';
import '../widgets/color_picker.dart';
import '../widgets/user_cursors.dart';

/// Main whiteboard screen
class WhiteboardScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatType;
  final List<String> participants;
  final String? title;

  const WhiteboardScreen({
    super.key,
    required this.chatId,
    required this.chatType,
    required this.participants,
    this.title,
  });

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _toolPaletteController;
  late AnimationController _colorPickerController;
  late Animation<Offset> _toolPaletteSlideAnimation;
  late Animation<Offset> _colorPickerSlideAnimation;
  
  bool _showToolPalette = true;
  bool _showColorPicker = false;
  Timer? _hideToolsTimer;
  
  // GlobalKey for capturing the canvas
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _toolPaletteController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _colorPickerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _toolPaletteSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolPaletteController,
      curve: Curves.easeInOut,
    ));
    
    _colorPickerSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _colorPickerController,
      curve: Curves.easeInOut,
    ));

    // Show tool palette initially
    _toolPaletteController.forward();
    
    // Initialize whiteboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWhiteboard();
    });
    
    // Auto-hide tools after inactivity
    _startHideToolsTimer();
  }

  @override
  void deactivate() {
    // Leave session when widget is being deactivated
    try {
      ref.read(whiteboardProvider.notifier).leaveSession();
    } catch (e) {
      debugPrint('Error leaving whiteboard session: $e');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _toolPaletteController.dispose();
    _colorPickerController.dispose();
    _hideToolsTimer?.cancel();
    super.dispose();
  }

  void _initializeWhiteboard() {
    if (!mounted) return;
    
    try {
      ref.read(whiteboardProvider.notifier).initializeWhiteboard(
        chatId: widget.chatId,
        chatType: widget.chatType,
        participants: widget.participants,
      );
    } catch (e) {
      debugPrint('Error initializing whiteboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize whiteboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startHideToolsTimer() {
    _hideToolsTimer?.cancel();
    _hideToolsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showToolPalette) {
        setState(() {
          _showToolPalette = false;
        });
        _toolPaletteController.reverse();
      }
    });
  }

  void _showTools() {
    if (!_showToolPalette) {
      setState(() {
        _showToolPalette = true;
      });
      _toolPaletteController.forward();
    }
    _startHideToolsTimer();
  }

  void _toggleColorPicker() {
    setState(() {
      _showColorPicker = !_showColorPicker;
    });
    
    if (_showColorPicker) {
      _colorPickerController.forward();
    } else {
      _colorPickerController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);
    final notifier = ref.read(whiteboardProvider.notifier);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title ?? 'Whiteboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          // Connection status
          _buildConnectionStatus(state.isConnected),
          
          // User presence indicator
          if (state.userPresence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: UserPresenceIndicator(
                userPresence: state.userPresence,
                currentUserId: currentUserId ?? '',
                onTap: _showUserList,
              ),
            ),
          
          // More options
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'undo',
                child: ListTile(
                  leading: Icon(Icons.undo),
                  title: Text('Undo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildErrorWidget(state.error!)
              : _buildWhiteboardContent(state, notifier, currentUserId),
      
      // Floating action button for tools
      floatingActionButton: _showToolPalette
          ? null
          : FloatingActionButton(
              onPressed: _showTools,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.brush),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildConnectionStatus(bool isConnected) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Live' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading whiteboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeWhiteboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteboardContent(
    WhiteboardState state,
    WhiteboardNotifier notifier,
    String? currentUserId,
  ) {
    return GestureDetector(
      onTap: _showTools,
      child: Stack(
        children: [
          // Main drawing canvas
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                
                return Stack(
                  children: [
                    // Drawing canvas wrapped in RepaintBoundary for export
                    RepaintBoundary(
                      key: _canvasKey,
                      child: DrawingCanvas(
                        strokes: [
                          ...state.strokes,
                          if (state.currentStroke != null) state.currentStroke!,
                        ],
                        selectedTool: state.selectedTool,
                        selectedColor: state.selectedColor,
                        strokeWidth: state.strokeWidth,
                      onStrokeCompleted: (stroke) async {
                        if (!mounted) return;
                        
                        try {
                          // Update the current stroke with the final stroke data
                          if (state.currentStroke != null) {
                            // Complete the stroke that was being tracked
                            await notifier.completeStroke();
                          }
                        } catch (e) {
                          debugPrint('Error completing stroke: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save drawing'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      onStrokeUpdated: (stroke) {
                        if (!mounted) return;
                        
                        try {
                          // Start stroke if not already started, or update it
                          if (state.currentStroke == null) {
                            notifier.startStrokeFromCanvas(stroke);
                          } else {
                            notifier.updateCurrentStroke(stroke.points);
                          }
                        } catch (e) {
                          debugPrint('Error updating stroke: $e');
                        }
                      },
                      onCursorMoved: (position) {
                        if (!mounted) return;
                        
                        try {
                          notifier.updateCursorPosition(position);
                        } catch (e) {
                          debugPrint('Error updating cursor: $e');
                        }
                      },
                      isEnabled: currentUserId != null,
                    ),
                  ),
                    
                    // User cursors overlay
                    if (currentUserId != null)
                      UserCursors(
                        userPresence: state.userPresence,
                        currentUserId: currentUserId,
                        canvasSize: canvasSize,
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Tool palette (left side)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SlideTransition(
              position: _toolPaletteSlideAnimation,
              child: Center(
                child: ToolPalette(
                  selectedTool: state.selectedTool,
                  onToolSelected: (tool) {
                    notifier.selectTool(tool);
                    _showTools();
                  },
                  selectedColor: state.selectedColor,
                ),
              ),
            ),
          ),
          
          // Color picker (right side)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SlideTransition(
              position: _colorPickerSlideAnimation,
              child: Center(
                child: ColorPicker(
                  selectedColor: state.selectedColor,
                  onColorSelected: (color) {
                    notifier.selectColor(color);
                    _toggleColorPicker();
                  },
                  isCompact: true,
                ),
              ),
            ),
          ),
          
          // Color picker toggle button
          if (_showToolPalette)
            Positioned(
              right: 16,
              top: 100,
              child: FloatingActionButton.small(
                heroTag: "colorPicker",
                onPressed: _toggleColorPicker,
                backgroundColor: state.selectedColor,
                child: Icon(
                  Icons.palette,
                  color: _getContrastColor(state.selectedColor),
                ),
              ),
            ),
          
          // Stroke width slider
          if (_showToolPalette)
            Positioned(
              left: 80,
              bottom: 100,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Size',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: state.strokeWidth,
                          min: 1.0,
                          max: 20.0,
                          divisions: 19,
                          onChanged: (value) {
                            notifier.setStrokeWidth(value);
                            _showTools();
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${state.strokeWidth.round()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          
          // Error snackbar
          if (state.error != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: () => notifier.clearError(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _handleMenuAction(String action) {
    final notifier = ref.read(whiteboardProvider.notifier);
    
    switch (action) {
      case 'clear':
        _showClearConfirmation();
        break;
      case 'undo':
        notifier.undoLastStroke();
        break;
      case 'export':
        _exportWhiteboard();
        break;
      case 'settings':
        _showSettings();
        break;
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Whiteboard'),
        content: const Text('Are you sure you want to clear all drawings? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(whiteboardProvider.notifier).clearWhiteboard();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _exportWhiteboard() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Capture the canvas as image
      final RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData == null) {
        throw Exception('Failed to capture whiteboard image');
      }

      // Save to downloads directory
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory? downloadsDir = await getExternalStorageDirectory();
      final String fileName = 'whiteboard_${DateTime.now().millisecondsSinceEpoch}.png';
      final File imageFile = File('${downloadsDir?.path ?? '/storage/emulated/0/Download'}/$fileName');
      
      // Ensure directory exists
      await imageFile.parent.create(recursive: true);
      await imageFile.writeAsBytes(pngBytes);

      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();

      // Show success message with option to share
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: Text('Whiteboard saved to: ${imageFile.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate back to chat and suggest sending the image
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You can now send the saved image in your chat'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                child: const Text('Go to Chat'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      debugPrint('Error exporting whiteboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export whiteboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettings() {
    // TODO: Implement settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings coming soon!')),
    );
  }

  void _showUserList() {
    final state = ref.read(whiteboardProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ...state.userPresence.entries
                .where((entry) => entry.value.isActive)
                .map((entry) {
              final presence = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: presence.userAvatarUrl != null
                      ? NetworkImage(presence.userAvatarUrl!)
                      : null,
                  child: presence.userAvatarUrl == null
                      ? Text(presence.userName.isNotEmpty
                          ? presence.userName[0].toUpperCase()
                          : '?')
                      : null,
                ),
                title: Text(presence.userName),
                subtitle: Text(presence.currentTool ?? 'No tool selected'),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
