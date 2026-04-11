import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'navigation_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? raw;

  const ApiResponse({
    required this.success,
    required this.message,
    required this.statusCode,
    this.data,
    this.raw,
  });
}

class _CacheItem {
  final String body;
  final int statusCode;
  final DateTime expiresAt;
  final DateTime updatedAt;

  const _CacheItem({
    required this.body,
    required this.statusCode,
    required this.expiresAt,
    required this.updatedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'statusCode': statusCode,
      'expiresAt': expiresAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static _CacheItem? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;

    final body = json['body']?.toString() ?? '';
    final statusCode = (json['statusCode'] as num?)?.toInt() ?? 200;
    final expiresAtRaw = json['expiresAt']?.toString();
    final updatedAtRaw = json['updatedAt']?.toString();
    if (expiresAtRaw == null || updatedAtRaw == null) return null;

    final expiresAt = DateTime.tryParse(expiresAtRaw);
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (expiresAt == null || updatedAt == null) return null;

    return _CacheItem(
      body: body,
      statusCode: statusCode,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
    );
  }
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const int _maxRetries = 2;
  static const Duration _cacheTtl = Duration(seconds: 60);
  static const Duration _backgroundRefreshMinInterval = Duration(seconds: 12);
  static const String _cacheBoxName = 'api_cache_v1';

  final Map<String, _CacheItem> _memoryCache = <String, _CacheItem>{};
  final Map<String, Future<http.Response>> _inFlightGetRequests =
      <String, Future<http.Response>>{};
  final Set<String> _backgroundRefreshingKeys = <String>{};
  final Map<String, DateTime> _lastBackgroundRefreshAt = <String, DateTime>{};

  final http.Client _client = http.Client();
  Box<dynamic>? _cacheBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Hive.initFlutter();
      _cacheBox = await Hive.openBox<dynamic>(_cacheBoxName);
    } catch (_) {
      _cacheBox = null;
    }
  }

  Future<void> warmUp() async {
    await initialize();
    await get('/health', auth: false, timeout: const Duration(seconds: 25));
  }

  Future<Map<String, String>> _buildHeaders({
    required bool auth,
    Map<String, String>? headers,
  }) async {
    final merged = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        merged['Authorization'] = 'Bearer $token';
      }
    }

    if (headers != null) {
      merged.addAll(headers);
    }

    return merged;
  }

  void _devLog(String message) {
    if (kDebugMode) {
      debugPrint('[API] $message');
    }
  }

  static String _cacheKey(String method, Uri uri) =>
      '$method:${uri.toString()}';

  _CacheItem? _readCache(String key) {
    final memory = _memoryCache[key];
    if (memory != null && !memory.isExpired) {
      return memory;
    }

    final persisted = _CacheItem.fromJson(
      _cacheBox?.get(key) as Map<dynamic, dynamic>?,
    );
    if (persisted == null) return null;

    if (persisted.isExpired) {
      _memoryCache.remove(key);
      _cacheBox?.delete(key);
      return null;
    }

    _memoryCache[key] = persisted;
    return persisted;
  }

  void _writeCache(String key, http.Response response, Duration ttl) {
    final item = _CacheItem(
      body: response.body,
      statusCode: response.statusCode,
      expiresAt: DateTime.now().add(ttl),
      updatedAt: DateTime.now(),
    );

    _memoryCache[key] = item;
    _cacheBox?.put(key, item.toJson());
  }

  Future<void> invalidateByPrefix(String prefix) async {
    final keys = _memoryCache.keys.where((k) => k.contains(prefix)).toList();
    for (final key in keys) {
      _memoryCache.remove(key);
      await _cacheBox?.delete(key);
    }
  }

  Future<void> _invalidateByMutationPath(String path) async {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final firstSegment = clean.split('/').first;
    if (firstSegment.isEmpty) {
      await invalidateByPrefix('GET:${ApiConfig.baseUrl}');
      return;
    }

    final prefix = 'GET:${ApiConfig.baseUrl}/$firstSegment';
    await invalidateByPrefix(prefix);
    _devLog('[CACHE INVALIDATE] $prefix');
  }

  Future<http.Response> _offlineResponse() async {
    return http.Response(
      jsonEncode({
        'success': false,
        'message': 'No internet connection. Please check your network.',
      }),
      503,
      headers: {'content-type': 'application/json'},
    );
  }

  http.Response _safeErrorResponse(String message, int statusCode) {
    return http.Response(
      jsonEncode({'success': false, 'message': message}),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<http.Response> _sendWithRetry({
    required String label,
    required Future<http.Response> Function() request,
    required Duration timeout,
    required bool auth,
    required Future<http.Response> Function() retryOriginal,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        _devLog('[API CALL] $label attempt ${attempt + 1}/${_maxRetries + 1}');
        final response = await request().timeout(timeout);

        if (response.statusCode == 401 && auth) {
          final refreshed = await AuthService.refreshAccessToken();
          if (refreshed) {
            return retryOriginal();
          }

          await AuthService.clearLocalSession();
          await NavigationService.forceLogoutToLogin(
            message: 'Session expired. Please sign in again.',
          );
          return response;
        }

        if (response.statusCode == 403 && auth) {
          try {
            final body = jsonDecode(response.body);
            print('[API 403] Full response body: $body');
            print('[API 403] forceLogout: ${body['forceLogout']}');
            print('[API 403] type: ${body['type']}');
            print('[API 403] suspendedUntil: ${body['suspendedUntil']} (${body['suspendedUntil']?.runtimeType})');
            print('[API 403] remainingSeconds: ${body['remainingSeconds']}');
            if (body is Map && body['forceLogout'] == true) {
              final restriction = <String, dynamic>{};
              final type = body['type']?.toString().trim() ?? '';
              final fromMessage = body['message']?.toString().trim() ?? '';
              final fromReason = body['reason']?.toString().trim() ?? '';
              final suspendedUntil = body['suspendedUntil'];
              final remainingSeconds = body['remainingSeconds'];

              print('[API 403] Extracted - type: $type, suspendedUntil: $suspendedUntil, remainingSeconds: $remainingSeconds');

              if (type.isNotEmpty) restriction['type'] = type;
              if (fromReason.isNotEmpty) restriction['reason'] = fromReason;
              if (suspendedUntil != null) {
                restriction['suspendedUntil'] = suspendedUntil.toString();
              }
              if (remainingSeconds != null) {
                restriction['remainingSeconds'] = remainingSeconds;
              }

              final popupMessage = fromMessage.isNotEmpty
                  ? fromMessage
                  : (fromReason.isNotEmpty
                        ? fromReason
                        : 'Your account is restricted.');

              if (popupMessage.isNotEmpty) {
                restriction['message'] = popupMessage;
              }

              print('[API 403] Final restriction map: $restriction');
              await AuthService.clearLocalSession();
              _devLog('[RESTRICT] type=' + (restriction['type']?.toString() ?? '-') +
                  ' remaining=' + (restriction['remainingSeconds']?.toString() ?? '-') +
                  ' until=' + (restriction['suspendedUntil']?.toString() ?? '-'));
              await NavigationService.forceLogoutToLogin(
                message: popupMessage,
                restriction: restriction,
              );
            }
          } catch (_) {}
        }

        if (response.statusCode >= 500 && attempt < _maxRetries) {
          _devLog('[RETRY] $label due to server ${response.statusCode}');
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }

        return response;
      } on TimeoutException {
        lastError = 'Connection timed out. Please try again.';
        if (attempt < _maxRetries) {
          _devLog('[RETRY] $label due to timeout');
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }
      } catch (error) {
        lastError = error;
        if (attempt < _maxRetries) {
          _devLog('[RETRY] $label due to error: $error');
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }
      }
    }

    final msg = lastError is String ? lastError : 'Unable to reach server.';
    return _safeErrorResponse(msg, 500);
  }

  bool _shouldWriteCache(String key, http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(body);
      final hasExistingCache = _memoryCache.containsKey(key);

      if (decoded is Map && decoded.isEmpty && hasExistingCache) {
        _devLog('[CACHE SKIP] empty object for $key');
        return false;
      }

      if (decoded is List && decoded.isEmpty && hasExistingCache) {
        _devLog('[CACHE SKIP] empty list for $key');
        return false;
      }
    } catch (_) {
      // Keep non-JSON responses cacheable when successful.
    }

    return true;
  }

  void _triggerBackgroundRefresh({
    required String key,
    required String path,
    required bool auth,
    Map<String, String>? query,
    Map<String, String>? headers,
    required Duration timeout,
    required Duration cacheTtl,
  }) {
    final now = DateTime.now();
    final lastRefresh = _lastBackgroundRefreshAt[key];

    if (lastRefresh != null &&
        now.difference(lastRefresh) < _backgroundRefreshMinInterval) {
      return;
    }

    if (_backgroundRefreshingKeys.contains(key)) {
      return;
    }

    _lastBackgroundRefreshAt[key] = now;
    _backgroundRefreshingKeys.add(key);

    unawaited(
      _refreshGetInBackground(
        cacheKey: key,
        path,
        auth: auth,
        query: query,
        headers: headers,
        timeout: timeout,
        cacheTtl: cacheTtl,
      ),
    );
  }

  Future<void> _refreshGetInBackground(
    String path, {
    required String cacheKey,
    required bool auth,
    Map<String, String>? query,
    Map<String, String>? headers,
    required Duration timeout,
    required Duration cacheTtl,
  }) async {
    try {
      final online = await ConnectivityService.isOnline();
      if (!online) return;

      await get(
        path,
        auth: auth,
        query: query,
        headers: headers,
        timeout: timeout,
        cacheFirst: false,
        cacheTtl: cacheTtl,
      );
    } finally {
      _backgroundRefreshingKeys.remove(cacheKey);
    }
  }

  Future<http.Response> get(
    String path, {
    bool auth = true,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
    bool cacheFirst = true,
    Duration cacheTtl = _cacheTtl,
  }) async {
    await initialize();

    final online = await ConnectivityService.isOnline();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query);
    _devLog('[API CALL] GET FULL URL: ${uri.toString()}');
    final key = _cacheKey('GET', uri);

    if (cacheFirst) {
      final cached = _readCache(key);
      if (cached != null) {
        _devLog('[CACHE HIT] GET $path');
        _triggerBackgroundRefresh(
          key: key,
          path: path,
          auth: auth,
          query: query,
          headers: headers,
          timeout: timeout,
          cacheTtl: cacheTtl,
        );
        return http.Response(
          cached.body,
          cached.statusCode,
          headers: {'x-cache': 'HIT'},
        );
      }
    }

    final inFlight = _inFlightGetRequests[key];
    if (inFlight != null) {
      _devLog('[API CALL] GET dedup $path');
      return inFlight;
    }

    if (!online) {
      return _offlineResponse();
    }

    final requestHeaders = await _buildHeaders(auth: auth, headers: headers);
    _devLog('[CACHE MISS] GET $path');

    final requestFuture = _sendWithRetry(
      label: 'GET $path',
      timeout: timeout,
      auth: auth,
      request: () => _client.get(uri, headers: requestHeaders),
      retryOriginal: () => get(
        path,
        auth: auth,
        query: query,
        headers: headers,
        timeout: timeout,
        cacheFirst: false,
        cacheTtl: cacheTtl,
      ),
    );

    _inFlightGetRequests[key] = requestFuture;
    try {
      final response = await requestFuture;
      if (_shouldWriteCache(key, response)) {
        _writeCache(key, response, cacheTtl);
      }
      return response;
    } finally {
      _inFlightGetRequests.remove(key);
    }
  }

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    await initialize();

    final online = await ConnectivityService.isOnline();
    if (!online) return _offlineResponse();

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    _devLog('[API CALL] POST FULL URL: ${uri.toString()}');
    final requestHeaders = await _buildHeaders(auth: auth, headers: headers);

    http.Response response = await _sendWithRetry(
      label: 'POST $path',
      timeout: timeout,
      auth: auth,
      request: () =>
          _client.post(uri, headers: requestHeaders, body: jsonEncode(body)),
      retryOriginal: () =>
          post(path, body, auth: auth, headers: headers, timeout: timeout),
    );

    // Fallback automatique entre /api et /api/v1 si route introuvable (404)
    if (response.statusCode == 404) {
      try {
        final bodyJson = safeDecodeObject(response.body);
        final msg = bodyJson['message']?.toString() ?? '';
        if (msg.toLowerCase().contains('route not found')) {
          final original = uri;
          Uri? alt;
          final p = original.path;
          if (p.startsWith('/api/v1/')) {
            alt = original.replace(path: p.replaceFirst('/api/v1/', '/api/'));
          } else if (p.startsWith('/api/')) {
            alt = original.replace(path: p.replaceFirst('/api/', '/api/v1/'));
          }
          if (alt != null) {
            _devLog('[API FALLBACK] Retrying with: ${alt.toString()}');
            response = await _client.post(
              alt,
              headers: requestHeaders,
              body: jsonEncode(body),
            );
          }
        }
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _invalidateByMutationPath(path);
    }

    return response;
  }

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    await initialize();

    final online = await ConnectivityService.isOnline();
    if (!online) return _offlineResponse();

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    _devLog('[API CALL] PUT FULL URL: ${uri.toString()}');
    final requestHeaders = await _buildHeaders(auth: auth, headers: headers);

    final response = await _sendWithRetry(
      label: 'PUT $path',
      timeout: timeout,
      auth: auth,
      request: () =>
          _client.put(uri, headers: requestHeaders, body: jsonEncode(body)),
      retryOriginal: () =>
          put(path, body, auth: auth, headers: headers, timeout: timeout),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _invalidateByMutationPath(path);
    }

    return response;
  }

  Future<http.Response> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    await initialize();

    final online = await ConnectivityService.isOnline();
    if (!online) return _offlineResponse();

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    _devLog('[API CALL] PATCH FULL URL: ${uri.toString()}');
    final requestHeaders = await _buildHeaders(auth: auth, headers: headers);

    final response = await _sendWithRetry(
      label: 'PATCH $path',
      timeout: timeout,
      auth: auth,
      request: () =>
          _client.patch(uri, headers: requestHeaders, body: jsonEncode(body)),
      retryOriginal: () =>
          patch(path, body, auth: auth, headers: headers, timeout: timeout),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _invalidateByMutationPath(path);
    }

    return response;
  }

  Future<http.Response> delete(
    String path, {
    bool auth = true,
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    await initialize();

    final online = await ConnectivityService.isOnline();
    if (!online) return _offlineResponse();

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    _devLog('[API CALL] DELETE FULL URL: ${uri.toString()}');
    final requestHeaders = await _buildHeaders(auth: auth, headers: headers);

    final response = await _sendWithRetry(
      label: 'DELETE $path',
      timeout: timeout,
      auth: auth,
      request: () => _client.delete(uri, headers: requestHeaders),
      retryOriginal: () =>
          delete(path, auth: auth, headers: headers, timeout: timeout),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _invalidateByMutationPath(path);
    }

    return response;
  }

  static Map<String, dynamic> safeDecodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static List<dynamic> safeDecodeList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) return decoded;
      return const <dynamic>[];
    } catch (_) {
      return const <dynamic>[];
    }
  }
}
