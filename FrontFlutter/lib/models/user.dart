class User {
  final String id;
  final String fullname;
  final String email;
  final String userType; // "Touriste" ou "Organisator"
  final int? age;
  final String? numTel;
  final String? avatar;
  final String? bio;
  final String? paysOrigine;
  final String status;
  final DateTime dateInscription;
  final DateTime? derniereConnexion;
  final bool notificationsEmail;
  final bool notificationsSms;
  final bool consentementDonnees;

  // Tourist specific fields
  final List<String>? centresInteret;
  final String? languePreferee;

  // Organizer specific fields
  final String? nomEntreprise;
  final String? numeroLicence;
  final String? adresseEntreprise;
  final String? siteWeb;
  final List<String>? typesActivites;
  final int? nombreActivites;
  final double? noteMoyenne;
  final int? nombreAvis;
  final List<String>? certifications;
  final List<String>? languesProposees;
  final int? capaciteMoyenne;
  final String? description;

  User({
    required this.id,
    required this.fullname,
    required this.email,
    required this.userType,
    this.age,
    this.numTel,
    this.avatar,
    this.bio,
    this.paysOrigine,
    required this.status,
    required this.dateInscription,
    this.derniereConnexion,
    required this.notificationsEmail,
    required this.notificationsSms,
    required this.consentementDonnees,
    this.centresInteret,
    this.languePreferee,
    this.nomEntreprise,
    this.numeroLicence,
    this.adresseEntreprise,
    this.siteWeb,
    this.typesActivites,
    this.nombreActivites,
    this.noteMoyenne,
    this.nombreAvis,
    this.certifications,
    this.languesProposees,
    this.capaciteMoyenne,
    this.description,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      userType: json['userType'] ?? json['__t'] ?? '',
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
      centresInteret: json['centres_interet'] != null
          ? List<String>.from(json['centres_interet'])
          : null,
      languePreferee: json['langue_preferee'],
      nomEntreprise: json['nom_entreprise'],
      numeroLicence: json['numero_licence'],
      adresseEntreprise: json['adresse_entreprise'],
      siteWeb: json['site_web'],
      typesActivites: json['types_activites'] != null
          ? List<String>.from(json['types_activites'])
          : null,
      nombreActivites: json['nombre_activites'],
      noteMoyenne: json['note_moyenne'] != null
          ? (json['note_moyenne'] as num).toDouble()
          : null,
      nombreAvis: json['nombre_avis'],
      certifications: json['certifications'] != null
          ? List<String>.from(json['certifications'])
          : null,
      languesProposees: json['langues_proposees'] != null
          ? List<String>.from(json['langues_proposees'])
          : null,
      capaciteMoyenne: json['capacite_moyenne'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullname': fullname,
      'email': email,
      'userType': userType,
      'age': age,
      'num_tel': numTel,
      'avatar': avatar,
      'bio': bio,
      'pays_origine': paysOrigine,
      'status': status,
      'date_inscription': dateInscription.toIso8601String(),
      'derniere_connexion': derniereConnexion?.toIso8601String(),
      'notifications_email': notificationsEmail,
      'notifications_sms': notificationsSms,
      'consentement_donnees': consentementDonnees,
      'centres_interet': centresInteret,
      'langue_preferee': languePreferee,
      'nom_entreprise': nomEntreprise,
      'numero_licence': numeroLicence,
      'adresse_entreprise': adresseEntreprise,
      'site_web': siteWeb,
      'types_activites': typesActivites,
      'nombre_activites': nombreActivites,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
      'certifications': certifications,
      'langues_proposees': languesProposees,
      'capacite_moyenne': capaciteMoyenne,
      'description': description,
    };
  }
}
