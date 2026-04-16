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

  /// Public: get activity reviews.
  static Future<List<Map<String, dynamic>>> getActivityReviews(
    String activityId,
  ) async {
    try {
      print('🔍 Fetching reviews for activity: $activityId');
      final res = await ApiClient.get(
        '/avis/activite/$activityId',
        auth: false,
        cacheFirst: false,
      );
      print('🔍 Response status: ${res.statusCode}');
      
      if (res.statusCode != 200) {
        print('❌ Non-200 status code: ${res.statusCode}');
        return [];
      }

      final data = jsonDecode(res.body);
      print('🔍 Decoded data type: ${data.runtimeType}');
      
      if (data is List) {
        print('🔍 Data is a List with ${data.length} items');
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          print('🔍 Data has data key with ${data['data'].length} items');
          return List<Map<String, dynamic>>.from(data['data'] as List);
        }
        if (data['avis'] is List) {
          print('🔍 Data has avis key with ${data['avis'].length} items');
          return List<Map<String, dynamic>>.from(data['avis'] as List);
        }
      }
      print('❌ Unexpected data structure');
      return [];
    } catch (e) {
      print('❌ Error fetching activity reviews: $e');
      return [];
    }
  }

  /// Check if the authenticated user already reviewed an activity.
  static Future<Map<String, dynamic>> getMyActivityReview(String activiteId) async {
    try {
      final res = await ApiClient.get(
        '/avis/my-review/activite/$activiteId',
        auth: true,
        cacheFirst: false,
      );
      if (res.statusCode != 200) {
        return {'hasReviewed': false, 'avis': null};
      }
      final data = jsonDecode(res.body);
      return {
        'hasReviewed': data['hasReviewed'] ?? false,
        'avis': data['avis'],
      };
    } catch (_) {
      return {'hasReviewed': false, 'avis': null};
    }
  }

  /// Submit a review for an activity.
  static Future<Map<String, dynamic>> submitActivityReview({
    required String activiteId,
    required int note,
    String? commentaire,
    List<String>? tags,
  }) async {
    try {
      final body = {
        'note': note,
        'commentaire': commentaire,
        if (tags != null) 'tags': tags,
      };
      final res = await ApiClient.post(
        '/avis/activite/$activiteId',
        body,
      );
      final data = jsonDecode(res.body);
      
      // Handle duplicate review error
      if (res.statusCode == 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'You have already reviewed this activity',
          'isDuplicate': true,
        };
      }
      
      return {
        'success': res.statusCode == 201,
        'message': data['message'] ?? 'Unable to submit review',
        'review': data['review'] ?? data['avis'],
        'isDuplicate': false,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to submit review right now.',
        'isDuplicate': false,
      };
    }
  }

  /// Update a review/rating (activity or organizer).
  static Future<Map<String, dynamic>> updateReview({
    required String avisId,
    required double note,
    String? commentaire,
    List<String>? tags,
  }) async {
    try {
      final body = {
        'note': note,
        'commentaire': commentaire,
        if (tags != null) 'tags': tags,
      };
      final res = await ApiClient.put('/avis/$avisId', body);
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Unable to update review',
        'review': data['review'] ?? data['avis'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Unable to update review right now.'};
    }
  }

  /// Delete a review/rating.
  static Future<bool> deleteReview(String avisId) async {
    try {
      final res = await ApiClient.delete('/avis/$avisId');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
