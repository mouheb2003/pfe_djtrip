import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking_review_model.dart';

/// Service API pour les reviews
/// Gère la communication avec le backend REST
class ReviewApiService {
  final String baseUrl;
  final http.Client _client;

  ReviewApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Récupère tous les bookings de l'utilisateur
  Future<List<BookingReviewModel>> getUserBookings({
    required String token,
    String? status,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/inscriptions/touriste/my-bookings');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['data'] != null) {
          final bookingsData = data['data'] as Map<String, dynamic>;
          final allBookings = <BookingReviewModel>[];
          
          // Fusionner pending, confirmed et cancelled
          for (final statusKey in ['pending', 'confirmed', 'cancelled']) {
            final statusBookings = bookingsData[statusKey] as List<dynamic>?;
            if (statusBookings != null) {
              for (final bookingJson in statusBookings) {
                try {
                  allBookings.add(BookingReviewModel.fromJson(
                    bookingJson as Map<String, dynamic>,
                  ));
                } catch (e) {
                  print('Error parsing booking: $e');
                }
              }
            }
          }
          
          return allBookings;
        }
      }

      throw Exception('Failed to fetch bookings: ${response.statusCode}');
    } catch (e) {
      throw Exception('API error: $e');
    }
  }

  /// Soumet un review pour un booking
  Future<Map<String, dynamic>> submitReview({
    required String token,
    required String bookingId,
    required String activityId,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/avis/activite/$activityId');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'note': rating,
        'commentaire': comment,
        'tags': tags,
      });

      final response = await _client.post(uri, headers: headers, body: body);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'review': data['review'],
          'message': data['message'],
        };
      }

      throw Exception('Failed to submit review: ${response.statusCode}');
    } catch (e) {
      throw Exception('API error: $e');
    }
  }

  /// Marque un booking comme reviewed
  Future<bool> markAsReviewed({
    required String token,
    required String bookingId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/inscriptions/$bookingId/mark-reviewed');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.put(uri, headers: headers);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('API error: $e');
    }
  }

  /// Récupère les données de rappel de review pour un booking
  Future<Map<String, dynamic>?> getReviewReminderData({
    required String token,
    required String bookingId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/inscriptions/$bookingId/review-reminder');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      print('Error fetching review reminder data: $e');
      return null;
    }
  }

  /// Dismiss un rappel de review
  Future<bool> dismissReviewReminder({
    required String token,
    required String bookingId,
    DateTime? reminderAt,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/inscriptions/$bookingId/dismiss-review-reminder');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = reminderAt != null
          ? jsonEncode({'reminderAt': reminderAt.toIso8601String()})
          : jsonEncode({});

      final response = await _client.post(uri, headers: headers, body: body);

      return response.statusCode == 200;
    } catch (e) {
      print('Error dismissing review reminder: $e');
      return false;
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}
