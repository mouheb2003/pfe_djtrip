import 'dart:convert';
import 'api_client.dart';
import '../models/inscription_model.dart';
import '../models/activity_model.dart';

class InscriptionService {
  static Map<String, dynamic> _decodeObject(dynamic raw) {
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

    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _decodeObjectList(dynamic rawList) {
    dynamic value = rawList;

    for (var i = 0; i < 3; i++) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return const <Map<String, dynamic>>[];
        try {
          value = jsonDecode(trimmed);
          continue;
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }
      break;
    }

    if (value is! List) return const <Map<String, dynamic>>[];
    return value.map(_decodeObject).where((e) => e.isNotEmpty).toList();
  }

  static List<Map<String, dynamic>> _extractInscriptions(
    Map<String, dynamic> body,
  ) {
    final direct = _decodeObjectList(body['inscriptions']);
    if (direct.isNotEmpty) return direct;

    final dataObj = _decodeObject(body['data']);
    final fromData = _decodeObjectList(dataObj['inscriptions']);
    if (fromData.isNotEmpty) return fromData;

    final resultObj = _decodeObject(body['result']);
    return _decodeObjectList(resultObj['inscriptions']);
  }

  static List<Map<String, dynamic>> _extractActivities(
    Map<String, dynamic> body,
  ) {
    final direct = _decodeObjectList(body['activities'] ?? body['activites']);
    if (direct.isNotEmpty) return direct;

    final dataObj = _decodeObject(body['data']);
    final fromData = _decodeObjectList(
      dataObj['activities'] ?? dataObj['activites'],
    );
    if (fromData.isNotEmpty) return fromData;

    final resultObj = _decodeObject(body['result']);
    return _decodeObjectList(resultObj['activities'] ?? resultObj['activites']);
  }

