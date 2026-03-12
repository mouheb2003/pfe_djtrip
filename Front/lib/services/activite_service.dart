import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/activite.dart';
import '../services/storage_service.dart';
import 'http_client.dart';

class ActiviteService {
  static const String baseUrl = '${ApiConfig.baseUrl}/activites';

  // Créer une nouvelle activité (organisateur seulement)
  static Future<Map<String, dynamic>> createActivite({
    required String titre,
    required String description,
    required String typeActivite,
    required String lieu,
    Map<String, double>? coordonnees,
    required double duree,
    required double prix,
    required int capaciteMax,
    required List<String> languesDisponibles,
    required DateTime dateDebut,
    required DateTime dateFin,
    List<String>? photos,
    String niveauDifficulte = 'Facile',
    List<String>? equipementsInclus,
    List<String>? aApporter,
    List<DateTime>? datesDisponibles,
  }) async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        throw Exception('Token non disponible');
      }

      final body = {
        'titre': titre,
        'description': description,
        'type_activite': typeActivite,
        'lieu': lieu,
        'duree': duree,
        'prix': prix,
        'capacite_max': capaciteMax,
        'langues_disponibles': languesDisponibles,
        'date_debut': dateDebut.toIso8601String(),
        'date_fin': dateFin.toIso8601String(),
        'niveau_difficulte': niveauDifficulte,
      };

      if (coordonnees != null) {
        body['coordonnees'] = coordonnees;
      }
      if (photos != null && photos.isNotEmpty) {
        body['photos'] = photos;
      }
      if (equipementsInclus != null) {
        body['equipements_inclus'] = equipementsInclus;
      }
      if (aApporter != null) {
        body['a_apporter'] = aApporter;
      }
      if (datesDisponibles != null) {
        body['dates_disponibles'] = datesDisponibles
            .map((date) => date.toIso8601String())
            .toList();
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
        throw Exception(error['message'] ?? 'Error creating activity');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Obtenir toutes les activités avec filtres optionnels
  static Future<List<Activite>> getAllActivites({
    String? typeActivite,
    String? lieu,
    String? statut,
    String? niveauDifficulte,
    double? prixMin,
    double? prixMax,
    String? organisateurId,
    String? temporalite, // 'en_cours', 'a_venir', 'passees', 'disponibles'
  }) async {
    try {
      final queryParams = <String, String>{};
      if (typeActivite != null) queryParams['type_activite'] = typeActivite;
      if (lieu != null) queryParams['lieu'] = lieu;
      if (statut != null) queryParams['statut'] = statut;
      if (niveauDifficulte != null) {
        queryParams['niveau_difficulte'] = niveauDifficulte;
      }
      if (prixMin != null) queryParams['prix_min'] = prixMin.toString();
      if (prixMax != null) queryParams['prix_max'] = prixMax.toString();
      if (organisateurId != null) {
        queryParams['organisateur_id'] = organisateurId;
      }
      if (temporalite != null) {
        queryParams['temporalite'] = temporalite;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> activitesJson = data['activites'];
        return activitesJson.map((json) => Activite.fromJson(json)).toList();
      } else {
        throw Exception('Error fetching activities');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Obtenir une activité par ID
  static Future<Activite> getActiviteById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$id'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Activite.fromJson(data['activite']);
      } else {
        throw Exception('Activity not found');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Obtenir les activités d'un organisateur
  static Future<List<Activite>> getActivitesByOrganisateur(
    String organisateurId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/organisateur/$organisateurId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> activitesJson = data['activites'];
        return activitesJson.map((json) => Activite.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error fetching organizer activities',
        );
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Mettre à jour une activité
  static Future<Map<String, dynamic>> updateActivite(
    String id, {
    String? titre,
    String? description,
    String? typeActivite,
    String? lieu,
    Map<String, double>? coordonnees,
    double? duree,
    double? prix,
    int? capaciteMax,
    List<String>? languesDisponibles,
    List<String>? photos,
    String? niveauDifficulte,
    List<String>? equipementsInclus,
    List<String>? aApporter,
    List<DateTime>? datesDisponibles,
    String? statut,
  }) async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        throw Exception('Token non disponible');
      }

      final body = <String, dynamic>{};
      if (titre != null) body['titre'] = titre;
      if (description != null) body['description'] = description;
      if (typeActivite != null) body['type_activite'] = typeActivite;
      if (lieu != null) body['lieu'] = lieu;
      if (coordonnees != null) body['coordonnees'] = coordonnees;
      if (duree != null) body['duree'] = duree;
      if (prix != null) body['prix'] = prix;
      if (capaciteMax != null) body['capacite_max'] = capaciteMax;
      if (languesDisponibles != null) {
        body['langues_disponibles'] = languesDisponibles;
      }
      if (photos != null) body['photos'] = photos;
      if (niveauDifficulte != null) {
        body['niveau_difficulte'] = niveauDifficulte;
      }
      if (equipementsInclus != null) {
        body['equipements_inclus'] = equipementsInclus;
      }
      if (aApporter != null) body['a_apporter'] = aApporter;
      if (datesDisponibles != null) {
        body['dates_disponibles'] = datesDisponibles
            .map((date) => date.toIso8601String())
            .toList();
      }
      if (statut != null) body['statut'] = statut;

      final response = await HttpClient.put(
        '$baseUrl/$id',
        headers: await HttpClient.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error updating activity');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Supprimer une activité
  static Future<void> deleteActivite(String id) async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        throw Exception('Token non disponible');
      }

      final response = await HttpClient.delete(
        '$baseUrl/$id',
        headers: await HttpClient.getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Rechercher des activités
  static Future<List<Activite>> searchActivites(String query) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/search',
      ).replace(queryParameters: {'query': query});

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> activitesJson = data['activites'];
        return activitesJson.map((json) => Activite.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la recherche');
      }
    } catch (e) {
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  // Obtenir les activités actives uniquement (filtre rapide)
  static Future<List<Activite>> getActiveActivites() async {
    return getAllActivites(statut: 'active');
  }

  // Obtenir les activités par type
  static Future<List<Activite>> getActivitesByType(String type) async {
    return getAllActivites(typeActivite: type);
  }

  // Obtenir les activités dans une fourchette de prix
  static Future<List<Activite>> getActivitesByPriceRange(
    double minPrice,
    double maxPrice,
  ) async {
    return getAllActivites(prixMin: minPrice, prixMax: maxPrice);
  }

  // Obtenir les activités en cours maintenant
  static Future<List<Activite>> getActivitesEnCours() async {
    return getAllActivites(temporalite: 'en_cours');
  }

  // Obtenir les activités à venir (pas encore commencées)
  static Future<List<Activite>> getActivitesAVenir() async {
    return getAllActivites(temporalite: 'a_venir');
  }

  // Obtenir les activités passées (terminées)
  static Future<List<Activite>> getActivitesPassees() async {
    return getAllActivites(temporalite: 'passees');
  }

  // Obtenir les activités disponibles (en cours ou à venir)
  static Future<List<Activite>> getActivitesDisponibles() async {
    return getAllActivites(temporalite: 'disponibles', statut: 'active');
  }
}
