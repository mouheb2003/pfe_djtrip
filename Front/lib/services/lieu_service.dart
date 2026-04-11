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
    final res = await ApiClient.get('/lieux/$id', auth: false);
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
}
