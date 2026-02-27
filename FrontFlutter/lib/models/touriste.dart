import 'user.dart';

class Touriste extends User {
  final List<String> centresInteret;
  final String languePreferee;

  Touriste({
    required String id,
    required String fullname,
    required String email,
    int? age,
    String? numTel,
    String? avatar,
    String? bio,
    String? paysOrigine,
    required String status,
    required DateTime dateInscription,
    DateTime? derniereConnexion,
    required bool notificationsEmail,
    required bool notificationsSms,
    required bool consentementDonnees,
    required this.centresInteret,
    required this.languePreferee,
  }) : super(
         id: id,
         fullname: fullname,
         email: email,
         userType: 'Touriste',
         age: age,
         numTel: numTel,
         avatar: avatar,
         bio: bio,
         paysOrigine: paysOrigine,
         status: status,
         dateInscription: dateInscription,
         derniereConnexion: derniereConnexion,
         notificationsEmail: notificationsEmail,
         notificationsSms: notificationsSms,
         consentementDonnees: consentementDonnees,
       );

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
