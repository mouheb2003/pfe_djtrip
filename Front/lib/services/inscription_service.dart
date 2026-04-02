import 'dart:convert';
import 'api_client.dart';
import '../models/inscription_model.dart';

class InscriptionService {
  /// Tourist: get all my inscriptions (optionally filtered by status).
  static Future<List<InscriptionModel>> getMyInscriptions({
    String? statut,
  }) async {
    final query = statut != null ? <String, String>{'statut': statut} : null;
    final res = await ApiClient.get(
      '/inscriptions/mes-inscriptions',
      query: query,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['inscriptions'] as List? ?? [];
      return list
          .map((i) => InscriptionModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    // Surface the backend/network error instead of returning an empty list silently.
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
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
    final resBody = jsonDecode(res.body) as Map<String, dynamic>;
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
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['inscriptions'] as List? ?? [];
      return list
          .map((i) => InscriptionModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
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
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['inscriptions'] as List? ?? [];
      return list
          .map((i) => InscriptionModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
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
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['inscriptions'] as List? ?? [];
      return list
          .map((i) => InscriptionModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
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
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {'activitiesCount': 0, 'totalBookings': 0, 'totalRevenue': 0.0};
  }

  /// Tourist stats: totalBookings.
  static Future<Map<String, dynamic>> getTouristStats() async {
    final res = await ApiClient.get('/inscriptions/stats/tourist');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {'totalBookings': 0};
  }
}
