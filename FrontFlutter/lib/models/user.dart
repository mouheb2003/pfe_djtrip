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
    };
  }
}
