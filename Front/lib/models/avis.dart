class Avis {
  final String id;
  final String touristeId;
  final String? touristeFullname;
  final String? touristeAvatar;
  final String? activiteId;
  final String? organisateurId;
  final String type; // 'activite' | 'organisateur'
  final double note;
  final String? commentaire;
  final DateTime createdAt;

  Avis({
    required this.id,
    required this.touristeId,
    this.touristeFullname,
    this.touristeAvatar,
    this.activiteId,
    this.organisateurId,
    required this.type,
    required this.note,
    this.commentaire,
    required this.createdAt,
  });

  factory Avis.fromJson(Map<String, dynamic> json) {
    String touristeId = '';
    String? touristeFullname;
    String? touristeAvatar;

    if (json['touriste_id'] is String) {
      touristeId = json['touriste_id'];
    } else if (json['touriste_id'] is Map) {
      touristeId = json['touriste_id']['_id'] ?? '';
      touristeFullname = json['touriste_id']['fullname'];
      touristeAvatar = json['touriste_id']['avatar'];
    }

    String? activiteId;
    if (json['activite_id'] is String) {
      activiteId = json['activite_id'];
    } else if (json['activite_id'] is Map) {
      activiteId = json['activite_id']['_id'];
    }

    String? organisateurId;
    if (json['organisateur_id'] is String) {
      organisateurId = json['organisateur_id'];
    } else if (json['organisateur_id'] is Map) {
      organisateurId = json['organisateur_id']['_id'];
    }

    return Avis(
      id: json['_id'] ?? '',
      touristeId: touristeId,
      touristeFullname: touristeFullname,
      touristeAvatar: touristeAvatar,
      activiteId: activiteId,
      organisateurId: organisateurId,
      type: json['type'] ?? 'activite',
      note: (json['note'] ?? 0).toDouble(),
      commentaire: json['commentaire'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
