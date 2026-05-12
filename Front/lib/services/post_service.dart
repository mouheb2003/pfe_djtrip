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
    List<String> mentions = const [],
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
        'mentions': mentions,
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
      // Use paginated API with default parameters (page 1, limit 10)
      // Disable frontend caching to prevent stale data
      final res = await ApiClient.get(
        '/comments/$postId/comments',
        query: {'page': '1', 'limit': '10'},
        cacheFirst: false,
      );
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
      final res = await ApiClient.post('/comments/$postId/comments', {
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

  static Future<Map<String, dynamic>> togglePostLike(String postId, {String reactionType = 'like'}) async {
    try {
      final res = await ApiClient.post('/posts/$postId/like', {
        'reactionType': reactionType,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update like',
        'liked': body['liked'] == true,
        'likesCount': (body['likesCount'] as num?)?.toInt() ?? 0,
        'totalReactions': (body['totalReactions'] as num?)?.toInt() ?? 0,
        'reactionCounts': body['reaction_counts'] ?? {},
        'userReaction': body['userReaction'],
        'postId': body['postId']?.toString() ?? postId,
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update like right now.'};
    }
  }

  static Future<Map<String, dynamic>> togglePostBookmark(String postId) async {
    try {
      final res = await ApiClient.post('/posts/$postId/bookmark', {});

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update bookmark',
        'bookmarked': body['bookmarked'] == true,
        'bookmarksCount': (body['bookmarksCount'] as num?)?.toInt() ?? 0,
        'postId': body['postId']?.toString() ?? postId,
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update bookmark right now.'};
    }
  }

  static Future<List<Map<String, dynamic>>> getBookmarkedPosts() async {
    try {
      final res = await ApiClient.get('/posts/bookmarks', cacheFirst: false);
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

  static Future<Map<String, dynamic>> reactToComment(String commentId, String reactionType) async {
    try {
      final res = await ApiClient.post('/comments/$commentId/react', {
        'reactionType': reactionType,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update reaction',
        'user_reaction': body['user_reaction'],
        'total_reactions': (body['total_reactions'] as num?)?.toInt() ?? 0,
        'reaction_counts': body['reaction_counts'] ?? {},
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update reaction right now.'};
    }
  }

  static Future<Map<String, dynamic>> updateComment(String commentId, String content) async {
    try {
      final res = await ApiClient.patch('/comments/$commentId', {
        'content': content,
      });

      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update comment',
        'comment': body['comment'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update comment right now.'};
    }
  }

  // ✅ NEW: Delete comment (owner or post owner or admin)
  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      final res = await ApiClient.delete('/comments/$commentId');
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to delete comment',
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to delete comment right now.'};
    }
  }

  // ✅ NEW: Get comment replies with pagination (Facebook/Instagram style)
  static Future<Map<String, dynamic>> getCommentReplies({
    required String commentId,
    int page = 1,
    int limit = 5, // Default to 5 replies per page
  }) async {
    try {
      // Disable frontend caching to prevent stale data
      final res = await ApiClient.get(
        '/comments/$commentId/replies',
        query: {'page': page.toString(), 'limit': limit.toString()},
        cacheFirst: false,
      );
      if (res.statusCode != 200) {
        return {
          'success': false,
          'replies': <dynamic>[],
          'pagination': null,
        };
      }
      final body = _safeObject(res.body);
      return {
        'success': true,
        'replies': body['replies'] ?? <dynamic>[],
        'pagination': body['pagination'],
      };
    } catch (_) {
      return {
        'success': false,
        'replies': <dynamic>[],
        'pagination': null,
      };
    }
  }

  // ✅ NEW: Get comments with pagination
  static Future<Map<String, dynamic>> getPostCommentsPaginated({
    required String postId,
    int page = 1,
    int limit = 10, // Default to 10 for Facebook/Instagram style
  }) async {
    try {
      final res = await ApiClient.get(
        '/comments/$postId/comments',
        query: {'page': page.toString(), 'limit': limit.toString()},
      );
      if (res.statusCode != 200) {
        return {
          'success': false,
          'comments': <dynamic>[],
          'pagination': null,
        };
      }
      final body = _safeObject(res.body);
      return {
        'success': true,
        'comments': body['comments'] ?? <dynamic>[],
        'pagination': body['pagination'],
      };
    } catch (_) {
      return {
        'success': false,
        'comments': <dynamic>[],
        'pagination': null,
      };
    }
  }

  }
