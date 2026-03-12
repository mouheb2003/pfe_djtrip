import 'dart:convert';
import '../config/api_config.dart';
import '../models/activite.dart';
import 'http_client.dart';

class FavoritesService {
  static Future<List<String>> getFavoriteIds() async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.get(
      '${ApiConfig.baseUrl}/users/me/favorites',
      headers: headers,
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) {
          final id = e is Map ? e['_id']?.toString() : e?.toString();
          return id ?? '';
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }

  static Future<List<Activite>> getFavorites() async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.get(
      '${ApiConfig.baseUrl}/users/me/favorites',
      headers: headers,
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List;
    return list
        .map((e) => Activite.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<bool> addFavorite(String activityId) async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.post(
      '${ApiConfig.baseUrl}/users/me/favorites/$activityId',
      headers: headers,
    );
    return response.statusCode == 200;
  }

  static Future<bool> removeFavorite(String activityId) async {
    final headers = await HttpClient.getAuthHeaders();
    final response = await HttpClient.delete(
      '${ApiConfig.baseUrl}/users/me/favorites/$activityId',
      headers: headers,
    );
    return response.statusCode == 200;
  }

  static Future<bool> toggleFavorite(String activityId, bool currentlyFavorite) async {
    if (currentlyFavorite) {
      return removeFavorite(activityId);
    } else {
      return addFavorite(activityId);
    }
  }
}
