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
  final List<DateTime> datesDisponibles;
  final Map<String, dynamic>? organisateur;
  final Map<String, dynamic>? coordonnees;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.datesDisponibles = const [],
    this.organisateur,
    this.coordonnees,
    this.createdAt,
    this.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int nToInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<String> parseList(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        final List<String> result = [];
        for (final item in v) {
          final s = item?.toString() ?? '';
          if (s.startsWith('[') && s.endsWith(']')) {
            result.addAll(parseList(s));
          } else {
            if (s.isNotEmpty) result.add(s);
          }
        }
        return result;
      }
      if (v is String) {
        final s = v.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          // It's a string looking like a JSON array, e.g. '["item1", "item2"]'
          try {
            final content = s.substring(1, s.length - 1);
            if (content.isEmpty) return [];
            return content
                .split(',')
                .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((e) => e.isNotEmpty)
                .toList();
          } catch (_) {
            return [s];
          }
        }
        return s.isNotEmpty ? [s] : [];
      }
      return [];
    }

    return ActivityModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      typeActivite: json['type_activite']?.toString() ?? '',
      categorie: json['categorie']?.toString() ?? 'Other',
      lieu: json['lieu']?.toString() ?? '',
      duree: toDouble(json['duree']),
      prix: toDouble(json['prix']),
      capaciteMax: nToInt(json['capacite_max']),
      nombreReservations: nToInt(json['nombre_reservations']),
      photos: parseList(json['photos']),
      languesDisponibles: parseList(json['langues_disponibles']).isEmpty
          ? const ['French']
          : parseList(json['langues_disponibles']),
      equipementsInclus: parseList(json['equipements_inclus']),
      aApporter: parseList(json['a_apporter']),
      niveauDifficulte: json['niveau_difficulte']?.toString() ?? 'Moderate',
      noteMoyenne: toDouble(json['note_moyenne']),
      nombreAvis: nToInt(json['nombre_avis']),
      statut: json['statut']?.toString() ?? 'active',
      dateDebut: json['date_debut'] != null
          ? DateTime.tryParse(json['date_debut'].toString())
          : null,
      dateFin: json['date_fin'] != null
          ? DateTime.tryParse(json['date_fin'].toString())
          : null,
      datesDisponibles: (json['dates_disponibles'] is List)
          ? (json['dates_disponibles'] as List)
                .map((e) => DateTime.tryParse(e.toString()))
                .whereType<DateTime>()
                .toList()
          : const [],
      organisateur: json['organisateur_id'] is Map<String, dynamic>
          ? json['organisateur_id'] as Map<String, dynamic>
          : null,
      coordonnees: json['coordonnees'] is Map<String, dynamic>
          ? json['coordonnees'] as Map<String, dynamic>
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
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
      'dates_disponibles': datesDisponibles
          .map((d) => d.toIso8601String())
          .toList(),
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
      'organisateur_id': organisateur,
      'coordonnees': coordonnees,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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

  // Activity timeline status logic
  String get timelineStatus {
    final now = DateTime.now();

    if (dateDebut == null) {
      return 'UNKNOWN';
    }

    if (dateFin == null) {
      // If only start date, consider it single day activity
      final startOfDay = DateTime(
        dateDebut!.year,
        dateDebut!.month,
        dateDebut!.day,
      );
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));

      if (now.isBefore(startOfDay)) return 'UPCOMING';
      if (now.isAfter(endOfDay)) return 'PAST';
      return 'ONGOING';
    }

    // Both start and end dates available
    if (now.isBefore(dateDebut!)) return 'UPCOMING';
    if (now.isAfter(dateFin!)) return 'PAST';
    if (now.isAfter(dateDebut!) && now.isBefore(dateFin!)) return 'ONGOING';

    return 'UNKNOWN';
  }

  bool get isUpcoming => timelineStatus == 'UPCOMING';
  bool get isOngoing => timelineStatus == 'ONGOING';
  bool get isPast => timelineStatus == 'PAST';
}
