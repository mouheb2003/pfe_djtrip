class LieuModel {
  final String id;
  final String titre;
  final String sousTitre;
  final String description;
  final String imagePortrait;
  final String? imagePaysage;
  final List<String> images;
  final double noteMoyenne;
  final int nombreAvis;
  final String categorie;
  final bool topDestination;
  final String prix;
  final double? latitude;
  final double? longitude;
  final String? activiteLieeId;
  final String? video;
  final List<String> amenities;
  final List<String> activities;
  final String? openingHours;
  final String? closingHours;
  final bool? bookingRequired;

  String get displayImage {
    if (imagePortrait.isNotEmpty) return imagePortrait;
    if (images.isNotEmpty) return images.first;
    return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80';
  }

  const LieuModel({
    required this.id,
    required this.titre,
    required this.sousTitre,
    required this.description,
    required this.imagePortrait,
    this.imagePaysage,
    required this.images,
    required this.noteMoyenne,
    required this.nombreAvis,
    required this.categorie,
    required this.topDestination,
    required this.prix,
    this.latitude,
    this.longitude,
    this.activiteLieeId,
    this.video,
    this.amenities = const [],
    this.activities = const [],
    this.openingHours,
    this.closingHours,
    this.bookingRequired,
  });

  factory LieuModel.fromJson(Map<String, dynamic> json) {
    final coords =
        (json['coordonnees'] ?? json['coordinates'] ?? json['location'])
            as Map<String, dynamic>?;
    final position = json['position'] as Map<String, dynamic>?;
    final activiteLiee = json['activiteLiee'] ?? json['activity_id'];
    String? activiteId;
    if (activiteLiee is String) activiteId = activiteLiee;
    if (activiteLiee is Map<String, dynamic>) {
      activiteId = activiteLiee['_id'] as String?;
    }

    final rawTitre = (json['name'] ?? json['titre'] ?? json['title'] ?? json['nom'] ?? '')
        .toString();
    final rawSousTitre =
        (json['short_description'] ?? json['sousTitre'] ?? json['subtitle'] ?? json['sous_titre'] ?? '')
            .toString()
            .trim()
            .isNotEmpty
        ? (json['short_description'] ?? json['sousTitre'] ?? json['subtitle'] ?? json['sous_titre'])
              .toString()
        : (json['city'] ?? 'Djerba').toString();
    final rawDescription =
        (json['long_description'] ?? json['description'] ?? json['desc'] ?? position?['description'] ?? '')
            .toString();
    final rawImagePortrait =
        (json['main_image'] ??
                json['imagePortrait'] ??
                json['image'] ??
                (json['gallery'] as List?)
                    ?.whereType<String>()
                    .cast<String?>()
                    .firstWhere(
                      (value) => value != null && value.isNotEmpty,
                      orElse: () => null,
                    ) ??
                '')
            .toString();
    final rawCategorie = _normalizeCategory(
      (json['type'] ?? json['categorie'] ?? json['category'] ?? 'Other')
          .toString(),
    );
    final rawTopDestination =
        json['topDestination'] == true || json['top_destination'] == true;

    return LieuModel(
      id: json['_id'] as String? ?? '',
      titre: rawTitre,
      sousTitre: rawSousTitre,
      description: rawDescription,
      imagePortrait: rawImagePortrait,
      imagePaysage: json['imagePaysage'] as String?,
      images: (json['gallery'] as List? ?? json['images'] as List? ?? []).whereType<String>().toList(
        growable: false,
      ),
      noteMoyenne:
          (json['rating'] as num? ?? json['noteMoyenne'] as num? ?? json['note_moyenne'] as num? ?? 0)
              .toDouble(),
      nombreAvis:
          (json['review_count'] as num? ?? json['nombreAvis'] as num? ?? json['nombre_avis'] as num? ?? 0)
              .toInt(),
      categorie: rawCategorie,
      topDestination: rawTopDestination,
      prix: (json['price_range'] as String? ?? json['prix'] as String? ?? 'FREE'),
      latitude:
          (coords?['latitude'] as num? ??
                  coords?['lat'] as num? ??
                  position?['latitude'] as num?)
              ?.toDouble(),
      longitude:
          (coords?['longitude'] as num? ??
                  coords?['lng'] as num? ??
                  position?['longitude'] as num? ??
                  position?['lng'] as num?)
              ?.toDouble(),
      activiteLieeId: activiteId,
      video: json['video'] as String?,
      amenities: (json['amenities'] as List? ?? []).whereType<String>().toList(),
      activities: (json['activities'] as List? ?? []).whereType<String>().toList(),
      openingHours: json['opening_hours'] as String?,
      closingHours: json['closing_hours'] as String?,
      bookingRequired: json['booking_required'] as bool?,
    );
  }

  static String _normalizeCategory(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('heberg')) return 'Hotels';
    if (value.contains('rest') || value.contains('food')) return 'Restaurants';
    if (value.contains('activ')) return 'Activities';
    if (value.contains('nature')) return 'Nature';
    if (value.contains('museum')) return 'Museums';
    if (value.contains('village') || value.contains('histor'))
      return 'Villages';
    if (value.contains('beach') || value.contains('plage')) return 'Beaches';
    return raw;
  }

  
  String get categoryLabelFr {
    switch (categorie) {
      case 'Beaches':
        return 'Plages';
      case 'Museums':
        return 'Musees';
      case 'Villages':
        return 'Villages';
      case 'Nature':
        return 'Nature';
      default:
        return 'Autres';
    }
  }

  /// English category label for UI.
  String get categoryLabelEn {
    switch (categorie) {
      case 'Beaches':
        return 'Beaches';
      case 'Museums':
        return 'Museums';
      case 'Villages':
        return 'Villages';
      case 'Nature':
        return 'Nature';
      default:
        return 'Other';
    }
  }
}
