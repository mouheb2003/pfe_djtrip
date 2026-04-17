import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';
import 'api_service.dart';

class BookingService {
  // Helper methods for JSON parsing
  static Map<String, dynamic> _safeObject(String body) {
    return ApiService.safeDecodeObject(body);
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getMyBookings() async {
    try {
      final res = await ApiClient.get('/inscriptions/me', cacheFirst: false);
      if (res.statusCode != 200) return [];
      
      final body = _safeObject(res.body);
      final raw = body['inscriptions'] ?? body['bookings'] ?? [];
      return _safeMapList(raw);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createBooking({
    required String activityId,
    required int nombreParticipants,
    Map<String, dynamic>? paymentData,
  }) async {
    try {
      final data = {
        'activityId': activityId,
        'nombreParticipants': nombreParticipants,
        if (paymentData != null) ...paymentData,
      };

      final res = await ApiClient.post('/inscriptions', data);
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(res.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 201,
        'message': body['message'] ?? 'Unable to create booking',
        'booking': body['booking'],
        'paymentUrl': body['paymentUrl'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to create booking right now.'};
    }
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await ApiClient.post('/inscriptions/$bookingId/cancel', {});
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Unable to cancel booking',
        'booking': body['booking'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to cancel booking right now.'};
    }
  }

  static Future<Map<String, dynamic>> submitActivityReview({
    required String bookingId,
    required String activityId,
    required double rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final response = await ApiClient.post('/avis/activite/$activityId', {
        'note': rating,
        'commentaire': comment,
        'tags': tags,
      });
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      // Handle duplicate review error
      if (response.statusCode == 400) {
        return {
          'success': false,
          'message': body['message'] ?? 'You have already reviewed this activity',
          'isDuplicate': true,
        };
      }

      // Mark booking as reviewed after successful submission
      if (response.statusCode == 201) {
        await markBookingAsReviewed(bookingId);
      }

      return {
        'success': response.statusCode == 201,
        'message': body['message'] ?? 'Unable to submit review',
        'review': body['review'] ?? body['avis'],
        'isDuplicate': false,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to submit review right now.',
        'isDuplicate': false,
      };
    }
  }

  static Future<bool> markBookingAsReviewed(String bookingId) async {
    try {
      final response = await ApiClient.patch('/inscriptions/$bookingId/reviewed', {});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> submitOrganizerReview({
    required String bookingId,
    required String organizerId,
    required double rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final response = await ApiClient.post('/avis/organisateur/$organizerId', {
        'note': rating,
        'commentaire': comment,
        'tags': tags,
      });
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 201,
        'message': body['message'] ?? 'Unable to submit review',
        'review': body['review'] ?? body['avis'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to submit review right now.'};
    }
  }

  static Future<Map<String, dynamic>> dismissReviewReminder(
    String bookingId, {
    DateTime? reminderAt,
  }) async {
    try {
      final response = await ApiClient.post('/inscriptions/$bookingId/dismiss-review-reminder', {
        'reminderAt': reminderAt?.toIso8601String(),
      });
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Unable to dismiss reminder',
        'reminder': body['reminder'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to dismiss reminder right now.'};
    }
  }

  static Future<Map<String, dynamic>?> getReviewReminderData(String bookingId) async {
    try {
      final response = await ApiClient.get('/inscriptions/$bookingId/review-reminder');
      
      if (response.statusCode == 200) {
        final body = _safeObject(response.body);
        return body['reminder'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> checkInBooking(String bookingId) async {
    try {
      final response = await ApiClient.post('/inscriptions/$bookingId/checkin', {});
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Unable to check in',
        'booking': body['booking'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to check in right now.'};
    }
  }

  static Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    try {
      final response = await ApiClient.patch('/inscriptions/$bookingId', {
        'statut': status,
      });
      
      Map<String, dynamic> body = {};
      try {
        body = _safeObject(response.body);
      } catch (_) {
        body = {};
      }

      return {
        'success': response.statusCode == 200,
        'message': body['message'] ?? 'Unable to update booking',
        'booking': body['booking'],
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to update booking right now.'};
    }
  }
}
