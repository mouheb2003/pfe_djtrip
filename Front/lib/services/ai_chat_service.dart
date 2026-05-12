import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ai_chat_message.dart';

class AiChatService {
  static const String baseUrl = 'http://localhost:3001/api';
  
  // Get chat endpoint URL
  static String get _chatUrl => '$baseUrl/chat';
  
  // Get search endpoint URL
  static String get _searchUrl => '$baseUrl/search';
  
  // Get conversation endpoint URL
  static String _conversationUrl(String conversationId) => '$baseUrl/conversations/$conversationId';
  
  // Get conversations endpoint URL
  static String get _conversationsUrl => '$baseUrl/conversations';
  
  // Send message to AI chatbot
  static Future<AiChatResponse> sendMessage({
    required String query,
    String? conversationId,
    Map<String, dynamic>? options,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          if (conversationId != null) 'conversationId': conversationId,
          if (options != null) 'options': options,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiChatResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to send message');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }
  
  // Search documentation without AI response
  static Future<AiSearchResponse> search({
    required String query,
    Map<String, dynamic>? options,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_searchUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          if (options != null) 'options': options,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiSearchResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Search failed');
      }
    } catch (e) {
      throw Exception('Error searching: $e');
    }
  }
  
  // Get conversation history
  static Future<AiConversation> getConversation(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse(_conversationUrl(conversationId)),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiConversation.fromJson(data['data']);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get conversation');
      }
    } catch (e) {
      throw Exception('Error getting conversation: $e');
    }
  }
  
  // Create new conversation
  static Future<AiConversation> createConversation({String? sessionId}) async {
    try {
      final response = await http.post(
        Uri.parse(_conversationsUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (sessionId != null) 'sessionId': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AiConversation.fromJson(data['data']);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create conversation');
      }
    } catch (e) {
      throw Exception('Error creating conversation: $e');
    }
  }
  
  // Delete conversation
  static Future<void> deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse(_conversationUrl(conversationId)),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to delete conversation');
      }
    } catch (e) {
      throw Exception('Error deleting conversation: $e');
    }
  }
}
