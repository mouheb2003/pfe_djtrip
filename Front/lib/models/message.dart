class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    String extractId(dynamic field) {
      if (field == null) return '';
      if (field is Map) return (field['_id'] ?? field['\$oid'] ?? '').toString();
      return field.toString();
    }

    return Message(
      id: extractId(json['_id']),
      senderId: extractId(json['sender_id']),
      receiverId: extractId(json['receiver_id']),
      content: json['content'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Conversation {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final String partnerType;
  final Message? lastMessage;
  final int unreadCount;
  final bool isOnline;

  const Conversation({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    required this.partnerType,
    this.lastMessage,
    required this.unreadCount,
    this.isOnline = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    String extractId(dynamic field) {
      if (field == null) return '';
      if (field is Map) return (field['_id'] ?? field['\$oid'] ?? '').toString();
      return field.toString();
    }

    final partner = json['partner'] as Map<String, dynamic>?;
    final lastMsgJson = json['lastMessage'] as Map<String, dynamic>?;
    return Conversation(
      partnerId: extractId(partner?['_id']),
      partnerName: partner?['fullname'] ?? '',
      partnerAvatar: partner?['avatar'] as String?,
      partnerType: partner?['userType'] ?? '',
      lastMessage: lastMsgJson != null ? Message.fromJson(lastMsgJson) : null,
      unreadCount: json['unreadCount'] ?? 0,
      isOnline: partner?['isOnline'] == true,
    );
  }
}
