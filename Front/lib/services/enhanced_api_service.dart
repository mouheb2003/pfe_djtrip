import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'cache_manager.dart';
import 'network_helper.dart';

/// Unified API response wrapper
class ApiResponse<T> {
  final T? data;
  final String message;
  final bool isSuccess;
  final int statusCode;
  final String? rawError;
  final DateTime timestamp;

  const ApiResponse({
    this.data,
    required this.message,
    required this.isSuccess,
    required this.statusCode,
    this.rawError,
    required this.timestamp,
  });

  factory ApiResponse.success({
    required T data,
    String message = 'Success',
    int statusCode = 200,
  }) {
    return ApiResponse(
      data: data,
      message: message,
      isSuccess: true,
      statusCode: statusCode,
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.failure({
    required String message,
    int statusCode = 500,
    String? rawError,
  }) {
    return ApiResponse(
      message: message,
      isSuccess: false,
      statusCode: statusCode,
      rawError: rawError,
      timestamp: DateTime.now(),
    );
  }

  bool get hasData => data != null;
}

/// Enhanced API service with robust caching and retry logic
class EnhancedApiService {
  EnhancedApiService._();

  static final EnhancedApiService instance = EnhancedApiService._();
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const String _headerAuth = 'Authorization';

  final http.Client _client = http.Client();
  final CacheManager _cache = CacheManager.instance;
  bool _initialized = false;

  /// Initialize service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _cache.initialize();
    _devLog('✅ EnhancedApiService initialized');
  }

  /// Get with cache-first strategy
  Future<ApiResponse<Map<String, dynamic>>> getCached(
    String endpoint, {
    bool auth = true,
    Map<String, String>? query,
    Duration? cacheTtl,
  }) async {
    // Try cache first
    final cacheKey =
        'GET:$endpoint${query != null ? '?' + query.toString() : ''}';
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);

    if (cached != null) {
      _devLog('[API CACHE HIT] $endpoint');
      return ApiResponse.success(data: cached);
    }

    // Fetch from network
    _devLog('[API FETCH] GET $endpoint');
    final response = await NetworkHelper.executeWithRetry(
      () => _buildGet(endpoint, auth: auth, query: query),
      parseSuccess: (body) => _parseJson(body),
      endpoint: endpoint,
    );

    if (response.success) {
      _devLog(
        '[API SUCCESS] GET $endpoint (attempt ${response.attemptNumber})',
      );
      // Cache successful response
      await _cache.set(
        cacheKey,
        response.data as Map<String, dynamic>,
        ttl: cacheTtl ?? _cacheTtl,
      );
      return ApiResponse.success(data: response.data as Map<String, dynamic>);
    }

    _devLog('[API FAILED] GET $endpoint: ${response.error}');
    return ApiResponse.failure(
      message: response.error ?? 'Unknown error',
      statusCode: response.statusCode,
    );
  }

  /// POST with cache invalidation
  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    _devLog('[API FETCH] POST $endpoint');

    final response = await NetworkHelper.executeWithRetry(
      () => _buildPost(endpoint, body, auth: auth),
      parseSuccess: (body) => _parseJson(body),
      endpoint: endpoint,
    );

    if (response.success) {
      _devLog(
        '[API SUCCESS] POST $endpoint (attempt ${response.attemptNumber})',
      );

      // Invalidate related caches
      await _invalidateCacheForEndpoint(endpoint);

      return ApiResponse.success(data: response.data as Map<String, dynamic>);
    }

