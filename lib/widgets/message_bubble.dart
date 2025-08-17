import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_chat_app/services/media_cache_service.dart';

enum MessageStatus { sent, delivered, seen }

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? timestamp;
  final MessageStatus? status;
  // New media parameters
  final String? mediaUrl;
  final String? mediaType;
  final String? fileName;
  final int? fileSize;
  final String? mediaThumbnail;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.timestamp,
    this.status,
    this.mediaUrl,
    this.mediaType,
    this.fileName,
    this.fileSize,
    this.mediaThumbnail,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Media content
              if (mediaUrl != null) ...[
                _buildMediaWidget(context, colorScheme),
                if (text.isNotEmpty) const SizedBox(height: 8),
              ],
              // Text and timestamp row
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Message text (only if not empty)
                  if (text.isNotEmpty)
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaWidget(BuildContext context, ColorScheme colorScheme) {
    if (mediaUrl == null || mediaType == null) return const SizedBox.shrink();

    switch (mediaType) {
      case 'image':
        return _buildImageWidget(context);
      case 'video':
        return _buildVideoWidget(context);
      case 'audio':
        return _buildAudioWidget(context, colorScheme);
      case 'document':
        return _buildDocumentWidget(context, colorScheme);
      default:
        return _buildGenericMediaWidget(context, colorScheme);
    }
  }

  Widget _buildImageWidget(BuildContext context) {
    const double imageWidth = 220;
    const double imageHeight = 220;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: imageWidth,
        height: imageHeight,
        color: Colors.grey[300],
        child: FutureBuilder<Uint8List?>(
          future: MediaCacheService().getMedia(mediaUrl!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: imageWidth,
                height: imageHeight,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return GestureDetector(
                onTap: () async {
                  await MediaCacheService().invalidateMedia(mediaUrl!);
                  (context as Element).markNeedsBuild();
                },
                child: Container(
                  width: imageWidth,
                  height: imageHeight,
                  color: Colors.grey[300],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to retry',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Image.memory(
              snapshot.data!,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoWidget(BuildContext context) {
    const double videoWidth = 220;
    const double videoHeight = 220;
    final thumbnailUrl = mediaThumbnail ?? mediaUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: videoWidth,
        height: videoHeight,
        color: Colors.grey[300],
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              thumbnailUrl!,
              width: videoWidth,
              height: videoHeight,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: videoWidth,
                  height: videoHeight,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: videoWidth,
                  height: videoHeight,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.videocam, size: 48, color: Colors.grey)),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.6 * 255).toInt()),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioWidget(BuildContext context, ColorScheme colorScheme) {
    final iconColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe 
          ? colorScheme.onPrimary.withAlpha((0.1 * 255).toInt())
          : colorScheme.surface.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audiotrack, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Icon(Icons.play_arrow, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: iconColor.withAlpha((0.3 * 255).toInt()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0:00',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: iconColor.withAlpha((0.7 * 255).toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentWidget(BuildContext context, ColorScheme colorScheme) {
    final iconColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe 
          ? colorScheme.onPrimary.withAlpha((0.1 * 255).toInt())
          : colorScheme.surface.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName ?? 'Document',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize!),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: iconColor.withAlpha((0.7 * 255).toInt()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericMediaWidget(BuildContext context, ColorScheme colorScheme) {
    final iconColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe 
          ? colorScheme.onPrimary.withAlpha((0.1 * 255).toInt())
          : colorScheme.surface.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attachment, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Text(
            'Media file',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}