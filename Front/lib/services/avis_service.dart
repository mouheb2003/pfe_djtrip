import 'dart:convert';
import '../config/api_config.dart';
import '../models/avis.dart';
import 'http_client.dart';

class AvisService {
  static const String _base = '${ApiConfig.baseUrl}/avis';

  // ─── Submit review for an activity ──────────────────────────────────────────
  static Future<void> submitActivityReview({
    required String activiteId,
    required double note,
    String? commentaire,
  }) async {
    final headers = await HttpClient.getAuthHeaders();
    final body = jsonEncode({
      'note': note.toInt(),
      if (commentaire != null && commentaire.trim().isNotEmpty)
        'commentaire': commentaire.trim(),
    });

    final response = await HttpClient.post(
      '$_base/activite/$activiteId',
      headers: headers,
      body: body,
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to submit review');
    }
  }

  // ─── Submit rating for an organizer ──────────────────────────────────────────
  static Future<void> submitOrganisateurRating({
    required String organisateurId,
    required double note,
    String? commentaire,
  }) async {
    final headers = await HttpClient.getAuthHeaders();
    final body = jsonEncode({
      'note': note.toInt(),
      if (commentaire != null && commentaire.trim().isNotEmpty)
        'commentaire': commentaire.trim(),
    });

    final response = await HttpClient.post(
      '$_base/organisateur/$organisateurId',
      headers: headers,
      body: body,
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to submit rating');
    }
  }

  // ─── Get all reviews for an activity (public) ────────────────────────────────
  static Future<List<Avis>> getActivityReviews(String activiteId) async {
    final response = await HttpClient.get('$_base/activite/$activiteId');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Avis.fromJson(j)).toList();
    }
    return [];
  }

  // ─── Get all ratings for an organizer (public) ───────────────────────────────
  static Future<List<Avis>> getOrganisateurRatings(
    String organisateurId,
  ) async {
    final response = await HttpClient.get(
      '$_base/organisateur/$organisateurId',
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Avis.fromJson(j)).toList();
    }
    return [];
  }

  // ─── Check if tourist already reviewed a specific activity ──────────────────
  static Future<Map<String, dynamic>> checkMyActivityReview(
    String activiteId,
  ) async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.get(
      '$_base/my-review/activite/$activiteId',
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'hasReviewed': false, 'avis': null};
  }

  // ─── Check if tourist already rated a specific organizer ────────────────────
  static Future<Map<String, dynamic>> checkMyOrganisateurRating(
    String organisateurId,
  ) async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.get(
      '$_base/my-rating/organisateur/$organisateurId',
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'hasRated': false, 'avis': null};
  }

  // ─── Delete own review/rating ────────────────────────────────────────────────
  static Future<void> deleteAvis(String avisId) async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.delete(
      '$_base/$avisId',
      headers: headers,
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete review');
    }
  }
}
