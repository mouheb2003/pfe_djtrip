import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import 'storage_service.dart';
import 'http_client.dart';

class UserService {
  // Update user profile avec auto-refresh du token
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> updateData,
  ) async {
    try {
      final headers = await HttpClient.getAuthHeaders();

      final response = await HttpClient.put(
        ApiConfig.updateProfile,
        headers: headers,
        body: jsonEncode(updateData),
        timeout: ApiConfig.connectionTimeout,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        return {'success': true, 'message': data['message'], 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error updating profile',
        };
      }
    } on TokenExpiredException catch (e) {
      return {'success': false, 'message': e.message, 'requiresLogin': true};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Get user information avec auto-refresh du token
  static Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final headers = await HttpClient.getAuthHeaders();

      final response = await HttpClient.get(
        ApiConfig.myInfo,
        headers: headers,
        timeout: ApiConfig.connectionTimeout,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error retrieving information',
        };
      }
    } on TokenExpiredException catch (e) {
      return {'success': false, 'message': e.message, 'requiresLogin': true};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Update avatar - accepts File object or path string
  static Future<Map<String, dynamic>> uploadAvatar(dynamic avatar) async {
    try {
      final accessToken = await StorageService.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.updateAvatar),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      // Support both File object and path string
      if (avatar is File) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', avatar.path),
        );
      } else if (avatar is String) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatar));
      } else {
        return {'success': false, 'message': 'Invalid avatar parameter'};
      }

      final streamedResponse = await request.send().timeout(
        ApiConfig.connectionTimeout,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        return {
          'success': true,
          'message': data['message'],
          'avatar': data['avatar'],
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error uploading avatar',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Legacy method for backward compatibility
  static Future<Map<String, dynamic>> updateAvatar(String avatarPath) async {
    return uploadAvatar(avatarPath);
  }

  // Update notification preferences
  static Future<Map<String, dynamic>> updateNotificationPreferences({
    required bool emailNotifications,
    required bool smsNotifications,
  }) async {
    return updateProfile({
      'notifications_email': emailNotifications,
      'notifications_sms': smsNotifications,
    });
  }

  // Update account status (for administrator)
  static Future<Map<String, dynamic>> updateAccountStatus(
    String userId,
    String status,
  ) async {
    try {
      final accessToken = await StorageService.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/users/$userId/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error updating status',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Get current account status
  static Future<Map<String, dynamic>> getAccountStatus() async {
    try {
      final result = await getUserInfo();
      if (result['success']) {
        final User user = result['user'];
        return {
          'success': true,
          'status': user.status,
          'derniereConnexion': user.derniereConnexion,
        };
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Update interests (preferences)
  static Future<Map<String, dynamic>> updatePreferences(
    List<String> preferences,
  ) async {
    return updateProfile({'centres_interet': preferences});
  }
}
