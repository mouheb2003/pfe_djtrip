import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final String priority;
  final String? actionUrl;
  final String? actionText;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? targetRole;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    required this.priority,
    this.actionUrl,
    this.actionText,
    required this.createdAt,
    this.expiresAt,
    this.relatedEntityType,
    this.relatedEntityId,
    this.targetRole,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      isRead: json['is_read'] ?? false,
      priority: json['priority']?.toString() ?? 'medium',
      actionUrl: json['action_url']?.toString(),
      actionText: json['action_text']?.toString(),
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      relatedEntityType: json['related_entity_type']?.toString(),
      relatedEntityId: json['related_entity_id']?.toString(),
      targetRole: json['target_role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'is_read': isRead,
      'priority': priority,
      'action_url': actionUrl,
      'action_text': actionText,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'target_role': targetRole,
    };
  }

  // Helper getters
  bool get isUnread => !isRead;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  bool get isLowPriority => priority == 'low';

  String get typeDisplay {
    switch (type) {
      case 'booking':
        return 'Booking';
      case 'message':
        return 'Message';
      case 'review':
        return 'Review';
      case 'system':
        return 'System';
      case 'appeal':
        return 'Appeal';
      case 'activity':
        return 'Activity';
      case 'reminder':
        return 'Reminder';
      case 'follow':
        return 'Follow';
      case 'payment':
        return 'Payment';
      case 'profile':
        return 'Profile';
      case 'reaction':
        return 'Reaction';
      case 'comment':
        return 'Comment';
      case 'reply':
        return 'Reply';
      default:
        return type;
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFDC3545); // Red
      case 'high':
        return const Color(0xFFFFA502); // Orange
      case 'medium':
        return const Color(0xFF3498DB); // Blue
      case 'low':
        return const Color(0xFF6C757D); // Gray
      default:
        return const Color(0xFF6C757D); // Gray
    }
  }

  Color get typeColor {
    switch (type) {
      case 'booking':
        return const Color(0xFF4B63FF); // Blue
      case 'message':
        return const Color(0xFF00B894); // Green
      case 'review':
        return const Color(0xFF9B59B6); // Purple
      case 'system':
        return const Color(0xFF6C757D); // Gray
      case 'appeal':
        return const Color(0xFFE74C3C); // Orange
      case 'activity':
        return const Color(0xFFF39C12); // Yellow
      case 'reminder':
        return const Color(0xFF00B894); // Green
      case 'follow':
        return const Color(0xFF17A2B8); // Indigo
      case 'payment':
        return const Color(0xFF28A745); // Green
      case 'profile':
        return const Color(0xFF6F42C1); // Pink
      case 'reaction':
        return const Color(0xFFE91E63); // Pink/Red for reactions
      case 'comment':
        return const Color(0xFF2196F3); // Blue for comments
      case 'reply':
        return const Color(0xFF00BCD4); // Cyan for replies
      default:
        return const Color(0xFF6C757D); // Gray
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'booking':
        return Icons.event;
      case 'message':
        return Icons.message;
      case 'review':
        return Icons.star;
      case 'system':
        return Icons.notifications;
      case 'appeal':
        return Icons.gavel;
      case 'activity':
        return Icons.event_available;
      case 'reminder':
        return Icons.alarm;
      case 'follow':
        return Icons.person_add;
      case 'payment':
        return Icons.payment;
      case 'profile':
        return Icons.person;
      case 'reaction':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'reply':
        return Icons.reply;
      default:
        return Icons.notifications;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper to check if notification should be shown
  bool get shouldBeShown {
    if (isExpired) return false;
    return true;
  }

  // Helper to get action data
  Map<String, dynamic>? get actionData {
    if (actionUrl != null && relatedEntityId != null) {
      return {
        'url': actionUrl,
        'entityId': relatedEntityId,
        'entityType': relatedEntityType,
        'text': actionText,
      };
    }
    return null;
  }
}
