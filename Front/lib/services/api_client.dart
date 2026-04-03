import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

/// Standardized API result wrapper
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final int statusCode;

  ApiResult._({
    this.data,
    this.error,
    required this.isSuccess,
    required this.statusCode,
  });

  factory ApiResult.success(T data, int statusCode) {
    return ApiResult._(data: data, isSuccess: true, statusCode: statusCode);
  }

  factory ApiResult.failure(String error, int statusCode) {
    return ApiResult._(error: error, isSuccess: false, statusCode: statusCode);
  }

  bool get hasData => data != null;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}

/// Pagination info from response
class PaginatedInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginatedInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginatedInfo.fromJson(Map<String, dynamic> json) {
    return PaginatedInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
    );
  }
}

class ApiClient {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Timeout for every request. Adjust in ApiConfig if needed.
  static const Duration _kTimeout = Duration(seconds: 15);

  /// Returned when back-end doesn't respond in time.
  static http.Response get _timeoutResponse => http.Response(
    '{"message":"Connection timed out. Please check your network."}',
    408,
  );

  // ──────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await AuthService.getAccessToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// Silently try to refresh the access token and repeat [retry].
  static Future<http.Response> _withRefresh(
    Future<http.Response> Function() retry,
  ) async {
    final refreshed = await AuthService.refreshAccessToken();
    if (refreshed) return retry();
    throw Exception('Session expired. Please sign in again.');
  }

  // ──────────────────────────────────────────────────────────────
  // Public HTTP methods
  // ──────────────────────────────────────────────────────────────

  static Future<http.Response> get(
    String path, {
    bool auth = true,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = await _headers(auth: auth);
    try {
      final res = await http
          .get(uri, headers: headers)
          .timeout(_kTimeout, onTimeout: () => _timeoutResponse);
      if (res.statusCode == 401 && auth) {
        return _withRefresh(() => get(path, auth: auth, query: query));
      }
      return res;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    try {
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_kTimeout, onTimeout: () => _timeoutResponse);
      if (res.statusCode == 401 && auth) {
        return _withRefresh(() => post(path, body, auth: auth));
      }
      return res;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    try {
      final res = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(_kTimeout, onTimeout: () => _timeoutResponse);
      if (res.statusCode == 401 && auth) {
        return _withRefresh(() => put(path, body, auth: auth));
      }
      return res;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<http.Response> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    try {
      final res = await http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(_kTimeout, onTimeout: () => _timeoutResponse);
      if (res.statusCode == 401 && auth) {
        return _withRefresh(() => patch(path, body, auth: auth));
      }
      return res;
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(auth: auth);
    try {
      final res = await http
          .delete(uri, headers: headers)
          .timeout(_kTimeout, onTimeout: () => _timeoutResponse);
      if (res.statusCode == 401 && auth) {
        return _withRefresh(() => delete(path, auth: auth));
      }
      return res;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Response handlers
  // ──────────────────────────────────────────────────────────────

  static http.Response _handleError(dynamic error) {
    String message;
    if (error.toString().contains('SocketException')) {
      message = 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Connection timed out. Please try again.';
    } else {
      message = 'An unexpected error occurred.';
    }
    return http.Response('{"success": false, "message": "$message"}', 500);
  }
}
