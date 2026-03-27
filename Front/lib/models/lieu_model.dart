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
  });

  factory LieuModel.fromJson(Map<String, dynamic> json) {
    final coords = (json['coordonnees'] ??
        json['coordinates'] ??
        json['location']) as Map<String, dynamic>?;
    final activiteLiee = json['activiteLiee'] ?? json['activity_id'];
    String? activiteId;
    if (activiteLiee is String) activiteId = activiteLiee;
    if (activiteLiee is Map<String, dynamic>) {
      activiteId = activiteLiee['_id'] as String?;
    }

    final rawTitre = (json['titre'] ?? json['title'] ?? '').toString();
    final rawSousTitre =
        (json['sousTitre'] ?? json['subtitle'] ?? json['sous_titre'] ?? '')
            .toString();
    final rawDescription =
        (json['description'] ?? json['desc'] ?? '').toString();
    final rawImagePortrait =
        (json['imagePortrait'] ?? json['image'] ?? '').toString();
    final rawCategorie =
        (json['categorie'] ?? json['category'] ?? 'Other').toString();
    final rawTopDestination =
        json['topDestination'] == true || json['top_destination'] == true;

    return LieuModel(
      id: json['_id'] as String? ?? '',
      titre: rawTitre,
      sousTitre: rawSousTitre,
      description: rawDescription,
      imagePortrait: rawImagePortrait,
      imagePaysage: json['imagePaysage'] as String?,
      images: (json['images'] as List? ?? [])
          .whereType<String>()
          .toList(growable: false),
      noteMoyenne:
          (json['noteMoyenne'] as num? ?? json['note_moyenne'] as num? ?? 0)
              .toDouble(),
      nombreAvis:
          (json['nombreAvis'] as num? ?? json['nombre_avis'] as num? ?? 0)
              .toInt(),
      categorie: rawCategorie,
      topDestination: rawTopDestination,
      prix: json['prix'] as String? ?? 'FREE',
      latitude: (coords?['latitude'] as num? ?? coords?['lat'] as num?)
          ?.toDouble(),
      longitude: (coords?['longitude'] as num? ?? coords?['lng'] as num?)
          ?.toDouble(),
      activiteLieeId: activiteId,
    );
  }

  String get displayImage {
    if (imagePortrait.isNotEmpty) return imagePortrait;
    if (imagePaysage != null && imagePaysage!.isNotEmpty) return imagePaysage!;
    if (images.isNotEmpty) return images.first;
    return '';
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