  /// Tourist: get only activities that are not already joined/requested.
  /// Excludes activities with existing inscriptions in statuses:
  /// - en_attente (join requested)
  /// - approuvee (already joined)
  static Future<List<ActivityModel>> getJoinableActivities({
    Map<String, String>? filters,
  }) async {
    try {
      final mergedFilters = <String, String>{...?filters};
      mergedFilters.putIfAbsent('statut', () => 'active');

      final results = await Future.wait([
        ApiClient.get(
          '/activites',
          auth: false,
          query: mergedFilters.isEmpty ? null : mergedFilters,
          cacheFirst: false,
        ),
        getMyInscriptions(),
      ]);

      final activitiesRes = results[0] as dynamic;
      final inscriptions = results[1] as List<InscriptionModel>;

      if (activitiesRes.statusCode != 200) {
        return const <ActivityModel>[];
      }

      final body = _decodeObject(activitiesRes.body);
      final rawActivities = _extractActivities(body);
      final allActivities = rawActivities.map(ActivityModel.fromJson).toList();

      final blockedStatuses = {'en_attente', 'approuvee'};
      final blockedIds = inscriptions
          .where((i) => blockedStatuses.contains(i.statut))
          .map((i) => (i.activite?['_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final now = DateTime.now();
      return allActivities.where((activity) {
        if (blockedIds.contains(activity.id)) return false;
        if (activity.statut != 'active') return false;
        if (activity.dateFin != null && !activity.dateFin!.isAfter(now)) {
          return false;
        }
        return true;
      }).toList();
    } catch (_) {
      return const <ActivityModel>[];
    }
  }

  /// Tourist: get all my inscriptions (optionally filtered by status).
  static Future<List<InscriptionModel>> getMyInscriptions({
    String? statut,
  }) async {
    final query = statut != null ? <String, String>{'statut': statut} : null;
    final res = await ApiClient.get(
      '/inscriptions/mes-inscriptions',
      query: query,
      cacheFirst: false,
    );
    if (res.statusCode == 200) {
      final body = _decodeObject(res.body);
      final list = _extractInscriptions(body);
      return list.map(InscriptionModel.fromJson).toList();
    }
    // Surface the backend/network error instead of returning an empty list silently.
    try {
      final body = _decodeObject(res.body);
      throw Exception(
        (body['message'] as String?) ?? 'Unable to load inscriptions',
      );
    } catch (_) {
      throw Exception('Unable to load inscriptions');
    }
  }

  /// Tourist: book an activity.
  static Future<Map<String, dynamic>> createInscription({
    required String activiteId,
    required int nombreParticipants,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'activite_id': activiteId,
      'nombre_participants': nombreParticipants,
    };
    if (message != null && message.isNotEmpty) {
      body['message_touriste'] = message;
    }
    final res = await ApiClient.post('/inscriptions', body);
    final resBody = _decodeObject(res.body);
    if (res.statusCode == 201) {
      return {'success': true, 'inscription': resBody['inscription']};
    }
    return {'success': false, 'message': resBody['message'] ?? 'Booking error'};
  }

  /// Tourist: cancel an inscription.
  static Future<bool> cancelInscription(String inscriptionId) async {
    final res = await ApiClient.put('/inscriptions/$inscriptionId/annuler', {});
    return res.statusCode == 200;
  }

  /// Organizer: pending requests.
  static Future<List<InscriptionModel>> getOrganizerPendingRequests() async {
    final res = await ApiClient.get('/inscriptions/organisateur/en-attente');
    if (res.statusCode == 200) {
      final body = _decodeObject(res.body);
      final list = _extractInscriptions(body);
      return list.map(InscriptionModel.fromJson).toList();
    }
    try {
      final body = _decodeObject(res.body);
      throw Exception(
        (body['message'] as String?) ?? 'Unable to load pending requests',
      );
    } catch (_) {
      throw Exception('Unable to load pending requests');
    }
  }

  /// Organizer: all requests (all statuses).
  static Future<List<InscriptionModel>> getOrganizerAllRequests() async {
    final res = await ApiClient.get('/inscriptions/organisateur/mes-demandes');
    if (res.statusCode == 200) {
      final body = _decodeObject(res.body);
      final list = _extractInscriptions(body);
      return list.map(InscriptionModel.fromJson).toList();
    }
    try {
      final body = _decodeObject(res.body);
      throw Exception(
        (body['message'] as String?) ?? 'Unable to load organizer requests',
      );
    } catch (_) {
      throw Exception('Unable to load organizer requests');
    }
  }

  /// Organizer: inscriptions filtered by status and/or activity.
  static Future<List<InscriptionModel>> getOrganizerInscriptions({
    String? statut,
    String? activiteId,
  }) async {
    final query = <String, String>{};
    if (statut != null && statut.isNotEmpty) query['statut'] = statut;
    if (activiteId != null && activiteId.isNotEmpty) {
      query['activite_id'] = activiteId;
    }

    final res = await ApiClient.get(
      '/inscriptions/organisateur/mes-demandes',
      query: query.isEmpty ? null : query,
    );
    if (res.statusCode == 200) {
      final body = _decodeObject(res.body);
      final list = _extractInscriptions(body);
      return list.map(InscriptionModel.fromJson).toList();
    }
    try {
      final body = _decodeObject(res.body);
      throw Exception(
        (body['message'] as String?) ?? 'Unable to load organizer inscriptions',
      );
    } catch (_) {
      throw Exception('Unable to load organizer inscriptions');
    }
  }

  /// Organizer: approve an inscription.
  static Future<bool> approveInscription(
    String inscriptionId, {
    String? message,
  }) async {
    final body = <String, dynamic>{};
    if (message != null) body['message_organisateur'] = message;
    final res = await ApiClient.put(
      '/inscriptions/$inscriptionId/approuver',
      body,
    );
    return res.statusCode == 200;
  }

  /// Organizer: reject an inscription.
  static Future<bool> rejectInscription(
    String inscriptionId, {
    String? message,
  }) async {
    final body = <String, dynamic>{};
    if (message != null) body['message_organisateur'] = message;
    final res = await ApiClient.put(
      '/inscriptions/$inscriptionId/refuser',
      body,
    );
    return res.statusCode == 200;
  }

  /// Organizer stats: activitiesCount, totalBookings, totalRevenue.
  static Future<Map<String, dynamic>> getOrganizerStats() async {
    final res = await ApiClient.get('/inscriptions/stats/organizer');
    if (res.statusCode == 200) {
      return _decodeObject(res.body);
    }
    return {'activitiesCount': 0, 'totalBookings': 0, 'totalRevenue': 0.0};
  }

  /// Tourist stats: totalBookings.
  static Future<Map<String, dynamic>> getTouristStats() async {
    final res = await ApiClient.get(
      '/inscriptions/stats/tourist',
      cacheFirst: false,
    );
    if (res.statusCode == 200) {
      return _decodeObject(res.body);
    }
    return {'totalBookings': 0};
  }
}
