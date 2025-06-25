import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? timestamp;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primary.withAlpha((0.85 * 255).toInt())
                    : colorScheme.surface.withAlpha((0.85 * 255).toInt()),
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
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(
                  '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}