class ActivityModel {
  final String id;
  final String titre;
  final String description;
  final String typeActivite;
  final String categorie;
  final String lieu;
  final String? locationType;
  final String? itineraire;
  final List<Map<String, dynamic>>? itineraireSteps;
  final List<Map<String, dynamic>>? itineraireCoords;
  final double duree;
  final double prix;
  final int capaciteMax;
  final int nombreReservations;
  final List<String> photos;
  final List<String> languesDisponibles;
  final List<String> equipementsInclus;
  final List<String> aApporter;
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
  final bool isBookmarked;
  final int bookmarksCount;

  const ActivityModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.typeActivite,
    this.categorie = '',
    required this.lieu,
    this.locationType,
    this.itineraire,
    this.itineraireSteps,
    this.itineraireCoords,
    required this.duree,
    required this.prix,
    required this.capaciteMax,
    this.nombreReservations = 0,
    this.photos = const [],
    this.languesDisponibles = const ['French'],
    this.equipementsInclus = const [],
    this.aApporter = const [],
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
    this.isBookmarked = false,
    this.bookmarksCount = 0,
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

    List<Map<String, dynamic>> parseSteps(dynamic value) {
      if (value is! List) return [];
      return value
          .whereType<Map>()
          .map(
            (step) => step.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    }

    final itineraireValue = json['itineraire'];
    final itinerarySteps = parseSteps(itineraireValue);
    final itineraryText = itineraireValue is String
        ? itineraireValue
        : itinerarySteps.isNotEmpty
        ? itinerarySteps
              .map((step) {
                final title = step['title']?.toString() ?? '';
                final description = step['description']?.toString() ?? '';
                final address = step['address']?.toString() ?? '';
                final parts = <String>[];
                if (title.isNotEmpty) parts.add(title);
                if (description.isNotEmpty) parts.add(description);
                if (address.isNotEmpty) parts.add(address);
                return parts.join(' - ');
              })
              .join('\n')
        : null;

    return ActivityModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      typeActivite: json['type_activite']?.toString() ?? '',
      categorie: json['categorie']?.toString() ?? 'Other',
      lieu: json['lieu']?.toString() ?? '',
      locationType: json['location_type']?.toString(),
      itineraire: itineraryText,
      itineraireSteps: itinerarySteps.isNotEmpty ? itinerarySteps : null,
      itineraireCoords: json['itineraire_coords'] is List
          ? (json['itineraire_coords'] as List)
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList()
          : [],
      duree: toDouble(json['duree']),
      prix: toDouble(json['prix']),
      capaciteMax: nToInt(json['capacite_max']),
      nombreReservations: nToInt(json['nombre_reservations']),
      photos: parseList(json['photos']),
      languesDisponibles: parseList(json['langues_disponibles']).isEmpty
          ? const ['French']
          : parseList(json['langues_disponibles']),
      equipementsInclus: parseList(json['equipements_inclus']),
      aApporter: parseList(json['a_apporter'] ?? json['aApporter']),
      noteMoyenne: toDouble(json['note_moyenne'] ?? json['noteMoyenne']),
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
    ).copyWith(
      isBookmarked: json['isBookmarked'] == true,
      bookmarksCount: (json['bookmarks_count'] as num?)?.toInt() ?? 0,
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

  String get thumbnailUrl => displayPhotos.isNotEmpty ? displayPhotos.first : '';

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

  // Format lieu to show place name instead of coordinates
  String get formattedLieu {
    if (lieu.isEmpty) return 'Location not specified';

    final trimmed = lieu.trim();

    // Strict GPS coordinate pattern: two decimal numbers separated by comma or space
    // Valid coordinates: lat between -90 and 90, lng between -180 and 180
    final coordPattern = RegExp(
      r'^-?(?:90(?:\.0+)?|[1-8]?\d(?:\.\d+)?)\s*,\s*-?(?:180(?:\.0+)?|1[0-7]\d(?:\.\d+)?|[1-9]?\d(?:\.\d+)?)$',
    );

    // Alternative pattern with space separator
    final coordPatternSpace = RegExp(
      r'^-?(?:90(?:\.0+)?|[1-8]?\d(?:\.\d+)?)\s+-?(?:180(?:\.0+)?|1[0-7]\d(?:\.\d+)?|[1-9]?\d(?:\.\d+)?)$',
    );

    // Check if it's clearly GPS coordinates (two numbers with decimals)
    final isCoordinates =
        coordPattern.hasMatch(trimmed) || coordPatternSpace.hasMatch(trimmed);

    if (isCoordinates) {
      // It's GPS coordinates - try to use coordinates map if available
      if (coordonnees != null && coordonnees!.containsKey('name')) {
        final name = coordonnees!['name']?.toString() ?? '';
        if (name.isNotEmpty) return name;
      }
      // If no name available, show the actual coordinates
      return lieu;
    }

    // Not coordinates - return the original value
    return lieu;
  }

  // English getters for compatibility
  String get title => titre;
  String get category => categorie;
  String get location => lieu;
  String get duration => '${duree.toInt()}h';
  double? get price => prix;
  double? get rating => noteMoyenne;
  DateTime get createdDate => createdAt ?? DateTime.now();
  String get imageUrl => displayPhotos.isNotEmpty ? displayPhotos.first : '';

  // Activity timeline status logic
  String get timelineStatus {
    if (statut == 'cancelled') {
      return 'CANCELLED';
    }

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
      if (now.isAfter(endOfDay)) return 'COMPLETED';
      return 'ONGOING';
    }

    // Both start and end dates available
    if (now.isBefore(dateDebut!)) return 'UPCOMING';
    if (now.isAfter(dateFin!)) return 'COMPLETED';
    if (now.isAfter(dateDebut!) && now.isBefore(dateFin!)) return 'ONGOING';

    return 'UNKNOWN';
  }

