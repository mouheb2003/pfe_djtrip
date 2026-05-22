import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';

class FollowService {
  // Follow a user
  static Future<Map<String, dynamic>> followUser(String followingId) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'followingId': followingId}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Error following user',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Unfollow a user
  static Future<Map<String, dynamic>> unfollowUser(String followingId) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final response = await http.delete(
        Uri.parse('${ApiClient.baseUrl}/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'followingId': followingId}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Error unfollowing user',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Check if following a user
  static Future<bool> checkFollowStatus(String followingId) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        return false;
      }

      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/follow/check/$followingId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['isFollowing'] ?? false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Get followers count
  static Future<int> getFollowersCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/follow/followers/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['count'] ?? 0;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Get following count
  static Future<int> getFollowingCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/follow/following/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['count'] ?? 0;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Get followers list
  static Future<List<Map<String, dynamic>>> getFollowersList(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/follow/followers/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['followers'] != null) {
          return List<Map<String, dynamic>>.from(body['followers']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get following list
  static Future<List<Map<String, dynamic>>> getFollowingList(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/follow/following/$userId'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['following'] != null) {
          return List<Map<String, dynamic>>.from(body['following']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
