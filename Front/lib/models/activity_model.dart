class ActivityModel {
  final String id;
  final String titre;
  final String description;
  final String typeActivite;
  final String categorie;
  final String lieu;
  final double duree;
  final double prix;
  final int capaciteMax;
  final int nombreReservations;
  final List<String> photos;
  final List<String> languesDisponibles;
  final List<String> equipementsInclus;
  final List<String> aApporter;
  final String niveauDifficulte;
  final double noteMoyenne;
  final int nombreAvis;
  final String statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final Map<String, dynamic>? organisateur;
  final Map<String, dynamic>? coordonnees;

  const ActivityModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.typeActivite,
    this.categorie = '',
    required this.lieu,
    required this.duree,
    required this.prix,
    required this.capaciteMax,
    this.nombreReservations = 0,
    this.photos = const [],
    this.languesDisponibles = const ['French'],
    this.equipementsInclus = const [],
    this.aApporter = const [],
    this.niveauDifficulte = 'Easy',
    this.noteMoyenne = 0,
    this.nombreAvis = 0,
    this.statut = 'active',
    this.dateDebut,
    this.dateFin,
    this.organisateur,
    this.coordonnees,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['_id'] as String? ?? '',
      titre: json['titre'] as String? ?? '',
      description: json['description'] as String? ?? '',
      typeActivite: json['type_activite'] as String? ?? '',
      categorie: json['categorie'] as String? ?? '',
      lieu: json['lieu'] as String? ?? '',
      duree: (json['duree'] as num? ?? 0).toDouble(),
      prix: (json['prix'] as num? ?? 0).toDouble(),
      capaciteMax: (json['capacite_max'] as num? ?? 0).toInt(),
      nombreReservations: (json['nombre_reservations'] as num? ?? 0).toInt(),
      photos: (json['photos'] is List) 
          ? List<String>.from(json['photos'] as List) 
          : [],
      languesDisponibles: (json['langues_disponibles'] is List)
          ? List<String>.from(json['langues_disponibles'] as List)
          : const ['French'],
      equipementsInclus: (json['equipements_inclus'] is List)
          ? List<String>.from(json['equipements_inclus'] as List)
          : const [],
      aApporter: (json['a_apporter'] is List)
          ? List<String>.from(json['a_apporter'] as List)
          : const [],
      niveauDifficulte: json['niveau_difficulte']?.toString() ?? 'Easy',
      noteMoyenne: (json['note_moyenne'] as num? ?? 0).toDouble(),
      nombreAvis: (json['nombre_avis'] as num? ?? 0).toInt(),
      statut: json['statut']?.toString() ?? 'active',
      dateDebut: json['date_debut'] != null
          ? DateTime.tryParse(json['date_debut'].toString())
          : null,
      dateFin: json['date_fin'] != null
          ? DateTime.tryParse(json['date_fin'].toString())
          : null,
      organisateur: json['organisateur_id'] is Map<String, dynamic>
          ? json['organisateur_id'] as Map<String, dynamic>
          : null,
      coordonnees: json['coordonnees'] is Map<String, dynamic>
          ? json['coordonnees'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'titre': titre,
      'description': description,
      'type_activite': typeActivite,
      'categorie': categorie,
      'lieu': lieu,
      'duree': duree,
      'prix': prix,
      'capacite_max': capaciteMax,
      'nombre_reservations': nombreReservations,
      'photos': photos,
      'langues_disponibles': languesDisponibles,
      'equipements_inclus': equipementsInclus,
      'a_apporter': aApporter,
      'niveau_difficulte': niveauDifficulte,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
      'statut': statut,
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
      'organisateur_id': organisateur,
      'coordonnees': coordonnees,
    };
  }

  String get thumbnailUrl => photos.isNotEmpty ? photos.first : '';

  int get placesDisponibles =>
      (capaciteMax - nombreReservations).clamp(0, capaciteMax);

  String get prixFormatted =>
      '${prix.toStringAsFixed(prix.truncateToDouble() == prix ? 0 : 2)} TND';

  String get dureeFormatted {
    if (duree < 1) return '${(duree * 60).round()} min';
    return duree == duree.truncateToDouble()
        ? '${duree.toInt()} hour${duree >= 2 ? "s" : ""}'
        : '$duree hours';
  }

  String get languesFormatted => languesDisponibles.join(' / ');
}