  bool get isUpcoming => timelineStatus == 'UPCOMING';
  bool get isOngoing => timelineStatus == 'ONGOING';
  bool get isPast => timelineStatus == 'COMPLETED' || statut == 'cancelled';

  // Bookmark functionality
  // bool get isBookmarked => false; // Now using field instead of getter
  // int get bookmarksCount => 0; // Now using field instead of getter

  // CopyWith method for updating bookmark state
  ActivityModel copyWith({
    String? id,
    String? titre,
    String? description,
    String? typeActivite,
    String? categorie,
    String? lieu,
    double? duree,
    double? prix,
    int? capaciteMax,
    int? nombreReservations,
    List<String>? photos,
    List<String>? languesDisponibles,
    List<String>? equipementsInclus,
    List<String>? aApporter,
    double? noteMoyenne,
    int? nombreAvis,
    String? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
    List<DateTime>? datesDisponibles,
    Map<String, dynamic>? organisateur,
    Map<String, dynamic>? coordonnees,
    List<Map<String, dynamic>>? itineraireSteps,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBookmarked,
    int? bookmarksCount,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      typeActivite: typeActivite ?? this.typeActivite,
      categorie: categorie ?? this.categorie,
      lieu: lieu ?? this.lieu,
      duree: duree ?? this.duree,
      prix: prix ?? this.prix,
      capaciteMax: capaciteMax ?? this.capaciteMax,
      nombreReservations: nombreReservations ?? this.nombreReservations,
      photos: photos ?? this.photos,
      languesDisponibles: languesDisponibles ?? this.languesDisponibles,
      equipementsInclus: equipementsInclus ?? this.equipementsInclus,
      aApporter: aApporter ?? this.aApporter,
      noteMoyenne: noteMoyenne ?? this.noteMoyenne,
      nombreAvis: nombreAvis ?? this.nombreAvis,
      statut: statut ?? this.statut,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      datesDisponibles: datesDisponibles ?? this.datesDisponibles,
      organisateur: organisateur ?? this.organisateur,
      coordonnees: coordonnees ?? this.coordonnees,
      itineraireSteps: itineraireSteps ?? this.itineraireSteps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  static List<String> _getDefaultImagesForCategory(String? category) {
    final cat = (category ?? '').trim().toLowerCase();
    switch (cat) {
      case 'guided tour':
      case 'visite guidée':
        return const [
          'https://images.unsplash.com/photo-1590076214565-4f323a6771bb?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1540959733332-eab4deceeaf7?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=800&q=80',
        ];
      case 'excursion':
        return const [
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1506929562872-bb421503ef21?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=800&q=80',
        ];
      case 'hiking':
      case 'randonnée':
        return const [
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1472214222555-d404758b1c42?auto=format&fit=crop&w=800&q=80',
        ];
      case 'adventure':
      case 'aventure':
        return const [
          'https://images.unsplash.com/photo-1539650116574-8efeb43e2750?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1502680390469-be75c86b636f?auto=format&fit=crop&w=800&q=80',
        ];
      case 'culture':
        return const [
          'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1541432901042-2d8bd64b4a9b?auto=format&fit=crop&w=800&q=80',
        ];
      case 'gastronomy':
      case 'gastronomie':
        return const [
          'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=800&q=80',
        ];
      case 'sport':
      case 'sports':
        return const [
          'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1510070112810-d4e9a46d9e91?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=800&q=80',
        ];
      default:
        return const [
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1506929562872-bb421503ef21?auto=format&fit=crop&w=800&q=80',
        ];
    }
  }

  List<String> get displayPhotos {
    final List<String> extractedUrls = [];
    for (final p in photos) {
      final value = p.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        extractedUrls.add(value);
      }
    }
    if (extractedUrls.isEmpty) {
      return _getDefaultImagesForCategory(categorie);
    }
    return extractedUrls;
  }
}
