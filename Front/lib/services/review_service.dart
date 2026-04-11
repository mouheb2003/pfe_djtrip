import 'dart:convert';
import 'api_client.dart';

class ReviewService {
  /// Public: get organizer ratings/reviews.
  static Future<List<Map<String, dynamic>>> getOrganizerReviews(
    String organizerId,
  ) async {
    try {
      final res = await ApiClient.get(
        '/avis/organisateur/$organizerId',
        auth: false,
      );
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map<String, dynamic> && data['avis'] is List) {
        return List<Map<String, dynamic>>.from(data['avis'] as List);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
  /// Submit a review for an activity.
  static Future<bool> submitActivityReview({
    required String activiteId,
    required int note,
    String? commentaire,
  }) async {
    try {
      final res = await ApiClient.post(
        '/avis/activite/$activiteId',
        {'note': note, 'commentaire': commentaire},
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
