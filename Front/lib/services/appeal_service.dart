import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AppealService {
  static Future<Map<String, dynamic>> submitAppeal({
    required String subject,
    required String message,
    List<String>? attachments,
  }) async {
    try {
      final response = await ApiClient.post('/appeals', {
        'subject': subject,
        'message': message,
        'attachments': attachments ?? [],
      });

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 201,
        'message': body['message'] ?? 'Unable to submit appeal',
        'appeal': body['appeal'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to submit appeal right now.'};
    }
  }

  static Future<Map<String, dynamic>> getUserAppeals({
    String? status,
    int limit = 10,
  }) async {
    try {
      String queryParams = '';
      if (status != null) {
        queryParams += '?status=$status';
      }
      if (limit != 10) {
        queryParams += queryParams.isEmpty ? '?limit=$limit' : '&limit=$limit';
      }

      final response = await ApiClient.get('/appeals/me$queryParams');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'appeals': body['appeals'] ?? [],
        'count': body['count'] ?? 0,
      };
    } catch (_) {
      return {'success': false, 'appeals': [], 'count': 0};
    }
  }

  static Future<Map<String, dynamic>> getAppealDetails(String appealId) async {
    try {
      final response = await ApiClient.get('/appeals/admin/$appealId');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'appeal': body['appeal'],
      };
    } catch (_) {
      return {'success': false, 'appeal': null};
    }
  }

  static Future<Map<String, dynamic>> getAllAppeals({
    String? status,
    String? search,
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      List<String> queryParams = [];
      
      if (status != null) queryParams.add('status=$status');
      if (search != null) queryParams.add('search=$search');
      if (limit != 20) queryParams.add('limit=$limit');
      if (skip != 0) queryParams.add('skip=$skip');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      
      final response = await ApiClient.get('/appeals/admin$queryString');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'appeals': body['appeals'] ?? [],
        'total': body['total'] ?? 0,
        'limit': body['limit'] ?? limit,
        'skip': body['skip'] ?? skip,
        'hasMore': body['hasMore'] ?? false,
      };
    } catch (_) {
      return {
        'success': false,
        'appeals': [],
        'total': 0,
        'limit': limit,
        'skip': skip,
        'hasMore': false,
      };
    }
  }

  static Future<Map<String, dynamic>> updateAppealStatus(
    String appealId,
    String status, {
    String? adminResponse,
  }) async {
    try {
      final response = await ApiClient.patch('/appeals/admin/$appealId', {
        'status': status,
        'admin_response': adminResponse,
      });

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Unable to update appeal status',
        'appeal': body['appeal'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update appeal status right now.'};
    }
  }

  static Future<Map<String, dynamic>> getAppealStats() async {
    try {
      final response = await ApiClient.get('/appeals/admin/stats');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'pending': body['pending'] ?? 0,
        'reviewed': body['reviewed'] ?? 0,
        'accepted': body['accepted'] ?? 0,
        'rejected': body['rejected'] ?? 0,
        'last24h': body['last24h'] ?? 0,
      };
    } catch (_) {
      return {
        'success': false,
        'pending': 0,
        'reviewed': 0,
        'accepted': 0,
        'rejected': 0,
        'last24h': 0,
      };
    }
  }
}
