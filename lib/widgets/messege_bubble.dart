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

    // Updated: Remove gradient for outgoing (isMe) to improve tick readability.
    Gradient? bubbleGradient;
    Color? bubbleColor;

    if (isMe) {
      bubbleColor = colorScheme.primary; // solid color
    } else {
      bubbleColor = colorScheme.surfaceContainerHighest; // solid color
      // bubbleGradient = LinearGradient(
      //   colors: [
      //     colorScheme.surfaceContainerHighest.withAlpha((0.95 * 255).toInt()),
      //     colorScheme.surface.withAlpha((0.85 * 255).toInt()),
      //   ],
      //   begin: Alignment.topLeft,
      //   end: Alignment.bottomRight,
      // );
    }

    // Text & time colors
    final textColor = isMe
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withAlpha((0.9 * 255).toInt());
    final timeColor = isMe
        ? colorScheme.onPrimary.withAlpha((0.7 * 255).toInt())
        : colorScheme.onSurface.withAlpha((0.7 * 255).toInt());

    // Status / ticks
    Color tickColor = timeColor;
    IconData? tickIcon;

    if (isMe && status != null) {
      switch (status!) {
        case MessageStatus.sent:
          tickIcon = Icons.check;
          tickColor = timeColor;
          break;
        case MessageStatus.delivered:
          tickIcon = Icons.done_all;
          tickColor = timeColor;
          break;
        case MessageStatus.seen:
          tickIcon = Icons.done_all;
          tickColor = isMe
              ? const Color.fromARGB(255, 36, 154, 205)
              : colorScheme.primary;
          break;
      }
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
                color: colorScheme.outline.withAlpha((0.06 * 255).toInt()),
                blurRadius: 4,
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
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Time + tick
              if (timestamp != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: timeColor,
                      ),
                    ),
                    if (isMe && tickIcon != null) ...[
                      const SizedBox(width: 3),
                      Icon(tickIcon, size: 15, color: tickColor),
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