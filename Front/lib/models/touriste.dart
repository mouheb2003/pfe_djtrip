import 'user.dart';

class Touriste extends User {
  final List<String> centresInteret;
  final String languePreferee;

  Touriste({
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
    required this.centresInteret,
    required this.languePreferee,
  }) : super(userType: 'Touriste');

  factory Touriste.fromJson(Map<String, dynamic> json) {
    return Touriste(
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
      centresInteret: List<String>.from(json['centres_interet'] ?? []),
      languePreferee: json['langue_preferee'] ?? 'Français',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['centres_interet'] = centresInteret;
    data['langue_preferee'] = languePreferee;
    return data;
  }
}
