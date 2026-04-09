class AppealModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String message;
  final String status;
  final String? adminResponse;
  final String? adminId;
  final String? adminName;
  final List<String> attachments;
  final AppealMetadata? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppealModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.message,
    required this.status,
    this.adminResponse,
    this.adminId,
    this.adminName,
    this.attachments = const [],
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppealModel.fromJson(Map<String, dynamic> json) {
    final user = json['user_id'] is Map<String, dynamic>
        ? json['user_id'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AppealModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: user['_id']?.toString() ?? user['id']?.toString() ?? '',
      userName: user['fullname']?.toString() ?? 'Unknown User',
      userEmail: user['email']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      adminResponse: json['admin_response']?.toString(),
      adminId: json['admin_id']?['_id']?.toString() ?? json['admin_id']?.toString(),
      adminName: json['admin_id']?['fullname']?.toString(),
      attachments: json['attachments'] != null 
          ? List<String>.from(json['attachments'])
          : [],
      metadata: json['metadata'] != null 
          ? AppealMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user_id': {
        '_id': userId,
        'fullname': userName,
        'email': userEmail,
      },
      'subject': subject,
      'message': message,
      'status': status,
      'admin_response': adminResponse,
      'admin_id': adminId != null ? {'_id': adminId} : null,
      'attachments': attachments,
      'metadata': metadata?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isReviewed => status == 'reviewed';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'reviewed':
        return 'Under Review';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  String get statusColor {
    switch (status) {
      case 'pending':
        return '#FFA502'; // Orange
      case 'reviewed':
        return '#3498DB'; // Blue
      case 'accepted':
        return '#00B894'; // Green
      case 'rejected':
        return '#FF4757'; // Red
      default:
        return '#6C757D'; // Gray
    }
  }
}

class AppealMetadata {
  final String? userAccountStatus;
  final String? originalBanReason;
  final String? originalSuspensionReason;
  final String? ipAddress;
  final String? userAgent;

  const AppealMetadata({
    this.userAccountStatus,
    this.originalBanReason,
    this.originalSuspensionReason,
    this.ipAddress,
    this.userAgent,
  });

  factory AppealMetadata.fromJson(Map<String, dynamic> json) {
    return AppealMetadata(
      userAccountStatus: json['user_account_status']?.toString(),
      originalBanReason: json['original_ban_reason']?.toString(),
      originalSuspensionReason: json['original_suspension_reason']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_account_status': userAccountStatus,
      'original_ban_reason': originalBanReason,
      'original_suspension_reason': originalSuspensionReason,
      'ip_address': ipAddress,
      'user_agent': userAgent,
    };
  }
}
