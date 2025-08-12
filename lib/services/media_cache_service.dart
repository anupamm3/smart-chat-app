import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  // Memory cache for recently accessed media
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int maxMemoryCacheSize = 50; // 50 items in memory
  static const Duration cacheExpiry = Duration(hours: 24);

  // Get cache directory
  Future<Directory> get _cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/media_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // Generate cache key from URL
  String _getCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get media from cache (memory -> disk -> network)
  Future<Uint8List?> getMedia(String url, {bool forceRefresh = false}) async {
    final cacheKey = _getCacheKey(url);
    
    if (!forceRefresh) {
      // 1. Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < cacheExpiry) {
          // print('📱 Memory cache hit for: $url');
          return _memoryCache[cacheKey];
        } else {
          _removeFromMemoryCache(cacheKey);
        }
      }

      // 2. Check disk cache
      final diskData = await _getFromDiskCache(cacheKey);
      if (diskData != null) {
        // print('💾 Disk cache hit for: $url');
        _addToMemoryCache(cacheKey, diskData);
        return diskData;
      }
    }

    // 3. Fetch from network and cache
    // print('🌐 Network fetch for: $url');
    final networkData = await _fetchFromNetwork(url);
    if (networkData != null) {
      _addToMemoryCache(cacheKey, networkData);
      _saveToDiskCache(cacheKey, networkData);
    }
    
    return networkData;
  }

  // Memory cache management
  void _addToMemoryCache(String key, Uint8List data) {
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _evictOldestFromMemory();
    }
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  void _removeFromMemoryCache(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  void _evictOldestFromMemory() {
    if (_cacheTimestamps.isEmpty) return;
    
    final oldestKey = _cacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
        .key;
    
    _removeFromMemoryCache(oldestKey);
  }

  // Disk cache operations
  Future<Uint8List?> _getFromDiskCache(String cacheKey) async {
    try {
      final cacheDir = await _cacheDir;
      final file = File('${cacheDir.path}/$cacheKey');
      
      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified) < cacheExpiry) {
          return await file.readAsBytes();
        } else {
          await file.delete(); // Remove expired cache
        }
      }
    } catch (e) {
      // print('Disk cache read error: $e');
    }
    return null;
  }

  Future<void> _saveToDiskCache(String cacheKey, Uint8List data) async {
    try {
      final cacheDir = await _cacheDir;
      final file = File('${cacheDir.path}/$cacheKey');
      await file.writeAsBytes(data);
    } catch (e) {
      // print('Disk cache write error: $e');
    }
  }

  // Network fetch with retry logic
  Future<Uint8List?> _fetchFromNetwork(String url) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Cache-Control': 'max-age=3600'},
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        // print('Network fetch attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        }
      }
    }
    return null;
  }

  // Cache management methods
  Future<void> preloadMedia(List<String> urls) async {
    for (final url in urls) {
      if (!_memoryCache.containsKey(_getCacheKey(url))) {
        getMedia(url); // Fire and forget preload
      }
    }
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    
    try {
      final cacheDir = await _cacheDir;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // print('Cache clear error: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _cacheDir;
      if (!await cacheDir.exists()) return 0;
      
      int totalSize = 0;
      await for (final file in cacheDir.list()) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // Invalidate specific media (useful when sending new media)
  Future<void> invalidateMedia(String url) async {
    final cacheKey = _getCacheKey(url);
    _removeFromMemoryCache(cacheKey);
    
    try {
      final cacheDir = await _cacheDir;
      final file = File('${cacheDir.path}/$cacheKey');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // print('Cache invalidation error: $e');
    }
  }
}