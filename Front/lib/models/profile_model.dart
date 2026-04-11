class ProfileModel {
  final String id;
  final String fullname;
  final String email;
  final String? phone;
  final String? avatar;
  final String userType;
  final String? bio;
  final DateTime? birthDate;
  final String? location;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.fullname,
    required this.email,
    this.phone,
    this.avatar,
    required this.userType,
    this.bio,
    this.birthDate,
    this.location,
    required this.preferences,
    required this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      userType: json['userType']?.toString() ?? json['user_type']?.toString() ?? 'tourist',
      bio: json['bio']?.toString(),
      birthDate: json['birthDate'] != null 
          ? DateTime.tryParse(json['birthDate'].toString())
          : null,
      location: json['location']?.toString(),
      preferences: json['preferences'] is Map<String, dynamic>
          ? json['preferences'] as Map<String, dynamic>
          : {},
      stats: json['stats'] is Map<String, dynamic>
          ? json['stats'] as Map<String, dynamic>
          : {},
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'userType': userType,
      'bio': bio,
      'birthDate': birthDate?.toIso8601String(),
      'location': location,
      'preferences': preferences,
      'stats': stats,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  String get displayName => fullname.isNotEmpty ? fullname : email;
  String get initials {
    final names = fullname.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return fullname.isNotEmpty ? fullname[0].toUpperCase() : email[0].toUpperCase();
  }
  
  bool get isTourist => userType == 'tourist';
  bool get isOrganizer => userType == 'organizer';
  bool get isBusiness => userType == 'business';
  
  String get formattedBirthDate {
    if (birthDate == null) return 'Not set';
    return '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}';
  }
  
  String get memberSince {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
