import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import 'auth_service.dart';

class UserService {
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        print('🔒 No access token found');
        return null;
      }

      print('🌐 Fetching user profile...');
      final response = await http
          .get(
            Uri.parse('${ApiClient.baseUrl}/users/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⏱️ Profile request timed out after 30 seconds');
              throw Exception('Request timeout');
            },
          );

      print('📥 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Profile loaded successfully');
        return data['user'];
      }
      print('❌ Failed to load profile: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Profile updated successfully',
        'user': responseData['user'],
      };
    } catch (e) {
      print('Error updating profile: $e');
      return {'success': false, 'message': 'Error updating profile'};
    }
  }

  static Future<bool> updateAvatar(File avatarFile) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiClient.baseUrl}/users/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatarFile.path),
      );

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating avatar: $e');
      return false;
    }
  }

  // 🚀 NEW: Privacy settings methods
  static Future<Map<String, dynamic>> updatePrivacySettings(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/users/privacy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Privacy settings updated',
      };
    } catch (e) {
      print('Error updating privacy settings: $e');
      return {'success': false, 'message': 'Error updating privacy settings'};
    }
  }

  static Future<Map<String, dynamic>> updateAdvancedSettings(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('${ApiClient.baseUrl}/users/advanced-privacy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Advanced settings updated',
      };
    } catch (e) {
      print('Error updating advanced settings: $e');
      return {'success': false, 'message': 'Error updating advanced settings'};
    }
  }

  /// Get a public user profile by id (no auth required).
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['user'] ?? body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user by id: $e');
      return null;
    }
  }

  /// Update tourist interests.
  static Future<bool> updateInterests(
    String touristeId,
    List<String> interests,
  ) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return false;

      final uri = Uri.parse(
        '${ApiClient.baseUrl}/touristes/$touristeId/centres-interet',
      );
      final response = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'centres_interet': interests}),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating interests: $e');
      return false;
    }
  }

  /// Get current user's favourite activities.
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/users/me/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          return List<Map<String, dynamic>>.from(body);
        }
        final list = body['favorites'] ?? body;
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
      return [];
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  /// Add an activity to favourites. Returns updated list or null on fail.
  static Future<bool> addFavorite(String activityId) async {
    try {
      final response = await ApiClient.post(
        '/users/me/favorites/$activityId',
        {},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error adding favorite: $e');
      return false;
    }
  }

  /// Remove an activity from favourites.
  static Future<bool> removeFavorite(String activityId) async {
    try {
      final response = await ApiClient.delete(
        '/users/me/favorites/$activityId',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error removing favorite: $e');
      return false;
    }
  }

  /// Delete user account permanently.
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await ApiClient.delete('/users/me');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Account deleted successfully'};
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete account',
      };
    } catch (e) {
      print('Error deleting account: $e');
      return {'success': false, 'message': 'Error deleting account: $e'};
    }
  }
}
