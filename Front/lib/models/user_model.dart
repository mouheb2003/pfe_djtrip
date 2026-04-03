class UserModel {
  final String id;
  final String fullname;
  final String email;
  final String userType; // 'Touriste' | 'Organisator'
  final String? avatar;
  final String? bio;
  final String? numTel;
  final String? paysOrigine;
  final bool isOnline;
  final List<String> centresInteret;
  final String languePreferee;
  final double noteMoyenne;
  final int nombreAvis;

  const UserModel({
    required this.id,
    required this.fullname,
    required this.email,
    required this.userType,
    this.avatar,
    this.bio,
    this.numTel,
    this.paysOrigine,
    this.isOnline = false,
    this.centresInteret = const [],
    this.languePreferee = 'English',
    this.noteMoyenne = 0,
    this.nombreAvis = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      userType: json['userType'] ?? '',
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      numTel: json['num_tel'] as String?,
      paysOrigine: json['pays_origine'] as String?,
      isOnline: json['isOnline'] == true,
      centresInteret: List<String>.from(json['centres_interet'] as List? ?? []),
      languePreferee: json['langue_preferee'] as String? ?? 'English',
      noteMoyenne: (json['note_moyenne'] as num? ?? 0).toDouble(),
      nombreAvis:
          (json['nombre_avis'] as num? ?? json['nombreAvis'] as num? ?? 0)
              .toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullname': fullname,
      'email': email,
      'userType': userType,
      'avatar': avatar,
      'bio': bio,
      'num_tel': numTel,
      'pays_origine': paysOrigine,
      'isOnline': isOnline,
      'centres_interet': centresInteret,
      'langue_preferee': languePreferee,
      'note_moyenne': noteMoyenne,
      'nombre_avis': nombreAvis,
    };
  }

  bool get isTouriste => userType == 'Touriste';
  bool get isOrganisator => userType == 'Organisator';
}
