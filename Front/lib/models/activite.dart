class OrganisateurInfo {
  final String id;
  final String fullname;
  final String? avatar;
  final double noteMoyenne;
  final int nombreAvis;

  OrganisateurInfo({
    required this.id,
    required this.fullname,
    this.avatar,
    required this.noteMoyenne,
    required this.nombreAvis,
  });

  factory OrganisateurInfo.fromJson(Map<String, dynamic> json) {
    return OrganisateurInfo(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? 'Organisateur',
      avatar: json['avatar'],
      noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
    );
  }
}

class Activite {
  final String id;
  final String titre;
  final String description;
  final String typeActivite;
  final String organisateurId;
  final OrganisateurInfo? organisateur;
  final String lieu;
  final Coordonnees? coordonnees;
  final double duree; // en heures
  final double prix;
  final int capaciteMax;
  final List<String> languesDisponibles;
  final List<String> photos;
  final String niveauDifficulte;
  final List<String> equipementsInclus;
  final List<String> aApporter;
  final List<DateTime> datesDisponibles;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String statut;
  final double noteMoyenne;
  final int nombreAvis;
  final int nombreReservations;
  final DateTime dateCreation;
  final DateTime dateModification;

  Activite({
    required this.id,
    required this.titre,
    required this.description,
    required this.typeActivite,
    required this.organisateurId,
    this.organisateur,
    required this.lieu,
    this.coordonnees,
    required this.duree,
    required this.prix,
    required this.capaciteMax,
    required this.languesDisponibles,
    required this.photos,
    required this.niveauDifficulte,
    required this.equipementsInclus,
    required this.aApporter,
    required this.datesDisponibles,
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
    required this.noteMoyenne,
    required this.nombreAvis,
    required this.nombreReservations,
    required this.dateCreation,
    required this.dateModification,
  });

  factory Activite.fromJson(Map<String, dynamic> json) {
    // Parse organisateur_id - peut être un String ou un objet populé
    String organisateurId = '';
    OrganisateurInfo? organisateurInfo;

    if (json['organisateur_id'] is String) {
      organisateurId = json['organisateur_id'];
    } else if (json['organisateur_id'] is Map) {
      organisateurId = json['organisateur_id']['_id'] ?? '';
      try {
        organisateurInfo = OrganisateurInfo.fromJson(
          json['organisateur_id'] as Map<String, dynamic>,
        );
      } catch (e) {
        print('Error parsing organisateur info: $e');
      }
    }

    // Parse coordonnees - doit être un Map pour être valide
    Coordonnees? parsedCoordonnees;
    if (json['coordonnees'] != null &&
        json['coordonnees'] is Map<String, dynamic>) {
      try {
        parsedCoordonnees = Coordonnees.fromJson(
          json['coordonnees'] as Map<String, dynamic>,
        );
      } catch (e) {
        parsedCoordonnees = null;
      }
    }

    return Activite(
      id: json['_id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      typeActivite: json['type_activite'] ?? '',
      organisateurId: organisateurId,
      organisateur: organisateurInfo,
      lieu: json['lieu'] ?? '',
      coordonnees: parsedCoordonnees,
      duree: (json['duree'] ?? 0).toDouble(),
      prix: (json['prix'] ?? 0).toDouble(),
      capaciteMax: json['capacite_max'] ?? 0,
      languesDisponibles: List<String>.from(json['langues_disponibles'] ?? []),
      photos: List<String>.from(json['photos'] ?? []),
      niveauDifficulte: json['niveau_difficulte'] ?? 'Facile',
      equipementsInclus: List<String>.from(json['equipements_inclus'] ?? []),
      aApporter: List<String>.from(json['a_apporter'] ?? []),
      datesDisponibles:
          (json['dates_disponibles'] as List?)
              ?.map((date) => DateTime.parse(date))
              .toList() ??
          [],
      dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'])
          : DateTime.now(),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'])
          : DateTime.now(),
      statut: json['statut'] ?? 'active',
      noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
      nombreReservations: json['nombre_reservations'] ?? 0,
      dateCreation: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      dateModification: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'titre': titre,
      'description': description,
      'type_activite': typeActivite,
      'organisateur_id': organisateurId,
      'lieu': lieu,
      'coordonnees': coordonnees?.toJson(),
      'duree': duree,
      'prix': prix,
      'capacite_max': capaciteMax,
      'langues_disponibles': languesDisponibles,
      'photos': photos,
      'niveau_difficulte': niveauDifficulte,
      'equipements_inclus': equipementsInclus,
      'a_apporter': aApporter,
      'dates_disponibles': datesDisponibles
          .map((date) => date.toIso8601String())
          .toList(),
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': dateFin.toIso8601String(),
      'statut': statut,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
      'nombre_reservations': nombreReservations,
      'createdAt': dateCreation.toIso8601String(),
      'updatedAt': dateModification.toIso8601String(),
    };
  }
}

// Classe pour les coordonnées GPS
class Coordonnees {
  final double latitude;
  final double longitude;

  Coordonnees({required this.latitude, required this.longitude});

  factory Coordonnees.fromJson(Map<String, dynamic> json) {
    return Coordonnees(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}
