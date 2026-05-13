class LieuModel {
  final String id;
  final String titre;
  final String sousTitre;
  final String description;
  final String address;
  final String city;
  final String country;
  final String imagePortrait;
  final String? imagePaysage;
  final List<String> images;
  final String? telephone;
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
  final List<Map<String, dynamic>> reviews;
  final String? openingHours;
  final String? closingHours;
  final bool? bookingRequired;
  final String? website;
  final bool isBookmarked;
  final int bookmarksCount;

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
    this.address = '',
    this.city = '',
    this.country = '',
    required this.imagePortrait,
    this.imagePaysage,
    required this.images,
    this.telephone,
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
    this.reviews = const [],
    this.openingHours,
    this.closingHours,
    this.bookingRequired,
    this.website,
    this.isBookmarked = false,
    this.bookmarksCount = 0,
  });

  factory LieuModel.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic value) {
      if (value is num) return value;
      if (value is String) {
        return num.tryParse(value.trim());
      }
      return null;
    }

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

    final rawTitre =
        (json['name'] ?? json['titre'] ?? json['title'] ?? json['nom'] ?? '')
            .toString();
    final rawSousTitre =
        (json['short_description'] ??
                json['sousTitre'] ??
                json['subtitle'] ??
                json['sous_titre'] ??
                '')
            .toString()
            .trim()
            .isNotEmpty
        ? (json['short_description'] ??
                  json['sousTitre'] ??
                  json['subtitle'] ??
                  json['sous_titre'])
              .toString()
        : (json['city'] ?? 'Djerba').toString();
    final rawDescription =
        (json['long_description'] ??
                json['description'] ??
                json['desc'] ??
                position?['description'] ??
                '')
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
      images: (json['gallery'] as List? ?? json['images'] as List? ?? [])
          .whereType<String>()
          .toList(growable: false),
      telephone: (json['telephone'] ?? json['phone'])?.toString(),
      noteMoyenne:
          (parseNum(json['rating']) ??
                  parseNum(json['noteMoyenne']) ??
                  parseNum(json['note_moyenne']) ??
                  0)
              .toDouble(),
      nombreAvis:
          (parseNum(json['review_count']) ??
                  parseNum(json['nombreAvis']) ??
                  parseNum(json['nombre_avis']) ??
                  0)
              .toInt(),
      categorie: rawCategorie,
      topDestination: rawTopDestination,
      prix:
          (json['price_range'] as String? ?? json['prix'] as String? ?? 'FREE'),
      latitude:
          (parseNum(coords?['latitude']) ??
                  parseNum(coords?['lat']) ??
                  parseNum(position?['latitude']))
              ?.toDouble(),
      longitude:
          (parseNum(coords?['longitude']) ??
                  parseNum(coords?['lng']) ??
                  parseNum(position?['longitude']) ??
                  parseNum(position?['lng']))
              ?.toDouble(),
      activiteLieeId: activiteId,
      video: json['video'] as String?,
      amenities: (json['amenities'] as List? ?? [])
          .whereType<String>()
          .toList(),
      activities: (json['activities'] as List? ?? [])
          .whereType<String>()
          .toList(),
      openingHours: json['opening_hours'] as String?,
      closingHours: json['closing_hours'] as String?,
      bookingRequired: json['booking_required'] as bool?,
      website: (json['website'] ?? json['site_web'])?.toString(),
      reviews: (json['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false),
    ).copyWith(
      isBookmarked: json['isBookmarked'] == true,
      bookmarksCount: (json['bookmarks_count'] as num?)?.toInt() ?? 0,
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

  // CopyWith method for updating bookmark state
  LieuModel copyWith({
    String? id,
    String? titre,
    String? sousTitre,
    String? description,
    String? imagePortrait,
    String? imagePaysage,
    List<String>? images,
    String? telephone,
    double? noteMoyenne,
    int? nombreAvis,
    String? categorie,
    bool? topDestination,
    String? prix,
    double? latitude,
    double? longitude,
    String? activiteLieeId,
    String? video,
    List<String>? amenities,
    List<String>? activities,
    String? openingHours,
    String? closingHours,
    bool? bookingRequired,
    String? website,
    bool? isBookmarked,
    int? bookmarksCount,
    List<Map<String, dynamic>>? reviews,
  }) {
    return LieuModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      sousTitre: sousTitre ?? this.sousTitre,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      imagePortrait: imagePortrait ?? this.imagePortrait,
      imagePaysage: imagePaysage ?? this.imagePaysage,
      images: images ?? this.images,
      telephone: telephone ?? this.telephone,
      noteMoyenne: noteMoyenne ?? this.noteMoyenne,
      nombreAvis: nombreAvis ?? this.nombreAvis,
      categorie: categorie ?? this.categorie,
      topDestination: topDestination ?? this.topDestination,
      prix: prix ?? this.prix,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      activiteLieeId: activiteLieeId ?? this.activiteLieeId,
      video: video ?? this.video,
      amenities: amenities ?? this.amenities,
      activities: activities ?? this.activities,
      reviews: reviews ?? this.reviews,
      openingHours: openingHours ?? this.openingHours,
      closingHours: closingHours ?? this.closingHours,
      bookingRequired: bookingRequired ?? this.bookingRequired,
      website: website ?? this.website,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
    );
  }
}
