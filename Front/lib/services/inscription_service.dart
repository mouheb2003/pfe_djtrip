import 'dart:convert';
import '../config/api_config.dart';
import '../models/inscription.dart';
import 'http_client.dart';

class InscriptionService {
  static const String baseUrl = '${ApiConfig.baseUrl}/inscriptions';

  // ========================================
  // TOURISTE - Gérer ses inscriptions
  // ========================================

  /// S'inscrire à une activité (Touriste)
  static Future<Map<String, dynamic>> createInscription({
    required String activiteId,
    int nombreParticipants = 1,
    String? messageTouriste,
  }) async {
    try {
      final body = {
        'activite_id': activiteId,
        'nombre_participants': nombreParticipants,
      };

      if (messageTouriste != null && messageTouriste.isNotEmpty) {
        body['message_touriste'] = messageTouriste;
      }

      final response = await HttpClient.post(
        baseUrl,
        headers: await HttpClient.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de l\'inscription');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  /// Obtenir les inscriptions du touriste connecté
  static Future<List<Inscription>> getMesInscriptions({String? statut}) async {
    try {
      final queryParams = <String, String>{};
      if (statut != null) {
        queryParams['statut'] = statut;
      }

      final uri = Uri.parse(
        '$baseUrl/mes-inscriptions',
      ).replace(queryParameters: queryParams);

      final response = await HttpClient.get(
        uri.toString(),
        headers: await HttpClient.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> inscriptionsJson = data['inscriptions'];
        return inscriptionsJson
            .map((json) => Inscription.fromJson(json))
            .toList();
      } else {
        throw Exception('Error fetching inscriptions');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  /// Obtenir les inscriptions approuvées (activités rejointes)
  static Future<List<Inscription>> getActivitesRejointes() async {
    return getMesInscriptions(statut: 'approuvee');
  }

  /// Obtenir les inscriptions en attente
  static Future<List<Inscription>> getInscriptionsEnAttente() async {
    return getMesInscriptions(statut: 'en_attente');
  }

  /// Annuler une inscription (Touriste)
  static Future<void> annulerInscription(String inscriptionId) async {
    try {
      final response = await HttpClient.put(
        '$baseUrl/$inscriptionId/annuler',
        headers: await HttpClient.getAuthHeaders(),
        body: jsonEncode({}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de l\'annulation');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // ========================================
  // ORGANISATEUR - Gérer les demandes
  // ========================================

  /// Obtenir toutes les demandes d'inscription (Organisateur)
  static Future<List<Inscription>> getMesDemandes({
    String? statut,
    String? activiteId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (statut != null) {
        queryParams['statut'] = statut;
      }
      if (activiteId != null) {
        queryParams['activite_id'] = activiteId;
      }

      final uri = Uri.parse(
        '$baseUrl/organisateur/mes-demandes',
      ).replace(queryParameters: queryParams);

      final response = await HttpClient.get(
        uri.toString(),
        headers: await HttpClient.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> inscriptionsJson = data['inscriptions'];
        return inscriptionsJson
            .map((json) => Inscription.fromJson(json))
            .toList();
      } else {
        throw Exception('Error fetching requests');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  /// Obtenir les demandes en attente (Organisateur)
  static Future<List<Inscription>> getDemandesEnAttente() async {
    try {
      final response = await HttpClient.get(
        '$baseUrl/organisateur/en-attente',
        headers: await HttpClient.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> inscriptionsJson = data['inscriptions'];
        return inscriptionsJson
            .map((json) => Inscription.fromJson(json))
            .toList();
      } else {
        throw Exception('Error fetching requests');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  /// Approuver une inscription (Organisateur)
  static Future<Map<String, dynamic>> approuverInscription(
    String inscriptionId, {
    String? messageOrganisateur,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (messageOrganisateur != null && messageOrganisateur.isNotEmpty) {
        body['message_organisateur'] = messageOrganisateur;
      }

      final response = await HttpClient.put(
        '$baseUrl/$inscriptionId/approuver',
        headers: await HttpClient.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de l\'approbation');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  /// Refuser une inscription (Organisateur)
  static Future<Map<String, dynamic>> refuserInscription(
    String inscriptionId, {
    String? messageOrganisateur,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (messageOrganisateur != null && messageOrganisateur.isNotEmpty) {
        body['message_organisateur'] = messageOrganisateur;
      }

      final response = await HttpClient.put(
        '$baseUrl/$inscriptionId/refuser',
        headers: await HttpClient.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors du refus');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // ========================================
  // COMMUN - Consultation
  // ========================================

  /// Obtenir une inscription par ID
  static Future<Inscription> getInscriptionById(String inscriptionId) async {
    try {
      final response = await HttpClient.get(
        '$baseUrl/$inscriptionId',
        headers: await HttpClient.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Inscription.fromJson(data['inscription']);
      } else {
        throw Exception('Booking not found');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }
}
