import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';
import 'api_service.dart';

class PostService {
  // ✅ ADDED
  static Map<String, dynamic> _safeObject(String body) {
    return ApiService.safeDecodeObject(body);
  }

  // ✅ ADDED
  static List<Map<String, dynamic>> _safeMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Future<String?> uploadPostImage(File imageFile) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/posts/upload-image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return null;

      final body = _safeObject(response.body);
      return body['imageUrl'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyPosts() async {
    try {
      final res = await ApiClient.get('/posts/me', cacheFirst: false);
      if (res.statusCode != 200) return [];
      final body = _safeObject(res.body);
      if (body['posts'] is List) {
        return _safeMapList(body['posts']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getFeedPosts() async {
    try {
      final res = await ApiClient.get(
        '/posts/feed',
        auth: false,
        cacheFirst: false,
      );
      if (res.statusCode != 200) return [];
      final body = _safeObject(res.body);
      if (body['posts'] is List) {
        return _safeMapList(body['posts']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String content,
    String imageUrl = '',
    List<String> imageUrls = const [],
    String audience = 'public',
    String locationLabel = '',
    String tripLink = '',
    List<String> hashtags = const [],
  }) async {
    try {
      final res = await ApiClient.post('/posts', {
        'content': content,
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'postType': 'post',
        'audience': audience,
        'locationLabel': locationLabel,
        'tripLink': tripLink,
        'hashtags': hashtags,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 201,
        'message': body['message'] ?? 'Unable to create post',
        'post': body['post'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to create post right now.'};
    }
  }

  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    String content = '',
    String locationLabel = '',
    List<String> hashtags = const [],
    List<String> imageUrls = const [],
  }) async {
    try {
      final res = await ApiClient.put('/posts/$postId', {
        'content': content,
        'locationLabel': locationLabel,
        'hashtags': hashtags,
        'imageUrls': imageUrls,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update post',
        'post': body['post'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update post right now.'};
    }
  }

  static Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final res = await ApiClient.delete('/posts/$postId');
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to delete post',
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to delete post right now.'};
    }
  }

  static Future<List<Map<String, dynamic>>> getPostComments(
    String postId,
  ) async {
    try {
      final res = await ApiClient.get('/posts/$postId/comments');
      if (res.statusCode != 200) return [];
      final body = _safeObject(res.body);
      if (body['comments'] is List) {
        return _safeMapList(body['comments']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addPostComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final res = await ApiClient.post('/posts/$postId/comments', {
        'content': content,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parentCommentId': parentCommentId,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 201,
        'message': body['message'] ?? 'Unable to add comment',
        'comments': body['comments'] ?? const <dynamic>[],
        'commentsCount': body['commentsCount'] ?? 0,
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to add comment right now.'};
    }
  }
}
