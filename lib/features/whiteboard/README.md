# Whiteboard Feature Integration Guide

## Overview
The whiteboard feature provides a production-ready collaborative drawing experience with real-time synchronization, multiple drawing tools, and seamless integration with your chat application.

## Architecture
- **Real-time synchronization** using Firestore snapshots
- **State management** with Riverpod
- **Modular design** with separate models, services, widgets, and providers
- **Firebase integration** for persistence and user management

## Quick Integration

### 1. Add Whiteboard to Chat Screen

```dart
// In your chat screen
import 'package:smart_chat_app/features/whiteboard/whiteboard.dart';

class ChatScreen extends ConsumerWidget {
  final String chatId;
  final String chatType; // 'individual' or 'group'
  final List<String> participants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        actions: [
          // Add whiteboard launcher to app bar
          WhiteboardLauncher(
            chatId: chatId,
            chatType: chatType,
            participants: participants,
            isCompact: true, // Shows as icon button
          ),
        ],
      ),
      body: Column(
        children: [
          // Your existing chat messages
          Expanded(child: MessagesList()),
          
          // Add full whiteboard launcher in chat
          WhiteboardLauncher(
            chatId: chatId,
            chatType: chatType,
            participants: participants,
            chatTitle: 'Chat Name',
            isCompact: false, // Shows as full card
          ),
          
          // Your message input
          MessageInput(),
        ],
      ),
    );
  }
}
```

### 2. Direct Whiteboard Launch

```dart
// Launch whiteboard directly
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WhiteboardScreen(
      chatId: 'chat_123',
      chatType: 'group',
      participants: ['user1', 'user2', 'user3'],
      title: 'Team Brainstorm',
    ),
  ),
);
```

### 3. Using Whiteboard Service Directly

```dart
// Get whiteboard service
final whiteboardService = WhiteboardService.instance;

// Create a new session
final session = await whiteboardService.createSession(
  chatId: 'chat_123',
  chatType: 'group',
  participants: ['user1', 'user2'],
);

// Get existing session
final existingSession = await whiteboardService.getSessionForChat('chat_123');
```

## Features

### Drawing Tools
- **Pen**: Freeform drawing with customizable stroke width
- **Highlighter**: Semi-transparent overlay drawing
- **Eraser**: Remove parts of drawings
- **Shapes**: Rectangle, circle, line, arrow
- **Colors**: Full color palette with custom colors
- **Stroke Width**: Adjustable from 1-20px

### Real-time Collaboration
- **Live cursors**: See other users' cursor positions
- **Instant updates**: Real-time stroke synchronization
- **User presence**: Active user indicators
- **Connection status**: Online/offline indicators

### User Interface
- **Auto-hiding tools**: Tools hide after inactivity
- **Responsive design**: Works on different screen sizes
- **Gesture support**: Touch and mouse input
- **Smooth animations**: Polished user experience

## Customization

### Custom Colors
```dart
// Add custom color palette
ColorPicker(
  selectedColor: currentColor,
  onColorSelected: (color) => updateColor(color),
  customColors: [
    Colors.red,
    Colors.blue,
    Color(0xFF123456), // Custom hex colors
  ],
)
```

### Custom Tools
```dart
// Extend drawing tools
enum CustomDrawingTool {
  textTool,
  stickerTool,
  // Add your custom tools
}
```

### Theme Integration
```dart
// The widgets automatically adapt to your app's theme
ToolPalette(
  selectedTool: currentTool,
  onToolSelected: onToolSelected,
  selectedColor: Theme.of(context).colorScheme.primary,
  backgroundColor: Theme.of(context).colorScheme.surface,
)
```

## Advanced Usage

### Listen to Whiteboard Events
```dart
// Using the provider
final whiteboardState = ref.watch(whiteboardProvider);

// Listen to strokes
if (whiteboardState.strokes.isNotEmpty) {
  print('Total strokes: ${whiteboardState.strokes.length}');
}

// Listen to active users
final activeUsers = ref.watch(activeUsersProvider);
print('Active users: ${activeUsers.length}');
```

