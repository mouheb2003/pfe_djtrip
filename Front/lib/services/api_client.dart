import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

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
  static final ApiService _api = ApiService.instance;

  /// Timeout for every request. Adjust in ApiConfig if needed.
  static const Duration _kTimeout = Duration(seconds: 15);

  // ──────────────────────────────────────────────────────────────
  // Public HTTP methods
  // ──────────────────────────────────────────────────────────────

  static Future<http.Response> get(
    String path, {
    bool auth = true,
    Map<String, String>? query,
  }) async {
    return _api.get(path, auth: auth, query: query, timeout: _kTimeout);
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _api.post(path, body, auth: auth, timeout: _kTimeout);
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _api.put(path, body, auth: auth, timeout: _kTimeout);
  }

  static Future<http.Response> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _api.patch(path, body, auth: auth, timeout: _kTimeout);
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    return _api.delete(path, auth: auth, timeout: _kTimeout);
  }
}
