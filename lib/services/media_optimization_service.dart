import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

class MediaOptimizationService {
  static Future<File> optimizeImage(File imageFile, {int maxWidth = 1920, int quality = 85}) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return imageFile;
    
    // Resize if too large
    img.Image resized = image;
    if (image.width > maxWidth) {
      resized = img.copyResize(image, width: maxWidth);
    }
    
    // Compress
    final compressedBytes = img.encodeJpg(resized, quality: quality);
    
    // Save optimized version
    final optimizedFile = File('${imageFile.path}_optimized.jpg');
    await optimizedFile.writeAsBytes(compressedBytes);
    
    return optimizedFile;
  }

  static Future<String> generateThumbnail(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return '';
    
    // Create small thumbnail
    final thumbnail = img.copyResize(image, width: 200, height: 200);
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: 60);
    
    // Convert to base64 for immediate display
    return 'data:image/jpeg;base64,${base64Encode(thumbnailBytes)}';
  }
}