    _devLog('[API FAILED] POST $endpoint: ${response.error}');
    return ApiResponse.failure(
      message: response.error ?? 'Unknown error',
      statusCode: response.statusCode,
    );
  }

  /// PUT with cache invalidation
  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    _devLog('[API FETCH] PUT $endpoint');

    final response = await NetworkHelper.executeWithRetry(
      () => _buildPut(endpoint, body, auth: auth),
      parseSuccess: (body) => _parseJson(body),
      endpoint: endpoint,
    );

    if (response.success) {
      _devLog(
        '[API SUCCESS] PUT $endpoint (attempt ${response.attemptNumber})',
      );

      // Invalidate related caches
      await _invalidateCacheForEndpoint(endpoint);

      return ApiResponse.success(data: response.data as Map<String, dynamic>);
    }

    _devLog('[API FAILED] PUT $endpoint: ${response.error}');
    return ApiResponse.failure(
      message: response.error ?? 'Unknown error',
      statusCode: response.statusCode,
    );
  }

  /// PATCH with cache invalidation
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    _devLog('[API FETCH] PATCH $endpoint');

    final response = await NetworkHelper.executeWithRetry(
      () => _buildPatch(endpoint, body, auth: auth),
      parseSuccess: (body) => _parseJson(body),
      endpoint: endpoint,
    );

    if (response.success) {
      _devLog(
        '[API SUCCESS] PATCH $endpoint (attempt ${response.attemptNumber})',
      );

      // Invalidate related caches
      await _invalidateCacheForEndpoint(endpoint);

      return ApiResponse.success(data: response.data as Map<String, dynamic>);
    }

    _devLog('[API FAILED] PATCH $endpoint: ${response.error}');
    return ApiResponse.failure(
      message: response.error ?? 'Unknown error',
      statusCode: response.statusCode,
    );
  }

  /// DELETE with cache invalidation
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    bool auth = true,
  }) async {
    _devLog('[API FETCH] DELETE $endpoint');

    final response = await NetworkHelper.executeWithRetry(
      () => _buildDelete(endpoint, auth: auth),
      parseSuccess: (body) => _parseJson(body),
      endpoint: endpoint,
    );

    if (response.success) {
      _devLog(
        '[API SUCCESS] DELETE $endpoint (attempt ${response.attemptNumber})',
      );

      // Invalidate related caches
      await _invalidateCacheForEndpoint(endpoint);

      return ApiResponse.success(data: response.data as Map<String, dynamic>);
    }

    _devLog('[API FAILED] DELETE $endpoint: ${response.error}');
    return ApiResponse.failure(
      message: response.error ?? 'Unknown error',
      statusCode: response.statusCode,
    );
  }

  // ──────────────────────────────────── PRIVATE ────────────────────────────────────

  Future<http.Response> _buildGet(
    String endpoint, {
    required bool auth,
    Map<String, String>? query,
  }) async {
    final headers = await _buildHeaders(auth: auth);
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final uriWithQuery = query != null
        ? uri.replace(queryParameters: query)
        : uri;

    return _client.get(uriWithQuery, headers: headers);
  }

  Future<http.Response> _buildPost(
    String endpoint,
    Map<String, dynamic> body, {
    required bool auth,
  }) async {
    final headers = await _buildHeaders(auth: auth);
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return _client.post(uri, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> _buildPut(
    String endpoint,
    Map<String, dynamic> body, {
    required bool auth,
  }) async {
    final headers = await _buildHeaders(auth: auth);
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return _client.put(uri, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> _buildPatch(
    String endpoint,
    Map<String, dynamic> body, {
    required bool auth,
  }) async {
    final headers = await _buildHeaders(auth: auth);
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return _client.patch(uri, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> _buildDelete(
    String endpoint, {
    required bool auth,
  }) async {
    final headers = await _buildHeaders(auth: auth);
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return _client.delete(uri, headers: headers);
  }

  Future<Map<String, String>> _buildHeaders({required bool auth}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers[_headerAuth] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Smart JSON parsing
  Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      _devLog('❌ JSON parse error: $e');
      return {};
    }
  }

  /// Invalidate cache for mutating operations
  Future<void> _invalidateCacheForEndpoint(String endpoint) async {
    // Extract base path (e.g., '/posts/123' -> '/posts/*')
    final basePath = endpoint.split('/').take(2).join('/');
    await _cache.removeByPattern('GET:$basePath.*');
    _devLog('🗑️ [CACHE INVALIDATED] Pattern: GET:$basePath.*');
  }

  void _devLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
