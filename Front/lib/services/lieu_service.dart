import 'dart:convert';

import '../models/lieu_model.dart';
import 'api_client.dart';

class LieuService {
  static Future<List<LieuModel>> getLieux({
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
