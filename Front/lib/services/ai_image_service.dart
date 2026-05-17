import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class AIImageService {
  AIImageService._();

  static final AIImageService instance = AIImageService._();

  /// Generate multiple AI images for an activity based on title and description
  /// Now includes category parameter and returns comprehensive metadata
  Future<Map<String, dynamic>> generateActivityImages({
    required String title,
    required String description,
    String? category,
    int? count,
  }) async {
    try {
      final response = await ApiService.instance.post(
        '/activites/generate-image',
        {
          'title': title,
          'description': description,
          if (category != null) 'category': category,
          if (count != null) 'count': count,
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] ?? {};
        final images = data['images'] as List<dynamic>? ?? [];
        
        // Extract new metadata fields
        return {
          'success': true,
          'images': images.cast<String>(),
          'prompt': data['prompt'] as String? ?? '',
          'promptScore': data['promptScore'] as int? ?? 0,
          'method': data['method'] as String? ?? 'unknown',
          'generationMethod': data['generationMethod'] as String? ?? 'unknown',
          'metadata': data['metadata'] as Map<String, dynamic>? ?? {},
          'processingTime': data['processingTime'] as String? ?? '',
        };
      } else {
        return {
          'success': false,
          'message': body['message'] as String? ?? 'Failed to generate images',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Validate if the generated images are high quality (not fallback)
  bool isHighQualityGeneration(Map<String, dynamic> result) {
    final method = result['method'] as String? ?? 'unknown';
    final promptScore = result['promptScore'] as int? ?? 0;
    
    // Consider high quality if:
    // 1. Method is 'ai_generated' AND
    // 2. Prompt score is >= 60
    return method == 'ai_generated' && promptScore >= 60;
  }
  
  /// Get user-friendly message about generation quality
  String getQualityMessage(Map<String, dynamic> result) {
    final method = result['method'] as String? ?? 'unknown';
    final promptScore = result['promptScore'] as int? ?? 0;
    final generationMethod = result['generationMethod'] as String? ?? 'unknown';
    
    if (method == 'ai_generated') {
      if (promptScore >= 80) {
        return 'Excellent quality AI-generated images';
      } else if (promptScore >= 60) {
        return 'Good quality AI-generated images';
      } else {
        return 'AI-generated images (acceptable quality)';
      }
    } else if (method == 'placeholder') {
      return 'Placeholder images (AI generation unavailable)';
    } else if (method == 'fallback') {
      return 'Fallback images (service temporarily unavailable)';
    }
    
    return 'Images generated';
  }
}
