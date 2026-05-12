import 'dart:convert';
import 'api_client.dart';

class AiTextService {
  static const String _baseUrl = 'ai-text';

  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'ar': 'Arabic',
    'ru': 'Russian',
  };

  // Translate text to target language
  static Future<Map<String, dynamic>> translateText(String text, String lang) async {
    try {
      final contextText = _buildTranslationContext(text, lang);
      final response = await ApiClient.post(
        '/ai-text/process',
        {
          'text': contextText,
          'action': 'translate',
          'lang': lang,
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        String result = body['result'] ?? '';
        
        // Extract only the actual translated text - clean all introductions
        result = _extractPureResponse(result);
        
        return {
          'success': true,
          'result': result,
          'originalText': body['originalText'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to translate text',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

  // Rewrite text to be more engaging
  static Future<Map<String, dynamic>> rewriteText(String text, {String? type, String? title, String? description}) async {
    try {
      final contextText = _buildContextText(type, title, description, text);
      final response = await ApiClient.post(
        '/ai-text/process',
        {
          'text': contextText,
          'action': 'rewrite',
          'targetField': description != null ? 'description' : 'text',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        String result = body['result'] ?? '';
        
        // Extract only the actual rewritten text - clean all introductions
        result = _extractPureResponse(result);
        
        return {
          'success': true,
          'result': result,
          'originalText': body['originalText'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to rewrite text',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

  // Improve text (grammar, clarity, tone)
  static Future<Map<String, dynamic>> improveText(String text, {String? type, String? title, String? description}) async {
    try {
      final contextText = _buildContextText(type, title, description, text);
      final response = await ApiClient.post(
        '/ai-text/process',
        {
          'text': contextText,
          'action': 'improve',
          'targetField': description != null ? 'description' : 'text',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        String result = body['result'] ?? '';
        
        // Extract only the actual improved text - clean all introductions
        result = _extractPureResponse(result);
        
        return {
          'success': true,
          'result': result,
          'originalText': body['originalText'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to improve text',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

  // Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await ApiClient.get('/ai-text/health');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          ...body,
        };
      } else {
        return {
          'success': false,
          'error': 'AI service unavailable',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error: ${e.toString()}',
      };
    }
  }

  // Extract pure response without any introductions or explanations
  static String _extractPureResponse(String result) {
    if (result.contains('\n')) {
      final lines = result.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty && 
            !trimmedLine.toLowerCase().contains('translation') &&
            !trimmedLine.toLowerCase().contains('translated') &&
            !trimmedLine.toLowerCase().contains('here is') &&
            !trimmedLine.toLowerCase().contains('voici') &&
            !trimmedLine.toLowerCase().contains('traduction') &&
            !trimmedLine.toLowerCase().contains('original') &&
            !trimmedLine.toLowerCase().contains('suggestion') &&
            !trimmedLine.toLowerCase().contains('option') &&
            !trimmedLine.toLowerCase().contains('here are') &&
            !trimmedLine.toLowerCase().contains('suggestion') &&
            !trimmedLine.toLowerCase().contains('improved') &&
            !trimmedLine.toLowerCase().contains('rewritten') &&
            !trimmedLine.toLowerCase().contains('better') &&
            !trimmedLine.toLowerCase().contains('version') &&
            !trimmedLine.toLowerCase().contains('alternative') &&
            !trimmedLine.toLowerCase().contains('recommend') &&
            !trimmedLine.toLowerCase().contains('i can') &&
            !trimmedLine.toLowerCase().contains('i will') &&
            !trimmedLine.toLowerCase().contains('let me') &&
            !trimmedLine.toLowerCase().contains('here\'s') &&
            !trimmedLine.toLowerCase().contains('the following') &&
            !trimmedLine.toLowerCase().contains('below is') &&
            !trimmedLine.toLowerCase().contains('above is')) {
          return trimmedLine;
        }
      }
    }
    return result.trim();
  }

  // Build context text for AI processing with clear distinction between content types
  static String _buildContextText(String? type, String? title, String? description, String currentText) {
    final buffer = StringBuffer();
    
    // Determine content type and build appropriate context
    if (type == 'message') {
      buffer.writeln('=== MESSAGE CONTEXT ===');
      buffer.writeln('Content Type: Chat Message');
      buffer.writeln('Purpose: Short, direct communication between users');
      buffer.writeln('Style: Conversational, natural, brief');
    } else if (type == 'post') {
      buffer.writeln('=== POST CONTEXT ===');
      buffer.writeln('Content Type: Social Media Post');
      buffer.writeln('Purpose: Share experience, longer than message but still concise');
      buffer.writeln('Style: Engaging, personal, moderately detailed');
      if (title != null) {
        buffer.writeln('Post Title/Location: $title');
      }
      if (description != null && description.isNotEmpty) {
        buffer.writeln('Post Content: $description');
      }
    } else if (type == 'activity') {
      buffer.writeln('=== ACTIVITY CONTEXT ===');
      buffer.writeln('Content Type: Activity Description');
      buffer.writeln('Purpose: Detailed description of an activity/experience');
      buffer.writeln('Style: Professional, detailed, persuasive, longer content');
      if (title != null) {
        buffer.writeln('Activity Title: $title');
      }
      if (description != null && description.isNotEmpty) {
        buffer.writeln('Current Activity Description: $description');
      }
    } else {
      buffer.writeln('=== GENERAL CONTEXT ===');
      buffer.writeln('Content Type: General Text');
      if (type != null) {
        buffer.writeln('Type: $type');
      }
      if (title != null) {
        buffer.writeln('Title: $title');
      }
      if (description != null && description.isNotEmpty) {
        buffer.writeln('Description: $description');
      }
    }
    
    buffer.writeln('\n=== TASK ===');
    if (type == 'message') {
      buffer.writeln('TASK: Rewrite or improve this short message to be clearer, more natural, and effective.');
      buffer.writeln('Keep it brief and conversational - suitable for chat/messaging.');
      buffer.writeln('Focus on clarity, tone, and natural flow.');
      buffer.writeln('Length: 1-3 sentences maximum.');
    } else if (type == 'post') {
      buffer.writeln('TASK: Enhance this post to be more engaging and well-written.');
      buffer.writeln('Make it more interesting but keep it reasonably concise.');
      buffer.writeln('Focus on engagement, readability, and personal expression.');
      buffer.writeln('Length: 3-8 sentences, moderate detail.');
    } else if (type == 'activity') {
      buffer.writeln('TASK: Create a comprehensive, professional activity description.');
      buffer.writeln('Make it detailed, persuasive, and appealing to potential participants.');
      buffer.writeln('Focus on experience, benefits, and unique aspects.');
      buffer.writeln('Length: 150-200 words minimum with vivid details.');
    } else {
      buffer.writeln('TASK: Improve the text based on its context and purpose.');
      buffer.writeln('Make it clearer, more engaging, and appropriate for the content type.');
    }
    
    buffer.writeln('\n=== CURRENT TEXT ===');
    buffer.writeln(currentText);
    
    buffer.writeln('\n=== CRITICAL INSTRUCTIONS ===');
    buffer.writeln('1. RETURN ONLY THE FINAL TEXT - NO INTRODUCTIONS');
    buffer.writeln('2. DO NOT include phrases like "Here is the improved version"');
    buffer.writeln('3. DO NOT include explanations, suggestions, or alternatives');
    buffer.writeln('4. DO NOT include "I suggest", "Here are options", "Let me help"');
    buffer.writeln('5. DO NOT include "Translation:", "Improved:", "Rewritten:"');
    buffer.writeln('6. Provide ONLY the processed text result');
    buffer.writeln('7. No conversational introductions or explanations');
    
    return buffer.toString();
  }

  // Build context text for translation
  static String _buildTranslationContext(String text, String targetLang) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== TRANSLATION TASK ===');
    buffer.writeln('Target Language: ${supportedLanguages[targetLang] ?? targetLang}');
    buffer.writeln('Text to translate: $text');
    
    buffer.writeln('\n=== CRITICAL INSTRUCTIONS ===');
    buffer.writeln('1. TRANSLATE ONLY - no explanations or introductions');
    buffer.writeln('2. Return ONLY the translated text');
    buffer.writeln('3. DO NOT include "Translation:", "Here is the translation", "Voici la traduction"');
    buffer.writeln('4. DO NOT include the original text in your response');
    buffer.writeln('5. DO NOT include explanations, notes, or alternatives');
    buffer.writeln('6. Provide ONLY the final translated result');
    buffer.writeln('7. Example: If translating "bonjour" to English, return ONLY "good morning"');
    
    return buffer.toString();
  }
}
