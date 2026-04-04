import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';
import '../models/activity_model.dart';
import 'api_service.dart';

class ActivityService {
  static Map<String, List<ActivityModel>> _emptyTimeline() {
    return {
      'upcoming': const <ActivityModel>[],
      'ongoing': const <ActivityModel>[],
      'past': const <ActivityModel>[],
    };
  }

  static dynamic _decodeNestedJson(dynamic raw) {
    dynamic value = raw;
    for (var i = 0; i < 3; i++) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return <String, dynamic>{};
        try {
          value = jsonDecode(trimmed);
          continue;
        } catch (_) {
          break;
        }
      }
      break;
    }
    return value;
  }

  static Map<String, dynamic> _safeObject(dynamic raw) {
    final decoded = _decodeNestedJson(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic value) {
    final decoded = _decodeNestedJson(value);
    if (decoded is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in decoded) {
        final obj = _safeObject(item);
        if (obj.isNotEmpty) out.add(obj);
      }
      return out;
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _extractTimelineData(Map<String, dynamic> body) {
    final directData = _safeObject(body['data']);
    if (directData.isNotEmpty) return directData;

    final wrapped = _safeObject(body['result']);
    final wrappedData = _safeObject(wrapped['data']);
    if (wrappedData.isNotEmpty) return wrappedData;

    // Some responses incorrectly place a full JSON payload into message/error.
    final messagePayload = _safeObject(body['message']);
    if (messagePayload.isNotEmpty) {
      final nestedData = _safeObject(messagePayload['data']);
      if (nestedData.isNotEmpty) return nestedData;
      return messagePayload;
    }

    final errorPayload = _safeObject(body['error']);
    if (errorPayload.isNotEmpty) {
      final nestedData = _safeObject(errorPayload['data']);
      if (nestedData.isNotEmpty) return nestedData;
      return errorPayload;
    }

    return <String, dynamic>{};
  }

  /// Fetch all activities with optional filters.
  static Future<List<ActivityModel>> getActivities({
    Map<String, String>? filters,
  }) async {
    try {
      final res = await ApiClient.get(
        '/activites',
        auth: false,
        query: filters,
      );
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final list = _safeMapList(body['activities']);
        return list.map(ActivityModel.fromJson).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch all activities grouped by timeline (upcoming, ongoing, past)
  static Future<Map<String, List<ActivityModel>>>
  getActivitiesByTimeline() async {
    try {
      // For pull-to-refresh screens, prefer a fresh response over local cache.
      final res = await ApiClient.get(
        '/activites/timeline',
        auth: false,
        cacheFirst: false,
      );
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final data = _extractTimelineData(body);

        List<ActivityModel> parseList(dynamic listRaw) {
          final items = _safeMapList(listRaw);
          return items
              .map((e) {
                try {
                  return ActivityModel.fromJson(e);
                } catch (err) {
                  print('Error parsing ActivityModel: $err');
                  return null;
                }
              })
              .whereType<ActivityModel>()
              .toList();
        }

        final upcoming = parseList(data['upcoming']);
        final ongoing = parseList(data['ongoing']);
        final past = parseList(data['past']);

        if (body['success'] == true ||
            data.isNotEmpty ||
            upcoming.isNotEmpty ||
            ongoing.isNotEmpty ||
            past.isNotEmpty) {
          return {'upcoming': upcoming, 'ongoing': ongoing, 'past': past};
        }
      }
    } catch (e) {
      print('getActivitiesByTimeline failed safely: $e');
    }

    return _emptyTimeline();
  }

  /// Fetch a single activity by id.
  static Future<ActivityModel?> getActivityById(String id) async {
    try {
      final res = await ApiClient.get('/activites/$id', auth: false);
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final data = (body['activite'] is Map<String, dynamic>)
            ? body['activite'] as Map<String, dynamic>
            : body;
        return ActivityModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Organizer: fetch their own active activities.
  static Future<List<ActivityModel>> getMyActivities() async {
    try {
      final res = await ApiClient.get('/activites/my-activities');
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final list = _safeMapList(body['activities'] ?? body['activites']);
        return list.map(ActivityModel.fromJson).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Organizer: fetch archived activities.
  static Future<List<ActivityModel>> getArchivedActivities() async {
    try {
      final res = await ApiClient.get('/activites/archived');
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final list = _safeMapList(body['activities'] ?? body['activites']);
        return list.map(ActivityModel.fromJson).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Search activities by keyword.
  static Future<List<ActivityModel>> searchActivities(String q) async {
    try {
      final res = await ApiClient.get(
        '/activites/search',
        auth: false,
        query: {'q': q},
      );
      if (res.statusCode == 200) {
        final body = _safeObject(res.body);
        final list = _safeMapList(body['activities'] ?? body['activites']);
        return list.map(ActivityModel.fromJson).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
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
      final body = _safeObject(res.body);

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
      final body = _safeObject(res.body);

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
