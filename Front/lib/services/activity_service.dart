import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';
import '../models/activity_model.dart';

class ActivityService {
  /// Fetch all activities with optional filters.
  static Future<List<ActivityModel>> getActivities({
    Map<String, String>? filters,
  }) async {
    final res = await ApiClient.get('/activites', auth: false, query: filters);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['activities'] as List? ?? [];
      return list
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Fetch a single activity by id.
  static Future<ActivityModel?> getActivityById(String id) async {
    final res = await ApiClient.get('/activites/$id', auth: false);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['activite'] as Map<String, dynamic>? ?? body;
      return ActivityModel.fromJson(data);
    }
    return null;
  }

  /// Organizer: fetch their own active activities.
  static Future<List<ActivityModel>> getMyActivities() async {
    final res = await ApiClient.get('/activites/my-activities');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['activities'] ?? body['activites']) as List? ?? [];
      return list
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Organizer: fetch archived activities.
  static Future<List<ActivityModel>> getArchivedActivities() async {
    final res = await ApiClient.get('/activites/archived');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['activities'] ?? body['activites']) as List? ?? [];
      return list
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Search activities by keyword.
  static Future<List<ActivityModel>> searchActivities(String q) async {
    final res = await ApiClient.get(
      '/activites/search',
      auth: false,
      query: {'q': q},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['activities'] ?? body['activites']) as List? ?? [];
      return list
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Delete an activity (organizer only).
  static Future<bool> deleteActivity(String id) async {
    final res = await ApiClient.delete('/activites/$id');
    return res.statusCode == 200;
  }

  /// Create a new activity with optional photos (multipart).
  static Future<Map<String, dynamic>> createActivity({
    required String titre,
    required String typeActivite,
    String? categorie,
    required String description,
    required double prix,
    required int capaciteMax,
    required String lieu,
    required double duree,
    required DateTime dateDebut,
    DateTime? dateFin,
    List<File> photos = const [],
    List<String> equipementsInclus = const [],
    Map<String, dynamic>? coordonnees,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final uri = Uri.parse('${ApiClient.baseUrl}/activites');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['titre'] = titre
        ..fields['type_activite'] = typeActivite
        ..fields['description'] = description
        ..fields['prix'] = prix.toString()
        ..fields['capacite_max'] = capaciteMax.toString()
        ..fields['lieu'] = lieu
        ..fields['duree'] = duree.toString()
        ..fields['date_debut'] = dateDebut.toIso8601String();

      if (categorie != null && categorie.isNotEmpty) {
        request.fields['categorie'] = categorie;
      }

      if (dateFin != null) {
        request.fields['date_fin'] = dateFin.toIso8601String();
      }

      if (equipementsInclus.isNotEmpty) {
        request.fields['equipements_inclus'] = jsonEncode(equipementsInclus);
      }

      if (coordonnees != null) {
        request.fields['coordonnees'] = jsonEncode(coordonnees);
      }

      for (final file in photos) {
        request.files.add(
          await http.MultipartFile.fromPath('photos', file.path),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 201 || res.statusCode == 200) {
        return {'success': true, 'activite': body['activite'] ?? body};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Error during creation.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update an existing activity (organizer only, multipart PUT).
  static Future<Map<String, dynamic>> updateActivity({
    required String id,
    required String titre,
    required String typeActivite,
    String? categorie,
    required String description,
    required double prix,
    required int capaciteMax,
    required String lieu,
    required double duree,
    required DateTime dateDebut,
    DateTime? dateFin,
    List<File> newPhotos = const [],
    List<String> equipementsInclus = const [],
    Map<String, dynamic>? coordonnees,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated.'};
      }

      final uri = Uri.parse('${ApiClient.baseUrl}/activites/$id');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['titre'] = titre
        ..fields['type_activite'] = typeActivite
        ..fields['description'] = description
        ..fields['prix'] = prix.toString()
        ..fields['capacite_max'] = capaciteMax.toString()
        ..fields['lieu'] = lieu
        ..fields['duree'] = duree.toString()
        ..fields['date_debut'] = dateDebut.toIso8601String();

      if (categorie != null && categorie.isNotEmpty) {
        request.fields['categorie'] = categorie;
      }

      if (dateFin != null) {
        request.fields['date_fin'] = dateFin.toIso8601String();
      }

      if (equipementsInclus.isNotEmpty) {
        request.fields['equipements_inclus'] = jsonEncode(equipementsInclus);
      }

      if (coordonnees != null) {
        request.fields['coordonnees'] = jsonEncode(coordonnees);
      }

      for (final file in newPhotos) {
        request.files.add(
          await http.MultipartFile.fromPath('photos', file.path),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        return {'success': true, 'activite': body['activite'] ?? body};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Error during update.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
