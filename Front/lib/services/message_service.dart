import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'api_client.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';

class MessageService {
  static Map<String, dynamic> _safeDecodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Get all conversations for the logged-in user.
  static Future<List<ConversationModel>> getConversations() async {
    final res = await ApiClient.get('/messages/conversations');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? (decoded['conversations'] ?? decoded['data'] ?? const [])
          : const [];

      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(ConversationModel.fromJson)
            .toList();
      }
      return const [];
    }
    final decoded = (() {
      try {
        final body = jsonDecode(res.body);
        return body is Map<String, dynamic> ? body : null;
      } catch (_) {
        return null;
      }
    })();

    final message =
        (decoded?['message'] as String?) ??
        'Unable to load conversations (HTTP ${res.statusCode})';
    throw Exception(message);
  }

  /// Get total unread message count.
  static Future<int> getUnreadCount() async {
    final res = await ApiClient.get('/messages/unread-count');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['count'] as num? ?? 0).toInt();
    }
    return 0;
  }

  /// Get messages exchanged with a specific partner.
  static Future<List<Map<String, dynamic>>> getMessages(
    String partnerId,
  ) async {
    final res = await ApiClient.get('/messages/with/$partnerId');
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Send message to partner through REST API.
  static Future<Map<String, dynamic>> sendMessage({
    required String partnerId,
    required String content,
  }) async {
    try {
      final res = await ApiClient.post('/messages/with/$partnerId', {
        'content': content,
      });
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 || res.statusCode == 200) {
        final msg = body['message'] as Map<String, dynamic>?;
        if (msg != null) return {'success': true, 'message': msg};
      }
      return {
        'success': false,
        'messageText': body['message'] ?? 'Error sending message',
      };
    } catch (_) {
      return {
        'success': false,
        'messageText': 'Network error while sending message',
      };
    }
  }

  /// Send an image message file to partner through multipart endpoint.
  static Future<Map<String, dynamic>> sendImageMessage({
    required String partnerId,
    required File imageFile,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'messageText': 'Session expired.'};
      }

      final uri = Uri.parse(
        '${ApiClient.baseUrl}/messages/with/$partnerId/image',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final res = await http.Response.fromStream(streamed);
      final body = _safeDecodeObject(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        final msg = body['message'] as Map<String, dynamic>?;
        if (msg != null) return {'success': true, 'message': msg};
      }
      return {
        'success': false,
        'messageText':
            body['message'] ??
            'Error sending image message (code ${res.statusCode})',
      };
    } on TimeoutException {
      return {'success': false, 'messageText': 'Image upload timed out.'};
    } catch (e) {
      return {
        'success': false,
        'messageText': 'Network error while sending image: $e',
      };
    }
  }

  /// Send an audio message file to partner through multipart endpoint.
  static Future<Map<String, dynamic>> sendAudioMessage({
    required String partnerId,
    required File audioFile,
    int durationSec = 0,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'messageText': 'Session expired.'};
      }

      final uri = Uri.parse(
        '${ApiClient.baseUrl}/messages/with/$partnerId/audio',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['duration_sec'] = durationSec.toString()
        ..files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final res = await http.Response.fromStream(streamed);
      final body = _safeDecodeObject(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        final msg = body['message'] as Map<String, dynamic>?;
        if (msg != null) return {'success': true, 'message': msg};
      }
      return {
        'success': false,
        'messageText':
            body['message'] ??
            'Error sending voice message (code ${res.statusCode})',
      };
    } on TimeoutException {
      return {
        'success': false,
        'messageText': 'Voice message upload timed out.',
      };
    } catch (e) {
      return {
        'success': false,
        'messageText': 'Network error while sending voice message: $e',
      };
    }
  }

  /// Send a video message file to partner through multipart endpoint.
  static Future<Map<String, dynamic>> sendVideoMessage({
    required String partnerId,
    required File videoFile,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'messageText': 'Session expired.'};
      }

      final uri = Uri.parse(
        '${ApiClient.baseUrl}/messages/with/$partnerId/video',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final res = await http.Response.fromStream(streamed);
      final body = _safeDecodeObject(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        final msg = body['message'] as Map<String, dynamic>?;
        if (msg != null) return {'success': true, 'message': msg};
      }
      return {
        'success': false,
        'messageText':
            body['message'] ??
            'Error sending video message (code ${res.statusCode})',
      };
    } on TimeoutException {
      return {
        'success': false,
        'messageText': 'Video message upload timed out.',
      };
    } catch (e) {
      return {
        'success': false,
        'messageText': 'Network error while sending video message: $e',
      };
    }
  }

  /// Edit one of my messages.
  static Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      final res = await ApiClient.put('/messages/$messageId', {
        'content': content,
      });
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final msg = body['message'] as Map<String, dynamic>?;
        if (msg != null) return {'success': true, 'message': msg};
      }
      return {
        'success': false,
        'messageText': body['message'] ?? 'Error editing message',
      };
    } catch (_) {
      return {'success': false, 'messageText': 'Network error during edit'};
    }
  }

  /// Delete one of my messages.
  static Future<bool> deleteMessage(String messageId) async {
    try {
      final res = await ApiClient.delete('/messages/$messageId');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
