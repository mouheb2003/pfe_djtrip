import 'user.dart';

class Organisator extends User {
  final String nomEntreprise;
  final String? numeroLicence;
  final String? adresseEntreprise;
  final String? siteWeb;
  final List<String> specialites;
  final double noteMoyenne;
  final int nombreAvis;
  final List<String> certifications;

  Organisator({
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
    required this.nomEntreprise,
    this.numeroLicence,
    this.adresseEntreprise,
    this.siteWeb,
    required this.specialites,
    required this.noteMoyenne,
    required this.nombreAvis,
    required this.certifications,
  }) : super(
         id: id,
         fullname: fullname,
         email: email,
         userType: 'Organisator',
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
      nomEntreprise: json['nom_entreprise'] ?? '',
      numeroLicence: json['numero_licence'],
      adresseEntreprise: json['adresse_entreprise'],
      siteWeb: json['site_web'],
      specialites: List<String>.from(json['specialites'] ?? []),
      noteMoyenne: (json['note_moyenne'] ?? 0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
      certifications: List<String>.from(json['certifications'] ?? []),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['nom_entreprise'] = nomEntreprise;
    data['numero_licence'] = numeroLicence;
    data['adresse_entreprise'] = adresseEntreprise;
    data['site_web'] = siteWeb;
    data['specialites'] = specialites;
    data['note_moyenne'] = noteMoyenne;
    data['nombre_avis'] = nombreAvis;
    data['certifications'] = certifications;
    return data;
  }
}
