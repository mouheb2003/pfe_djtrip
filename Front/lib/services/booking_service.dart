import 'api_client.dart';
import 'api_service.dart';


class BookingService {
  static Map<String, dynamic> _safeObject(String body) =>
      ApiService.safeDecodeObject(body);

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
      final body = _safeObject(res.body);

      if (res.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Booking request sent successfully.',
          'booking': body['booking'],
          'paymentUrl': body['paymentUrl'],
        };
      }

      // Use conflict details if available (overlap scenario)
      final conflict = body['conflict'];
      String errorMsg = ApiService.extractErrorMessage(res,
          fallback: 'Unable to complete your booking.');
      if (conflict != null && conflict['activityTitle'] != null) {
        errorMsg =
            'You already have a booking for "${conflict['activityTitle']}" at this time.';
      }

      return {
        'success': false,
        'message': errorMsg,
        'booking': null,
        'paymentUrl': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response =
          await ApiClient.post('/inscriptions/$bookingId/cancel', {});
      final body = _safeObject(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Booking cancelled successfully.',
          'booking': body['booking'],
        };
      }

      return {
        'success': false,
        'message': ApiService.extractErrorMessage(response,
            fallback: 'Unable to cancel your booking.'),
        'booking': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
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
      final body = _safeObject(response.body);

      if (response.statusCode == 201) {
        await markBookingAsReviewed(bookingId);
        return {
          'success': true,
          'message': body['message'] ?? 'Review submitted successfully.',
          'review': body['review'] ?? body['avis'],
          'isDuplicate': false,
        };
      }

      if (response.statusCode == 400 &&
          (body['message']?.toString().toLowerCase().contains('already') ??
              false)) {
        return {
          'success': false,
          'message': body['message'] ?? 'You have already reviewed this activity.',
          'isDuplicate': true,
        };
      }

      return {
        'success': false,
        'message': ApiService.extractErrorMessage(response,
            fallback: 'Unable to submit your review.'),
        'isDuplicate': false,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
        'isDuplicate': false,
      };
    }
  }

  static Future<bool> markBookingAsReviewed(String bookingId) async {
    try {
      final response =
          await ApiClient.patch('/inscriptions/$bookingId/reviewed', {});
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
      final response =
          await ApiClient.post('/avis/organisateur/$organizerId', {
        'note': rating,
        'commentaire': comment,
        'tags': tags,
      });
      final body = _safeObject(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Review submitted successfully.',
          'review': body['review'] ?? body['avis'],
        };
      }

      return {
        'success': false,
        'message': ApiService.extractErrorMessage(response,
            fallback: 'Unable to submit your review.'),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> dismissReviewReminder(
    String bookingId, {
    DateTime? reminderAt,
  }) async {
    try {
      final response = await ApiClient.post(
          '/inscriptions/$bookingId/dismiss-review-reminder', {
        'reminderAt': reminderAt?.toIso8601String(),
      });
      final body = _safeObject(response.body);

      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200
            ? (body['message'] ?? 'Reminder dismissed.')
            : ApiService.extractErrorMessage(response,
                fallback: 'Unable to dismiss reminder.'),
        'reminder': body['reminder'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>?> getReviewReminderData(
      String bookingId) async {
    try {
      final response =
          await ApiClient.get('/inscriptions/$bookingId/review-reminder');
      if (response.statusCode == 200) {
        final body = _safeObject(response.body);
        return body['reminder'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> checkInBooking(
      String bookingId) async {
    try {
      final response =
          await ApiClient.post('/inscriptions/$bookingId/checkin', {});
      final body = _safeObject(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Check-in successful.',
          'booking': body['booking'],
        };
      }

      return {
        'success': false,
        'message': ApiService.extractErrorMessage(response,
            fallback: 'Unable to complete check-in.'),
        'booking': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
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
      final body = _safeObject(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Booking updated.',
          'booking': body['booking'],
        };
      }

      return {
        'success': false,
        'message': ApiService.extractErrorMessage(response,
            fallback: 'Unable to update booking.'),
        'booking': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server. Please check your connection.',
      };
    }
  }

  static Future<int> getPendingBookingsCount() async {
    try {
      final res = await ApiClient.get('/inscriptions/organisateur/en-attente', cacheFirst: false);
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        return (body['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error fetching pending bookings count: $e');
      return 0;
    }
  }
}

