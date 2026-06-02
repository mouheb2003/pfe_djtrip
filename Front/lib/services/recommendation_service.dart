import 'dart:convert';
import 'api_client.dart';

class RecommendationService {
  static Future<List<Map<String, dynamic>>> getRecommendations({
    bool refresh = false,
  }) async {
    try {
      final res = await ApiClient.get(
        '/recommendations',
        auth: true,
        cacheFirst: !refresh,
      );

      if (res.statusCode == 200) {
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          return [];
        }

        if (body is Map<String, dynamic> && body['recommendations'] is List) {
          return List<Map<String, dynamic>>.from(body['recommendations']);
        }
      }
      return [];
    } catch (e) {
      print('❌ getRecommendations failed: $e');
      return [];
    }
  }
}
