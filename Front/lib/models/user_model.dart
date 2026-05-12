enum UserStatus { active, suspended, banned, inactive }

class UserModel {
  final String id;
  final String fullname;
  final String? username;
  final String email;
  final String userType; // 'Touriste' | 'Organisator'
  final String? avatar;
  final String? coverPhoto;
  final String? bio;
  final String? numTel;
  final String? paysOrigine;
  final bool isOnline;
  final List<String> centresInteret;
  final String languePreferee;
  final double noteMoyenne;
  final int nombreAvis;
  final bool pushNotifEnabled;
  final bool notificationsEmail;

  const UserModel({
    required this.id,
    required this.fullname,
    this.username,
    required this.email,
    required this.userType,
    this.avatar,
    this.coverPhoto,
    this.bio,
    this.numTel,
    this.paysOrigine,
    this.isOnline = false,
    this.centresInteret = const [],
    this.languePreferee = 'English',
    this.noteMoyenne = 0,
    this.nombreAvis = 0,
    this.pushNotifEnabled = true,
    this.notificationsEmail = true,
  });

  static List<String> _safeStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? '',
      username: json['username'] as String?,
      email: json['email'] ?? '',
      userType: json['userType'] ?? '',
      avatar: json['avatar'] as String?,
      coverPhoto: json['cover_photo'] as String?,
      bio: json['bio'] as String?,
      numTel: json['num_tel'] as String?,
      paysOrigine: json['pays_origine'] as String?,
      isOnline: json['isOnline'] ?? false,
      centresInteret: json['centres_interet'] != null ? List<String>.from(json['centres_interet']) : const [],
      languePreferee: json['langue_preferee'] ?? 'English',
      noteMoyenne: (json['note_moyenne'] ?? 0).toDouble(),
      nombreAvis: json['nombre_avis'] ?? 0,
      pushNotifEnabled: json['push_notif_enabled'] ?? true,
      notificationsEmail: json['notifications_email'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullname': fullname,
      'username': username,
      'email': email,
      'userType': userType,
      'avatar': avatar,
      'cover_photo': coverPhoto,
      'bio': bio,
      'num_tel': numTel,
      'pays_origine': paysOrigine,
      'isOnline': isOnline,
      'centres_interet': centresInteret,
      'langue_preferee': languePreferee,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
      'push_notif_enabled': pushNotifEnabled,
      'notifications_email': notificationsEmail,
    };
  }

  bool get isTouriste => userType == 'Touriste';
  bool get isOrganisator => userType == 'Organisator';
}
