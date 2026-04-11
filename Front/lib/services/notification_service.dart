import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class NotificationService {
  static Future<Map<String, dynamic>> getUserNotifications({
    String? type,
    bool unreadOnly = false,
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      List<String> queryParams = [];
      
      if (type != null) queryParams.add('type=$type');
      if (unreadOnly) queryParams.add('unread_only=true');
      if (limit != 20) queryParams.add('limit=$limit');
      if (skip != 0) queryParams.add('skip=$skip');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      
      final response = await ApiClient.get('/notifications$queryString');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'notifications': body['notifications'] ?? [],
        'pagination': body['pagination'] ?? {},
      };
    } catch (_) {
      return {
        'success': false,
        'notifications': [],
        'pagination': {},
      };
    }
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final response = await ApiClient.get('/notifications/unread-count');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'unread_count': body['unread_count'] ?? 0,
      };
    } catch (_) {
      return {'success': false, 'unread_count': 0};
    }
  }

  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final response = await ApiClient.patch('/notifications/$notificationId/read', {});
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Notification marked as read',
      };
    } catch (_) {
      return {'success': false, 'message': 'Failed to mark notification as read'};
    }
  }

  static Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await ApiClient.patch('/notifications/read-all', {});
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'All notifications marked as read',
        'modified_count': body['modifiedCount'] ?? 0,
      };
    } catch (_) {
      return {'success': false, 'message': 'Failed to mark all notifications as read'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final response = await ApiClient.delete('/notifications/$notificationId');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Notification deleted',
      };
    } catch (_) {
      return {'success': false, 'message': 'Failed to delete notification'};
    }
  }

  static Future<Map<String, dynamic>> getAllNotifications({
    String? type,
    String? targetRole,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      List<String> queryParams = [];
      
      if (type != null) queryParams.add('type=$type');
      if (targetRole != null) queryParams.add('target_role=$targetRole');
      if (limit != 50) queryParams.add('limit=$limit');
      if (skip != 0) queryParams.add('skip=$skip');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      
      final response = await ApiClient.get('/notifications/admin$queryString');
      
      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'notifications': body['notifications'] ?? [],
        'pagination': body['pagination'] ?? {},
      };
    } catch (_) {
      return {
        'success': false,
        'notifications': [],
        'pagination': {},
      };
    }
  }

  // WebSocket connection for real-time notifications
  static Future<void> connectWebSocket(String userId, Function(Map<String, dynamic>) onNotification) async {
    try {
      // This would connect to WebSocket for real-time updates
      // Implementation depends on your WebSocket setup
      print('WebSocket connection for user: $userId');
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  // Polling fallback for notifications
  static Future<void> startPolling(String userId, Function(int) onUnreadCount) async {
    int lastCount = 0;
    
    while (true) {
      try {
        final result = await getUnreadCount();
        if (result['success'] && result['unread_count'] != lastCount) {
          lastCount = result['unread_count'];
          onUnreadCount(lastCount);
        }
        
        // Wait 30 seconds before next poll
        await Future.delayed(const Duration(seconds: 30));
      } catch (e) {
        print('Error polling notifications: $e');
        await Future.delayed(const Duration(seconds: 30));
      }
    }
  }
}
