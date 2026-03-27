import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class UserService {
  /// Fetch the current user's profile from the backend & update local cache.
  static Future<UserModel?> getProfile() async {
    try {
      final res = await ApiClient.get('/users/me');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (body['user'] ?? body) as Map<String, dynamic>;
        await AuthService.saveUser(data);
        return UserModel.fromJson(data);
      }
    } catch (_) {
      // Keep null on failures to avoid crashing profile screens.
    }
    return null;
  }

  /// Update profile fields. Returns `{success, user?, message?}`.
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await ApiClient.put('/users/me', data);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final user = (body['user'] ?? body) as Map<String, dynamic>;
        await AuthService.saveUser(user);
        return {'success': true, 'user': user};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Update error',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Unable to reach the server. Check your connection.',
      };
    }
  }

  /// Upload a new avatar image.
  static Future<bool> updateAvatar(File imageFile) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return false;
      final uri = Uri.parse('${ApiClient.baseUrl}/users/me/avatar');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath('avatar', imageFile.path),
        );
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final user = body['user'];
          if (user is Map<String, dynamic>) {
            await AuthService.saveUser(user);
          }
        } catch (_) {}
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get a public user profile by id (no auth required).
  static Future<UserModel?> getUserById(String userId) async {
    final res = await ApiClient.get('/users/$userId', auth: false);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return UserModel.fromJson((body['user'] ?? body) as Map<String, dynamic>);
    }
    return null;
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
      final res = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'centres_interet': interests}),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get current user's favourite activities.
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final res = await ApiClient.get('/users/me/favorites');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is List) {
        return List<Map<String, dynamic>>.from(body);
      }
      final list = body['favorites'] ?? body;
      if (list is List) {
        return List<Map<String, dynamic>>.from(list);
      }
    }
    return [];
  }

  /// Add an activity to favourites. Returns updated list or null on fail.
  static Future<bool> addFavorite(String activityId) async {
    final res = await ApiClient.post('/users/me/favorites/$activityId', {});
    return res.statusCode == 200 || res.statusCode == 201;
  }

  /// Remove an activity from favourites.
  static Future<bool> removeFavorite(String activityId) async {
    final res = await ApiClient.delete('/users/me/favorites/$activityId');
    return res.statusCode == 200;
  }
}
