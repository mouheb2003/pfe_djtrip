import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Smart cache entry with TTL and metadata
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int accessCount;
  final DateTime lastAccessedAt;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    this.accessCount = 0,
    required this.lastAccessedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && data != null;

  CacheEntry<T> recordAccess() {
    return CacheEntry<T>(
      data: data,
      createdAt: createdAt,
      expiresAt: expiresAt,
      accessCount: accessCount + 1,
      lastAccessedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'accessCount': accessCount,
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }

  /// Parse from JSON (data is handled separately)
  static Map<String, dynamic>? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    return {
      'createdAt': DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      'expiresAt': DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      'accessCount': (json['accessCount'] ?? 0) as int,
      'lastAccessedAt': DateTime.tryParse(
        json['lastAccessedAt']?.toString() ?? '',
      ),
    };
  }
}

/// Advanced cache manager with memory + persistent storage
class CacheManager {
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  static const String _boxName = 'djtrip_cache_v2';
  static const Duration _defaultTtl = Duration(minutes: 5);

  Box<dynamic>? _hiveBox;
  final Map<String, dynamic> _memoryCache = {};

  bool get _isInitialized => _hiveBox != null;

  /// Initialize Hive storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      _hiveBox = await Hive.openBox<dynamic>(_boxName);
      _devLog('✅ CacheManager initialized');
    } catch (e) {
      _devLog('❌ CacheManager initialization failed: $e');
    }
  }

  /// Get cached data (memory first, then persistent)
  T? get<T>(String key, {bool recordAccess = true}) {
    // Check memory cache
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key];
      if (entry is CacheEntry<T>) {
        if (!entry.isExpired) {
          if (recordAccess) {
            _memoryCache[key] = entry.recordAccess();
          }
          _devLog('[CACHE HIT] $key (memory)');
          return entry.data;
        } else {
          _memoryCache.remove(key);
          _devLog('[CACHE EXPIRED] $key (memory)');
        }
      }
    }

    // Check persistent cache
    if (_isInitialized) {
      try {
        final stored = _hiveBox?.get(key);
        if (stored is Map) {
          final metadata = CacheEntry.fromJson(stored);
          if (metadata != null) {
            final expiresAt = metadata['expiresAt'] as DateTime?;
            if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
              _devLog('[CACHE HIT] $key (persistent)');
              return stored['data'] as T?;
            }
          }
        }
      } catch (e) {
        _devLog('[CACHE READ ERROR] $key: $e');
      }
    }

    _devLog('[CACHE MISS] $key');
    return null;
  }

  /// Set cache with smart invalidation
  Future<void> set<T>(
    String key,
    T data, {
    Duration ttl = _defaultTtl,
    bool overwriteIfExists = false,
  }) async {
    // 🚀 CRITICAL: Prevent overwriting valid cache with empty/null data
    if (data == null) {
      _devLog('⚠️ [CACHE SKIP] $key - data is null');
      return;
    }

    // Check if overwriting valid cache with empty collection
    if (!overwriteIfExists) {
      final existing = _memoryCache[key] as CacheEntry<T>?;
      if (existing != null && !existing.isExpired) {
        _devLog('⚠️ [CACHE SKIP] $key - valid cache exists, not overwriting');
        return;
      }
    }

    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
      accessCount: 0,
      lastAccessedAt: DateTime.now(),
    );

    // Store in memory
    _memoryCache[key] = entry;

    // Store in persistent cache
    if (_isInitialized) {
      try {
        await _hiveBox?.put(key, {...entry.toJson(), 'data': data});
        _devLog('💾 [CACHE SAVED] $key (TTL: ${ttl.inSeconds}s)');
      } catch (e) {
        _devLog('❌ [CACHE SAVE ERROR] $key: $e');
      }
    }
  }

  /// Remove specific cache entry
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    if (_isInitialized) {
      try {
        await _hiveBox?.delete(key);
        _devLog('🗑️ [CACHE REMOVED] $key');
      } catch (_) {}
    }
  }

  /// Clear all cache entries
  Future<void> clearAll() async {
    _memoryCache.clear();
    if (_isInitialized) {
      try {
        await _hiveBox?.clear();
        _devLog('🧹 [CACHE CLEARED ALL]');
      } catch (_) {}
    }
  }

  /// Remove cache by pattern (e.g., '/posts/*')
  Future<void> removeByPattern(String pattern) async {
    final regex = RegExp(pattern.replaceAll('*', '.*'), caseSensitive: false);

    final keysToRemove = _memoryCache.keys
        .where((k) => regex.hasMatch(k))
        .toList();

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    if (_isInitialized) {
      try {
        for (final key in keysToRemove) {
          await _hiveBox?.delete(key);
        }
        _devLog(
          '🗑️ [CACHE REMOVED PATTERN] $pattern (${keysToRemove.length} entries)',
        );
      } catch (_) {}
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memoryEntries': _memoryCache.length,
      'persistentEntries': _isInitialized ? (_hiveBox?.length ?? 0) : 0,
    };
  }

  void _devLog(String message) {
    if (kDebugMode) {
      debugPrint('[CACHE] $message');
    }
  }
}
