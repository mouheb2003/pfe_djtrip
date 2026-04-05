import 'dart:convert';

class ConversationModel {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final String partnerType;
  final bool partnerOnline;
  final String lastMessageContent;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isArchived;

  const ConversationModel({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerType = '',
    this.partnerOnline = false,
    required this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isArchived = false,
  });

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _safeUrl(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return value;
    return '';
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final partner = _asMap(json['partner']);
    final lastMsg = _asMap(json['lastMessage']);

    return ConversationModel(
      partnerId: (partner['_id'] ?? partner['id'] ?? '').toString(),
      partnerName: (partner['fullname'] ?? partner['name'] ?? 'Unknown')
          .toString(),
      partnerAvatar: _safeUrl(partner['avatar']),
      partnerType: (partner['userType'] ?? '').toString(),
      partnerOnline: partner['isOnline'] == true,
      lastMessageContent: (lastMsg['content'] ?? '').toString(),
      lastMessageTime: lastMsg['createdAt'] != null
          ? DateTime.tryParse(lastMsg['createdAt'].toString())
          : null,
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
      isArchived: json['archived'] == true,
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
    bool? isArchived,
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
      isArchived: isArchived ?? this.isArchived,
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
      'archived': isArchived,
    };
  }
}
