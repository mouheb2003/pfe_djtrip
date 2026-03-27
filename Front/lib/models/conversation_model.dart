class ConversationModel {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final String partnerType;
  final bool partnerOnline;
  final String lastMessageContent;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const ConversationModel({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerType = '',
    this.partnerOnline = false,
    required this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>? ?? {};
    final lastMsg = json['lastMessage'] as Map<String, dynamic>? ?? {};

    return ConversationModel(
      partnerId: partner['_id'] as String? ?? '',
      partnerName: partner['fullname'] as String? ?? 'Unknown',
      partnerAvatar: partner['avatar'] as String?,
      partnerType: partner['userType'] as String? ?? '',
      partnerOnline: partner['isOnline'] == true,
      lastMessageContent: lastMsg['content'] as String? ?? '',
      lastMessageTime: lastMsg['createdAt'] != null
          ? DateTime.tryParse(lastMsg['createdAt'])
          : null,
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
    );
  }

  String get timeLabel {
    if (lastMessageTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastMessageTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d';
  }

  ConversationModel copyWith({
    bool? partnerOnline,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return ConversationModel(
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatar: partnerAvatar,
      partnerType: partnerType,
      partnerOnline: partnerOnline ?? this.partnerOnline,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerAvatar': partnerAvatar,
      'partnerType': partnerType,
      'partnerOnline': partnerOnline,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
