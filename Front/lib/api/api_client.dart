import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.1.191:3000/api';

  static Future<Map<String, String>> _getAuthHeaders(bool auth) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await AuthService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<http.Response> get(
    String endpoint, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = await _getAuthHeaders(auth);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    return await http.get(uri, headers: requestHeaders);
  }

  static Future<http.Response> post(
    String endpoint,
    dynamic body, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = await _getAuthHeaders(auth);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    return await http.post(
      uri,
      headers: requestHeaders,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    dynamic body, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = await _getAuthHeaders(auth);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    return await http.put(uri, headers: requestHeaders, body: jsonEncode(body));
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = await _getAuthHeaders(auth);
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    return await http.delete(uri, headers: requestHeaders);
  }
}
