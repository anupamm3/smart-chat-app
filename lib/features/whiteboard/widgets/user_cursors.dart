import 'package:flutter/material.dart';
import '../models/whiteboard_session.dart';

/// Widget to display user cursors on the whiteboard
class UserCursors extends StatelessWidget {
  final Map<String, UserPresence> userPresence;
  final String currentUserId;
  final Size canvasSize;

  const UserCursors({
    super.key,
    required this.userPresence,
    required this.currentUserId,
    required this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out current user and inactive users
    final activeOtherUsers = userPresence.entries
        .where((entry) => 
            entry.key != currentUserId && 
            entry.value.isActive &&
            entry.value.cursorPosition != null)
        .toList();

    if (activeOtherUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: activeOtherUsers.map((entry) {
        final userId = entry.key;
        final presence = entry.value;
        
        return UserCursor(
          userId: userId,
          userName: presence.userName,
          avatarUrl: presence.userAvatarUrl,
          position: presence.cursorPosition!,
          canvasSize: canvasSize,
          userColor: _getUserColor(userId),
        );
      }).toList(),
    );
  }

  /// Generate a consistent color for each user based on their ID
  Color _getUserColor(String userId) {
    final hash = userId.hashCode;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[hash.abs() % colors.length];
  }
}

/// Individual user cursor widget
class UserCursor extends StatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final Offset position;
  final Size canvasSize;
  final Color userColor;

  const UserCursor({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.position,
    required this.canvasSize,
    required this.userColor,
  });

  @override
  State<UserCursor> createState() => _UserCursorState();
}

class _UserCursorState extends State<UserCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Convert normalized position to screen position
    final screenPosition = Offset(
      widget.position.dx * widget.canvasSize.width,
      widget.position.dy * widget.canvasSize.height,
    );

    return Positioned(
      left: screenPosition.dx - 12, // Offset for cursor center
      top: screenPosition.dy - 12,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: _buildCursor(),
          );
        },
      ),
    );
  }

  Widget _buildCursor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cursor indicator
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: widget.userColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    widget.avatarUrl!,
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackAvatar();
                    },
                  ),
                )
              : _buildFallbackAvatar(),
        ),
        
        const SizedBox(height: 4),
        
        // User name label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: widget.userColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar() {
    return Icon(
      Icons.person,
      size: 16,
      color: Colors.white,
    );
  }
}

/// Animated cursor that appears when user starts drawing
class DrawingCursor extends StatefulWidget {
  final Offset position;
  final Size canvasSize;
  final Color color;
  final double strokeWidth;
  final bool isVisible;

  const DrawingCursor({
    super.key,
    required this.position,
    required this.canvasSize,
    required this.color,
    required this.strokeWidth,
    this.isVisible = true,
  });

  @override
  State<DrawingCursor> createState() => _DrawingCursorState();
}

class _DrawingCursorState extends State<DrawingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(DrawingCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Convert normalized position to screen position
    final screenPosition = Offset(
      widget.position.dx * widget.canvasSize.width,
      widget.position.dy * widget.canvasSize.height,
    );

    final cursorSize = widget.strokeWidth * 2;

    return Positioned(
      left: screenPosition.dx - cursorSize / 2,
      top: screenPosition.dy - cursorSize / 2,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: cursorSize,
              height: cursorSize,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget showing presence indicators for all users
class UserPresenceIndicator extends StatelessWidget {
  final Map<String, UserPresence> userPresence;
  final String currentUserId;
  final VoidCallback? onTap;

  const UserPresenceIndicator({
    super.key,
    required this.userPresence,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeUsers = userPresence.values
        .where((presence) => presence.isActive)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatars
            ...activeUsers.take(3).map((presence) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: _getUserColor(presence.userId),
                  backgroundImage: presence.userAvatarUrl != null
                      ? NetworkImage(presence.userAvatarUrl!)
                      : null,
                  child: presence.userAvatarUrl == null
                      ? Text(
                          presence.userName.isNotEmpty
                              ? presence.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              );
            }),
            
            if (activeUsers.length > 3)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+${activeUsers.length - 3}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            // Online indicator
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 4),
            
            Text(
              '${activeUsers.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUserColor(String userId) {
    final hash = userId.hashCode;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[hash.abs() % colors.length];
  }
}
