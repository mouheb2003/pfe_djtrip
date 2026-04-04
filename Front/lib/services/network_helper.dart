import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Network request result wrapper
class NetworkResult<T> {
  final T? data;
  final String? error;
  final bool success;
  final int statusCode;
  final bool isRetry;
  final int attemptNumber;
  final DateTime timestamp;

  const NetworkResult({
    this.data,
    this.error,
    required this.success,
    required this.statusCode,
    this.isRetry = false,
    this.attemptNumber = 1,
    required this.timestamp,
  });

  factory NetworkResult.success(T data, int statusCode, {int attempt = 1}) {
    return NetworkResult(
      data: data,
      success: true,
      statusCode: statusCode,
      attemptNumber: attempt,
      timestamp: DateTime.now(),
    );
  }

  factory NetworkResult.failure(String error, int statusCode, {int attempt = 1}) {
    return NetworkResult(
      error: error,
      success: false,
      statusCode: statusCode,
      attemptNumber: attempt,
      timestamp: DateTime.now(),
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 503 || statusCode == 0;
}

/// Network resilience helper with retry logic
class NetworkHelper {
  NetworkHelper._();

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const Duration _timeout = Duration(seconds: 15);

  /// Execute request with automatic retry and timeout
  static Future<NetworkResult<T>> executeWithRetry<T>(
    Future<http.Response> Function() request, {
    required T Function(String) parseSuccess,
    int maxRetries = _maxRetries,
    Duration retryDelay = _retryDelay,
    Duration timeout = _timeout,
    String? endpoint,
  }) async {
    Object? lastError;
    http.Response? lastResponse;

    for (int attempt = 1; attempt <= maxRetries + 1; attempt++) {
      try {
        _devLog(
          '[RETRY] START attempt $attempt/${ maxRetries + 1} - ${endpoint ?? 'request'}',
        );

        // Execute request with timeout
        final response = await request().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
              'Request timeout after ${timeout.inSeconds}s',
            );
          },
        );

        lastResponse = response;

        // Success - return data
        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final parsed = parseSuccess(response.body);
            _devLog(
              '[RETRY] SUCCESS after $attempt attempt(s) - ${endpoint ?? 'request'}',
            );
            return NetworkResult.success(
              parsed,
              response.statusCode,
              attempt: attempt,
            );
          } catch (e) {
            _devLog('[RETRY] Parsing error: $e');
            lastError = e;
            if (attempt == maxRetries + 1) {
              return NetworkResult.failure(
                'Failed to parse response: $e',
                response.statusCode,
                attempt: attempt,
              );
            }
          }
        }

        // Client error - don't retry
        if (response.statusCode >= 400 && response.statusCode < 500) {
          _devLog(
            '[RETRY] CLIENT ERROR ${response.statusCode} - ${endpoint ?? 'request'}',
          );
          return NetworkResult.failure(
            'Client error: ${response.statusCode}',
            response.statusCode,
            attempt: attempt,
          );
        }

        // Server error or network issue - can retry
        if (response.statusCode >= 500 || response.statusCode == 0) {
          _devLog(
            '[RETRY] SERVER/NETWORK ERROR ${response.statusCode} - attempt $attempt',
          );
          if (attempt < maxRetries + 1) {
            await Future.delayed(retryDelay * attempt); // Exponential backoff
            continue;
          }
        }

        lastError = 'HTTP ${response.statusCode}';
      } on TimeoutException catch (e) {
        _devLog('[RETRY] TIMEOUT - attempt $attempt');
        lastError = 'Timeout: ${e.message}';

        if (attempt < maxRetries + 1) {
          await Future.delayed(retryDelay * attempt);
          continue;
        }
      } catch (e) {
        _devLog('[RETRY] ERROR attempt $attempt: $e');
        lastError = e;

        if (attempt < maxRetries + 1) {
          await Future.delayed(retryDelay * attempt);
          continue;
        }
      }
    }

    // All retries exhausted
    final errorMsg = 'Request failed after ${maxRetries + 1} attempts: $lastError';
    _devLog('[RETRY] FAILED - $errorMsg');

    return NetworkResult.failure(
      errorMsg,
      lastResponse?.statusCode ?? 503,
      attempt: maxRetries + 1,
    );
  }

  /// Check if error is retryable
  static bool isRetryable(int statusCode) {
    // Retry on server errors and network issues, but not on client errors
    return statusCode >= 500 || statusCode == 0 || statusCode == 408;
  }

  /// Get backoff duration for attempt number
  static Duration getBackoffDuration(int attemptNumber) {
    // Exponential backoff: 500ms, 1s, 2s, etc.
    return Duration(milliseconds: 500 * (attemptNumber ~/ 1));
  }

  static void _devLog(String message) {
    if (kDebugMode) {
      debugPrint('[NETWORK] $message');
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
