import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/notification_service.dart';
import '../../../theme/app_theme.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final bool isTab;
  const NotificationHistoryScreen({super.key, this.isTab = false});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      print('🔍 Loading notifications... (isRefresh: $isRefresh)');
      final result = await NotificationService.getUserNotifications(limit: 100, cacheFirst: false);
      print('✅ Notifications result: ${result['success']}, count: ${(result['notifications'] as List?)?.length ?? 0}');
      final unreadResult = await NotificationService.getUnreadCount(cacheFirst: false);
      print('✅ Unread count: ${unreadResult['unread_count']}');

      if (mounted) {
        setState(() {
          _notifications = (result['notifications'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          // Client-side descending sort by createdAt to guarantee newest is on top
          _notifications.sort((a, b) {
            final aTimeStr = a['createdAt'] ?? a['created_at'];
            final bTimeStr = b['createdAt'] ?? b['created_at'];
            final aTime = DateTime.tryParse(aTimeStr?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(bTimeStr?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          _unreadCount = unreadResult['unread_count'] as int? ?? 0;
          _isLoading = false;
        });
        print('✅ Loaded ${_notifications.length} notifications');
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final result = await NotificationService.markAsRead(notificationId);
    if (result['success'] == true) {
      await _loadNotifications(isRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final result = await NotificationService.markAllAsRead();
    if (result['success'] == true) {
      await _loadNotifications(isRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await NotificationService.deleteNotification(notificationId);
    if (result['success'] == true) {
      await _loadNotifications(isRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'booking':
        return Icons.bookmark;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'review':
        return Icons.star;
      case 'activity':
        return Icons.event;
      case 'system':
        return Icons.info;
      case 'appeal':
        return Icons.report;
      case 'reminder':
        return Icons.alarm;
      case 'follow':
        return Icons.person_add;
      case 'payment':
        return Icons.payment;
      case 'profile':
        return Icons.account_circle;
      case 'publication':
        return Icons.article;
      case 'reaction':
        return Icons.thumb_up;
      case 'comment':
        return Icons.comment;
      case 'reply':
        return Icons.reply;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'booking':
        return const Color(0xFF4B63FF);
      case 'message':
        return const Color(0xFF10B981);
      case 'review':
        return const Color(0xFFF59E0B);
      case 'activity':
        return const Color(0xFF8B5CF6);
      case 'system':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF4B63FF);
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all as read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(isRefresh: true),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isUnread = notification['is_read'] == false;
                      final type = notification['type'] as String?;
                      final title = notification['title'] as String? ?? '';
                      final message = notification['message'] as String? ?? '';
                      final createdAt = notification['created_at'] as String?;
                      final notificationId = (notification['_id'] ?? notification['id'] ?? '').toString();

                      return InkWell(
                        onTap: () {
                          if (isUnread) {
                            _markAsRead(notificationId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: isUnread ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _getNotificationColor(type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _getNotificationIcon(type),
                                  color: _getNotificationColor(type),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_horiz,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'mark_read':
                                                _markAsRead(notificationId);
                                                break;
                                              case 'delete':
                                                _deleteNotification(notificationId);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            if (isUnread)
                                              const PopupMenuItem(
                                                value: 'mark_read',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.mark_email_read, size: 18),
                                                    SizedBox(width: 12),
                                                    Text('Mark as read'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18),
                                                  SizedBox(width: 12),
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
