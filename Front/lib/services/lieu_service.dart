import 'dart:convert';

import '../models/lieu_model.dart';
import 'api_client.dart';

class LieuService {
  static Future<List<LieuModel>> getLieux({
    String? search,
    String? type,
    bool? isFeatured,
    String? city,
    String? country,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }
    if (isFeatured != null) {
      query['is_featured'] = isFeatured.toString();
    }
    if (city != null && city.isNotEmpty) {
      query['city'] = city;
    }
    if (country != null && country.isNotEmpty) {
      query['country'] = country;
    }

    final res = await ApiClient.get(
      '/lieux',
      auth: false,
      query: query.isEmpty ? null : query,
      cacheFirst: false, // Forcer le rechargement depuis l'API
    );
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    final mapped = list
        .whereType<Map<String, dynamic>>()
        .map(LieuModel.fromJson)
        .toList(growable: false);

    return mapped
        .where((l) => l.id.trim().isNotEmpty && l.titre.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getLieuxAsMap({
    String? search,
    String? type,
    bool? isFeatured,
    String? city,
    String? country,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }
    if (isFeatured != null) {
      query['is_featured'] = isFeatured.toString();
    }
    if (city != null && city.isNotEmpty) {
      query['city'] = city;
    }
    if (country != null && country.isNotEmpty) {
      query['country'] = country;
    }

    final res = await ApiClient.get(
      '/lieux',
      auth: false,
      query: query.isEmpty ? null : query,
      cacheFirst: false, // Forcer le rechargement depuis l'API
    );
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<List<LieuModel>> getFeaturedLieux() async {
    final res = await ApiClient.get('/lieux/featured', auth: false);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    final mapped = list
        .whereType<Map<String, dynamic>>()
        .map(LieuModel.fromJson)
        .toList(growable: false);

    return mapped
        .where((l) => l.id.trim().isNotEmpty && l.titre.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getFeaturedLieuxAsMap() async {
    final res = await ApiClient.get('/lieux/featured', auth: false);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> getLieuxByType(String type) async {
    final res = await ApiClient.get('/lieux/type/$type', auth: false);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>?> getLieuById(String id) async {
    final res = await ApiClient.get('/lieux/$id', auth: true);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['lieu'] as Map<String, dynamic>?;
  }

  // Legacy method for backward compatibility
  static Future<List<LieuModel>> getLieuxLegacy({
    String? search,
    String? categorie,
    bool? topDestination,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (categorie != null && categorie.isNotEmpty) {
      query['categorie'] = categorie;
    }
    if (topDestination != null) {
      query['topDestination'] = topDestination.toString();
    }

    final res = await ApiClient.get(
      '/lieux',
      auth: false,
      query: query.isEmpty ? null : query,
      cacheFirst: false, // Forcer le rechargement depuis l'API
    );
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['lieux'] as List? ?? const [];
    final mapped = list
        .whereType<Map<String, dynamic>>()
        .map(LieuModel.fromJson)
        .toList(growable: false);

    // Keep only valid places coming from DB.
    // If DB has no valid records, Explore must be empty.
    return mapped
        .where((l) => l.id.trim().isNotEmpty && l.titre.trim().isNotEmpty)
        .toList(growable: false);
  }

  // Toggle bookmark on a place
  static Future<Map<String, dynamic>> toggleLieuBookmark(String lieuId) async {
    try {
      final res = await ApiClient.post('/lieux/$lieuId/bookmark', {});

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update bookmark',
        'bookmarked': body['bookmarked'] == true,
        'bookmarksCount': (body['bookmarksCount'] as num?)?.toInt() ?? 0,
        'lieuId': body['lieuId']?.toString() ?? lieuId,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to update bookmark right now.',
      };
    }
  }

  // Add a review to a place
  static Future<Map<String, dynamic>> addReview({
    required String lieuId,
    required int rating,
    required String comment,
  }) async {
    try {
      final res = await ApiClient.post('/lieux/$lieuId/reviews', {
        'rating': rating,
        'comment': comment,
      });

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'success': res.statusCode == 201,
        'message': body['message'] ?? 'Unable to add review',
        'lieu': body['lieu'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error connecting to server'};
    }
  }

  // Get bookmarked places for current user
  static Future<List<Map<String, dynamic>>> getBookmarkedLieux() async {
    try {
      final res = await ApiClient.get('/lieux/bookmarks', cacheFirst: false);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['lieux'] is List) {
        return (body['lieux'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Update a review
  static Future<Map<String, dynamic>> updateReview({
    required String lieuId,
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    try {
      final res = await ApiClient.put('/lieux/$lieuId/reviews/$reviewId', {
        'rating': rating,
        'comment': comment,
      });

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to update review',
        'lieu': body['lieu'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error connecting to server'};
    }
  }

  // Delete a review
  static Future<Map<String, dynamic>> deleteReview({
    required String lieuId,
    required String reviewId,
  }) async {
    try {
      final res = await ApiClient.delete('/lieux/$lieuId/reviews/$reviewId');

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to delete review',
        'lieu': body['lieu'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error connecting to server'};
    }
  }
}
