import 'touriste.dart';
import 'organisator.dart';

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
  });

  // Factory qui retourne le bon type (Touriste ou Organisator)
  factory User.fromJson(Map<String, dynamic> json) {
    final userType = json['userType'] ?? json['__t'] ?? '';

    // Import dynamique pour éviter les imports circulaires
    if (userType == 'Touriste') {
      // Retourner un Touriste
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
    } else if (userType == 'Organisator') {
      // Retourner un Organisator
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
    } else {
      // Base User (ne devrait pas arriver)
      return User(
        id: json['_id'] ?? '',
        fullname: json['fullname'] ?? '',
        email: json['email'] ?? '',
        userType: userType,
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
      );
    }
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
    };
  }
}
