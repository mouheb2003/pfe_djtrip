import 'user.dart';

class Organisator extends User {
  final List<String> typesActivites;
  final List<String> listeActivites; // IDs des activités créées
  final List<String> languesProposees;
  final double noteMoyenne;
  final int nombreAvis;
  final String? description;

  Organisator({
    required super.id,
    required super.fullname,
    required super.email,
    super.age,
    super.numTel,
    super.avatar,
    super.bio,
    super.paysOrigine,
    required super.status,
    required super.dateInscription,
    super.derniereConnexion,
    required super.notificationsEmail,
    required super.notificationsSms,
    required super.consentementDonnees,
    required this.typesActivites,
    required this.listeActivites,
    required this.languesProposees,
    required this.noteMoyenne,
    required this.nombreAvis,
    this.description,
  }) : super(userType: 'Organisator');

  factory Organisator.fromJson(Map<String, dynamic> json) {
    return Organisator(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      age: json['age'],
      numTel: json['num_tel'],
      avatar: json['avatar'],
      bio: json['bio'],
      paysOrigine: json['pays_origine'],
      status: json['status'] ?? 'actif',
      dateInscription: DateTime.parse(
        json['date_inscription'] ?? DateTime.now().toIso8601String(),
      ),
      derniereConnexion: json['derniere_connexion'] != null
          ? DateTime.parse(json['derniere_connexion'])
          : null,
      notificationsEmail: json['notifications_email'] ?? true,
      notificationsSms: json['notifications_sms'] ?? false,
      consentementDonnees: json['consentement_donnees'] ?? false,
      typesActivites: List<String>.from(json['types_activites'] ?? []),
      listeActivites: List<String>.from(json['liste_activites'] ?? []),
      languesProposees: List<String>.from(json['langues_proposees'] ?? []),
      noteMoyenne: (json['note_moyenne'] ?? 0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
      description: json['description'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['types_activites'] = typesActivites;
    data['liste_activites'] = listeActivites;
    data['langues_proposees'] = languesProposees;
    data['note_moyenne'] = noteMoyenne;
    data['nombre_avis'] = nombreAvis;
    data['description'] = description;
    return data;
  }
}
