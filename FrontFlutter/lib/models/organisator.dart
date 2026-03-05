import 'user.dart';

class Organisator extends User {
  @override
  final String nomEntreprise;
  @override
  final String? numeroLicence;
  @override
  final String? adresseEntreprise;
  @override
  final String? siteWeb;
  @override
  final List<String> typesActivites;
  @override
  final int nombreActivites;
  @override
  final double noteMoyenne;
  @override
  final int nombreAvis;
  @override
  final List<String> certifications;
  @override
  final List<String> languesProposees;
  @override
  final int? capaciteMoyenne;
  @override
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
    required this.nomEntreprise,
    this.numeroLicence,
    this.adresseEntreprise,
    this.siteWeb,
    required this.typesActivites,
    required this.nombreActivites,
    required this.noteMoyenne,
    required this.nombreAvis,
    required this.certifications,
    required this.languesProposees,
    this.capaciteMoyenne,
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
      nomEntreprise: json['nom_entreprise'] ?? '',
      numeroLicence: json['numero_licence'],
      adresseEntreprise: json['adresse_entreprise'],
      siteWeb: json['site_web'],
      typesActivites: List<String>.from(json['types_activites'] ?? []),
      nombreActivites: json['nombre_activites'] ?? 0,
      noteMoyenne: (json['note_moyenne'] ?? 0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
      certifications: List<String>.from(json['certifications'] ?? []),
      languesProposees: List<String>.from(json['langues_proposees'] ?? []),
      capaciteMoyenne: json['capacite_moyenne'],
      description: json['description'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['nom_entreprise'] = nomEntreprise;
    data['numero_licence'] = numeroLicence;
    data['adresse_entreprise'] = adresseEntreprise;
    data['site_web'] = siteWeb;
    data['types_activites'] = typesActivites;
    data['nombre_activites'] = nombreActivites;
    data['note_moyenne'] = noteMoyenne;
    data['nombre_avis'] = nombreAvis;
    data['certifications'] = certifications;
    data['langues_proposees'] = languesProposees;
    data['capacite_moyenne'] = capaciteMoyenne;
    data['description'] = description;
    return data;
  }
}
