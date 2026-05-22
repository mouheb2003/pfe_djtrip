import 'dart:convert';
import 'api_client.dart';
import '../models/inscription_model.dart';
import '../models/activity_model.dart';

class InscriptionService {
  static Map<String, dynamic> _decodeObject(dynamic raw) {
    try {
      dynamic value = raw;

      // If already a Map, return immediately — no JSON roundtrip needed.
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }

      // Only JSON-decode if it's a String.
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }
    } catch (_) {
      // Never propagate — always return a safe empty map.
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

    // Check for participants key (used by getActivityParticipants endpoint)
    final participants = _decodeObjectList(body['participants']);
    if (participants.isNotEmpty) return participants;

    final dataObj = _decodeObject(body['data']);
    final fromData = _decodeObjectList(dataObj['inscriptions']);
    if (fromData.isNotEmpty) return fromData;

    // Check for participants in data
    final participantsFromData = _decodeObjectList(dataObj['participants']);
    if (participantsFromData.isNotEmpty) return participantsFromData;

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
  /// - pending (join requested)
  /// - approved (already joined)
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

      final blockedStatuses = {'pending', 'approved', 'verified'};
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
      // Map each raw inscription, skipping malformed entries gracefully.
      final result = <InscriptionModel>[];
      for (final item in list) {
        try {
          result.add(InscriptionModel.fromJson(item));
        } catch (_) {
          // Skip malformed inscription entries instead of crashing.
        }
      }
      return result;
    }
    // Surface a clean error message — never expose the raw response body.
    final errorMsg = _extractErrorMessage(res.body);
    throw Exception(errorMsg);
  }

  /// Safely extract an error message from a response body string.
  static String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body.trim());
      if (decoded is Map) {
        final msg = decoded['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {
      // Body was not valid JSON.
    }
    return 'Unable to load inscriptions';
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

  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await ApiClient.get(path, cacheFirst: false);
    print('🔍 [SERVICE] GET $path -> Status: ${res.statusCode}');
    return _decodeObject(res.body);
  }

  /// Get ALL bookings for the tourist, bucketed by reservation status
  /// Returns a map with 'pending', 'confirmed', 'cancelled', 'used'
  static Future<Map<String, List<InscriptionModel>>> getMyBookings() async {
    try {
      final body = await _get('/inscriptions/touriste/my-bookings');
      print('🔍 [SERVICE] API Response body keys: ${body.keys.toList()}');
      print('🔍 [SERVICE] API Response success: ${body['success']}');
      print('🔍 [SERVICE] API Response data type: ${body['data'].runtimeType}');

      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        print('🔍 [SERVICE] Data buckets available: ${data.keys.toList()}');

        for (final key in data.keys) {
          print(
            '🔍 [SERVICE] Bucket "$key": ${data[key] is List ? (data[key] as List).length : 'not a list'}',
          );
        }

        List<InscriptionModel> parseList(dynamic listRaw, String listName) {
          if (listRaw is! List) {
            print('❌ [SERVICE] $listName is not a List: $listRaw');
            return [];
          }

          print('🔍 [SERVICE] Parsing $listName with ${listRaw.length} items');
          final result = <InscriptionModel>[];
          for (int i = 0; i < listRaw.length; i++) {
            try {
              final item = listRaw[i];

              // Ensure item is a Map before parsing
              if (item is Map<String, dynamic>) {
                final inscription = InscriptionModel.fromJson(item);
                result.add(inscription);
                print(
                  '🔍 [SERVICE] $listName[$i]: ID=${inscription.id}, Status=${inscription.statut}, ActivityID=${inscription.activite?['_id']}',
                );
              } else {
                print('❌ [SERVICE] Item $i in $listName is not a Map: $item');
              }
            } catch (e) {
              print('❌ [SERVICE] Error parsing item $i in $listName: $e');
              continue; // Skip problematic items
            }
          }

          print('✅ [SERVICE] $listName parsed: ${result.length} items');
          return result;
        }

        // Only accept the normalized `pending` key from the API.
        final pending = parseList(data['pending'], 'pending');

        final result = {
          'pending': pending,
          'confirmed': parseList(data['confirmed'], 'confirmed'),
          'cancelled': parseList(data['cancelled'], 'cancelled'),
          'used': parseList(data['used'], 'used'),
        };

        print(
          '✅ [SERVICE] Final buckets: pending=${result['pending']!.length}, confirmed=${result['confirmed']!.length}, cancelled=${result['cancelled']!.length}, used=${result['used']!.length}',
        );
        return result;
      }

      print(
        '⚠️ [SERVICE] Invalid response: success=${body['success']}, data is ${body['data']}',
      );
      if (body['message'] != null) {
        print('❌ [SERVICE] API Error Message: ${body['message']}');
      }
      return {'pending': [], 'confirmed': [], 'cancelled': [], 'used': []};
    } catch (e) {
      print('❌ [SERVICE] Error in getMyBookings: $e');
      throw Exception(_extractErrorMessage(e.toString()));
    }
  }

  /// Tourist: cancel an inscription.
  static Future<bool> cancelInscription(String inscriptionId, {String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
    }
    final res = await ApiClient.put('/inscriptions/$inscriptionId/annuler', body);
    return res.statusCode == 200;
  }

  /// Tourist: delete an inscription.
  static Future<bool> deleteInscription(String inscriptionId) async {
    final res = await ApiClient.delete('/inscriptions/$inscriptionId');
    return res.statusCode == 200;
  }

  /// Organizer: pending requests.
  static Future<List<InscriptionModel>> getOrganizerPendingRequests() async {
    final res = await ApiClient.get(
      '/inscriptions/organisateur/en-attente',
      cacheFirst: false,
    );
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
    final res = await ApiClient.get(
      '/inscriptions/organisateur/mes-demandes',
      cacheFirst: false,
    );
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

  /// Public: Get participants for any activity (any authenticated user can see)
  static Future<List<InscriptionModel>> getActivityParticipants({
    required String activiteId,
  }) async {
    final query = <String, String>{'activite_id': activiteId};

    final res = await ApiClient.get(
      '/inscriptions/activite/$activiteId/participants',
      query: query,
      cacheFirst: false,
      cacheTtl: const Duration(seconds: 1),
    );
    if (res.statusCode == 200) {
      final body = _decodeObject(res.body);
      final list = _extractInscriptions(body);

      // Map the backend response to frontend model structure
      final mappedList = list.map((participant) {
        print('🔍 [SERVICE DEBUG] Original participant: $participant');

        // If participant has the new structure with nested touriste object
        if (participant['touriste'] != null) {
          // Create a new structure that matches InscriptionModel.fromJson expectations
          final mapped = {
            '_id': participant['_id'],
            'statut': participant['statut'],
            'nombre_participants':
                participant['nombreParticipants'] ??
                participant['nombre_participants'],
            'prix_total': participant['prixTotal'] ?? participant['prix_total'],
            'date_demande':
                participant['dateDemande'] ?? participant['date_demande'],
            'touriste_id': participant['touriste']['_id'],
            'activite_id': participant['activite']['_id'],
            'touriste':
                participant['touriste'], // Keep the nested object for UI display
            'activite':
                participant['activite'], // Keep the nested object for UI display
          };
          print('🔍 [SERVICE DEBUG] Mapped participant: $mapped');
          return mapped;
        }
        // Return original structure if no nested touriste object
        print('🔍 [SERVICE DEBUG] Using original participant structure');
        return participant;
      }).toList();

      return mappedList.map(InscriptionModel.fromJson).toList();
    }
    try {
      final body = _decodeObject(res.body);
      throw Exception(
        (body['message'] as String?) ?? 'Unable to load activity participants',
      );
    } catch (_) {
      throw Exception('Unable to load activity participants');
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
      '/inscriptions/$inscriptionId/approve',
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
      '/inscriptions/$inscriptionId/reject',
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

  /// Public: get tourist's participated activities count
  static Future<int> getTouristeParticipatedCount(String touristeId) async {
    try {
      final response = await ApiClient.get(
        '/inscriptions/touriste/$touristeId/count',
        auth: false,
        cacheFirst: false,
      );

      if (response.statusCode == 200) {
        final data = _decodeObject(response.body);
        return data['count'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// Organizer: get inscription by ID for QR verification
  static Future<InscriptionModel?> getInscriptionById(
    String inscriptionId,
  ) async {
    try {
      final res = await ApiClient.get(
        '/inscriptions/$inscriptionId',
        cacheFirst: false,
      );
      if (res.statusCode == 200) {
        final body = _decodeObject(res.body);
        final data = body['data'] ?? body['inscription'];
        if (data is Map<String, dynamic>) {
          return InscriptionModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching inscription: $e');
      return null;
    }
  }

  /// Organizer: validate a scanned QR code and get the booking state.
  static Future<Map<String, dynamic>> validateQrBooking(String qrData) async {
    try {
      print('[QR SERVICE OLD] Starting validation for QR: $qrData');

      final res = await ApiClient.post('/inscriptions/qr/validate', {
        'qrData': qrData,
      });

      print('[QR SERVICE OLD] Status code: ${res.statusCode}');
      print('[QR SERVICE OLD] Response body: ${res.body}');

      final body = _decodeObject(res.body);
      final data = _decodeObject(body['data']);

      print('[QR SERVICE OLD] Parsed body: $body');
      print('[QR SERVICE OLD] Parsed data: $data');
      print('[QR SERVICE OLD] Success: ${body['success']}');

      return {
        'success': body['success'] == true || res.statusCode == 200,
        'statusCode': res.statusCode,
        'message': body['message'] ?? 'Unknown validation result',
        'code': body['code'],
        'booking': data['booking'] ?? body['booking'],
        'canMarkUsed':
            data['canMarkUsed'] == true || body['canMarkUsed'] == true,
        'tokenType': data['tokenType'] ?? body['tokenType'],
      };
    } catch (e) {
      print('[QR SERVICE OLD] Exception: $e');
      return {
        'success': false,
        'statusCode': 500,
        'message': e.toString(),
        'code': 'ERROR',
        'booking': null,
        'canMarkUsed': false,
      };
    }
  }

  /// Organizer: mark a validated booking as used.
  static Future<bool> markInscriptionAsUsed(String inscriptionId) async {
    try {
      final res = await ApiClient.put('/inscriptions/$inscriptionId/verifier', {
        'statut': 'verified',
      });
      return res.statusCode == 200;
    } catch (e) {
      print('Error verifying inscription: $e');
      return false;
    }
  }

  /// Backward-compatible alias.
  static Future<bool> verifyInscription(String inscriptionId) async {
    return markInscriptionAsUsed(inscriptionId);
  }

  // Organizer: Get all reservations for organizer
  static Future<List<InscriptionModel>> getOrganizerReservations() async {
    try {
      final res = await ApiClient.get(
        '/inscriptions/organisateur/mes-demandes',
      );

      if (res.statusCode == 200) {
        final body = _decodeObject(res.body);
        final inscriptions = _extractInscriptions(body);

        return inscriptions.map((inscriptionData) {
          return InscriptionModel.fromJson(inscriptionData);
        }).toList();
      } else {
        throw Exception('Failed to load reservations: ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading reservations: $e');
    }
  }

  // Organizer: Approve a reservation
  static Future<bool> approveReservation(
    String inscriptionId, {
    String? messageOrganisateur,
  }) async {
    try {
      final res = await ApiClient.put('/inscriptions/$inscriptionId/approve', {
        'message_organisateur': messageOrganisateur ?? '',
      });

      return res.statusCode == 200;
    } catch (e) {
      print('Error approving reservation: $e');
      return false;
    }
  }

  // Organizer: Reject a reservation
  static Future<bool> rejectReservation(
    String inscriptionId, {
    String? messageOrganisateur,
  }) async {
    try {
      final res = await ApiClient.put('/inscriptions/$inscriptionId/reject', {
        'message_organisateur': messageOrganisateur ?? '',
      });

      return res.statusCode == 200;
    } catch (e) {
      print('Error rejecting reservation: $e');
      return false;
    }
  }

  /// Organizer: Add an external/manual participant to an activity.
  static Future<Map<String, dynamic>> addExternalParticipant({
    required String activiteId,
    required String externalName,
    String? externalPhone,
    String? externalEmail,
    required int nombreParticipants,
  }) async {
    try {
      final body = <String, dynamic>{
        'activite_id': activiteId,
        'externalName': externalName,
        'nombre_participants': nombreParticipants,
      };
      if (externalPhone != null && externalPhone.isNotEmpty) {
        body['externalPhone'] = externalPhone;
      }
      if (externalEmail != null && externalEmail.isNotEmpty) {
        body['externalEmail'] = externalEmail;
      }

      final res = await ApiClient.post('/inscriptions/organisateur/external', body);
      final resBody = _decodeObject(res.body);

      if (res.statusCode == 201) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'External participant added successfully',
          'inscription': resBody['inscription'] != null
              ? InscriptionModel.fromJson(resBody['inscription'])
              : null,
        };
      }

      return {
        'success': false,
        'message': resBody['message'] ?? 'Failed to add participant',
      };
    } catch (e) {
      print('Error adding external participant: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