### Custom Stroke Processing
```dart
// Access individual strokes
final strokes = whiteboardState.strokes;
for (final stroke in strokes) {
  print('Stroke by ${stroke.userName}: ${stroke.points.length} points');
  print('Tool: ${stroke.tool.displayName}');
  print('Color: ${stroke.color}');
}
```

### Export Functionality
```dart
// Get all strokes for export
final whiteboardService = WhiteboardService.instance;
final strokes = await whiteboardService.exportWhiteboard(sessionId);

// Process strokes (convert to image, PDF, etc.)
// Implementation depends on your export requirements
```

## Firestore Security Rules

Add these rules to your Firestore security rules:

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Whiteboard sessions
    match /whiteboards/{sessionId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // Whiteboard strokes
    match /whiteboards/{sessionId}/strokes/{strokeId} {
      allow read, write: if request.auth != null;
      allow create: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // User presence
    match /whiteboards/{sessionId}/presence/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        request.auth.uid == userId;
    }
  }
}
```

## Performance Considerations

### Optimization Tips
1. **Stroke Batching**: Large numbers of strokes are handled efficiently
2. **Real-time Throttling**: Cursor updates are throttled to prevent spam
3. **Memory Management**: Old strokes can be archived for performance
4. **Connection Handling**: Automatic reconnection on network issues

### Monitoring
```dart
// Get session statistics
final stats = ref.read(whiteboardProvider.notifier).getStatistics();
print('Session stats: $stats');

// Monitor connection status
final isConnected = whiteboardState.isConnected;
if (!isConnected) {
  print('Whiteboard is offline');
}
```

## Error Handling

```dart
// Handle whiteboard errors
if (whiteboardState.error != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(whiteboardState.error!)),
  );
  
  // Clear error
  ref.read(whiteboardProvider.notifier).clearError();
}
```

## Testing

### Unit Tests
```dart
// Test whiteboard service
void main() {
  group('WhiteboardService', () {
    test('creates session successfully', () async {
      final service = WhiteboardService.instance;
      final session = await service.createSession(
        chatId: 'test_chat',
        chatType: 'group',
        participants: ['user1', 'user2'],
      );
      
      expect(session.chatId, equals('test_chat'));
      expect(session.participants.length, equals(2));
    });
  });
}
```

### Widget Tests
```dart
// Test whiteboard widgets
void main() {
  testWidgets('ToolPalette displays all tools', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ToolPalette(
          selectedTool: DrawingTool.pen,
          onToolSelected: (tool) {},
        ),
      ),
    );
    
    // Verify all tools are displayed
    expect(find.byIcon(Icons.edit), findsOneWidget); // Pen
    expect(find.byIcon(Icons.highlight), findsOneWidget); // Highlighter
  });
}
```

## Troubleshooting

### Common Issues

1. **Strokes not syncing**: Check Firebase authentication and Firestore rules
2. **Poor performance**: Ensure stroke batching is enabled
3. **UI not responsive**: Check if tools are properly initialized
4. **Connection issues**: Verify network connectivity and Firebase config

### Debug Mode
```dart
// Enable debug mode
const bool kDebugWhiteboard = true;

if (kDebugWhiteboard) {
  print('Whiteboard debug info: ${whiteboardState.toString()}');
}
```

## Future Enhancements

Potential features to add:
- **Text tool** for adding text annotations
- **Image import** for background images
- **Vector graphics** support
- **Collaborative cursors** with user names
- **Undo/redo** functionality
- **Layer management** for complex drawings
- **Export to PDF/PNG** functionality
- **Voice annotations** with drawing strokes
- **Template library** for common diagrams

## Support

For issues and feature requests, please refer to the project documentation or create an issue in the repository.
