import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'api_client.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';
import 'api_service.dart';

class MessageService {
  static dynamic _decodeFlexible(String body) {
    try {
      var decoded = jsonDecode(body);
      for (var i = 0; i < 2; i++) {
        if (decoded is String && decoded.trim().startsWith('{')) {
          decoded = jsonDecode(decoded);
          continue;
        }
        if (decoded is String && decoded.trim().startsWith('[')) {
          decoded = jsonDecode(decoded);
          continue;
        }
        break;
      }
      return decoded;
    } catch (_) {
      return body;
    }
  }

  static Map<String, dynamic> _safeDecodeObject(String body) {
    return ApiService.safeDecodeObject(body);
  }

  static List<Map<String, dynamic>> _extractMapList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      final candidates = [
        payload['data'],
        payload['conversations'],
        payload['messages'],
        payload['items'],
        payload['results'],
      ];
      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate.whereType<Map<String, dynamic>>().toList();
        }
        if (candidate is String) {
          final decoded = _decodeFlexible(candidate);
          if (decoded is List) {
            return decoded.whereType<Map<String, dynamic>>().toList();
          }
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  /// Get all conversations for the logged-in user.
  static Future<List<ConversationModel>> getConversations() async {
    try {
      final res = await ApiClient.get('/messages/conversations');
      if (res.statusCode == 200) {
        final decoded = _decodeFlexible(res.body);
        final list = _extractMapList(decoded);
        if (list.isNotEmpty) {
          return list.map(ConversationModel.fromJson).toList();
        }
        return const [];
      }

      final decoded = _safeDecodeObject(res.body);
      final message =
          (decoded['message'] as String?) ??
          'Unable to load conversations (HTTP ${res.statusCode})';
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> archiveConversation(
    String partnerId,
  ) async {
    try {
      final res = await ApiClient.post(
        '/messages/conversations/$partnerId/archive',
        const {},
      );
      final body = _safeDecodeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Conversation archived',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to archive conversation right now.',
      };
    }
  }

  static Future<Map<String, dynamic>> unarchiveConversation(
    String partnerId,
  ) async {
    try {
      final res = await ApiClient.delete(
        '/messages/conversations/$partnerId/archive',
      );
      final body = _safeDecodeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Conversation restored',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to restore conversation right now.',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteConversation(
    String partnerId,
  ) async {
    try {
      final res = await ApiClient.delete('/messages/conversations/$partnerId');
      final body = _safeDecodeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Conversation deleted',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to delete conversation right now.',
      };
    }
  }

  /// Get total unread message count.
  static Future<int> getUnreadCount() async {
    try {
      final res = await ApiClient.get('/messages/unread-count');
      if (res.statusCode == 200) {
        final body = _safeDecodeObject(res.body);
        return (body['count'] as num? ?? 0).toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get messages exchanged with a specific partner.
  static Future<List<Map<String, dynamic>>> getMessages(
    String partnerId,
  ) async {
    try {
      final res = await ApiClient.get('/messages/with/$partnerId');
      if (res.statusCode == 200) {
        final decoded = _decodeFlexible(res.body);
        final list = _extractMapList(decoded);
        if (list.isNotEmpty) return list;
      }
      return [];
    } catch (_) {
      return [];
    }
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
      final decoded = _decodeFlexible(res.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : _safeDecodeObject(res.body);
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
      final decoded = _decodeFlexible(res.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : _safeDecodeObject(res.body);

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
      final decoded = _decodeFlexible(res.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : _safeDecodeObject(res.body);

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
      final decoded = _decodeFlexible(res.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : _safeDecodeObject(res.body);

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
      final decoded = _decodeFlexible(res.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : _safeDecodeObject(res.body);
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
