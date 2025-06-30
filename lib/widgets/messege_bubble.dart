import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum MessageStatus { sent, delivered, seen }

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? timestamp;
  final MessageStatus? status;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.timestamp,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Gradient backgrounds for modern look
    Gradient? bubbleGradient;
    Color? bubbleColor;
    if (isMe) {
      bubbleGradient = LinearGradient(
        colors: [
          colorScheme.primary.withAlpha((0.95 * 255).toInt()),
          colorScheme.primary.withAlpha((0.75 * 255).toInt()),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      bubbleGradient = LinearGradient(
        colors: [
          colorScheme.surfaceContainerHighest.withAlpha((0.95 * 255).toInt()),
          colorScheme.surface.withAlpha((0.85 * 255).toInt()),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    Color tickColor = Colors.grey;
    IconData tickIcon = Icons.check;
    Widget tickWidget = const SizedBox.shrink();

    if (isMe && status != null) {
      switch (status!) {
        case MessageStatus.sent:
          tickIcon = Icons.check;
          tickColor = Colors.grey;
          break;
        case MessageStatus.delivered:
          tickIcon = Icons.done_all;
          tickColor = Colors.grey;
          break;
        case MessageStatus.seen:
          tickIcon = Icons.done_all;
          tickColor = Colors.blue;
          break;
      }
      tickWidget = Icon(tickIcon, size: 16, color: tickColor);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            gradient: bubbleGradient,
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.outline.withAlpha((0.08 * 255).toInt()),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Message text
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: isMe
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withAlpha((0.9 * 255).toInt()),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Time and tick
              if (timestamp != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isMe
                            ? colorScheme.onPrimary.withAlpha((0.8 * 255).toInt())
                            : colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                      ),
                    ),
                    if (isMe && status != null) ...[
                      const SizedBox(width: 2),
                      tickWidget,
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}