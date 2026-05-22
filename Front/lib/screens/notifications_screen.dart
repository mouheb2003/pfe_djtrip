import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isTab;
  const NotificationsScreen({super.key, this.isTab = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _unreadCount = 0;
  bool _hasMore = true;
  String _selectedType = 'All';

  final List<String> _typeOptions = [
    'All',
    'Push',
    'Normal',
    'Booking',
    'Message',
    'Review',
    'System',
    'Appeal',
    'Activity',
    'Reminder',
    'Follow',
    'Reaction',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();

    // Set up scroll listener for infinite loading
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreNotifications();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _notifications = [];
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

    try {
      String? filterType;

      // Gérer les filtres spéciaux pour Push/Normal
      if (_selectedType == 'Push') {
        filterType = 'push'; // Filtrer par isPush: true
      } else if (_selectedType == 'Normal') {
        filterType = 'normal'; // Filtrer par isPush: false
      } else if (_selectedType == 'All') {
        filterType = null; // Afficher tout
      } else {
        filterType = _selectedType.toLowerCase(); // Types standards
      }

      final result = await NotificationService.getUserNotifications(
        type: filterType,
        limit: 20,
        skip: refresh ? 0 : _notifications.length,
        cacheFirst: false,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _notifications = List<NotificationModel>.from(
              result['notifications'].map((n) => NotificationModel.fromJson(n)),
            );
          } else {
            _notifications.addAll(
              List<NotificationModel>.from(
                result['notifications'].map(
                  (n) => NotificationModel.fromJson(n),
                ),
              ),
            );
          }
          // Client-side descending sort by createdAt to guarantee newest is on top
          _notifications.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          _hasMore = result['pagination']['hasMore'] ?? false;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await NotificationService.getUserNotifications(
        type: _selectedType == 'All' ? null : _selectedType.toLowerCase(),
        limit: 20,
        skip: _notifications.length,
        cacheFirst: false,
      );

      if (mounted) {
        setState(() {
          _notifications.addAll(
            List<NotificationModel>.from(
              result['notifications'].map((n) => NotificationModel.fromJson(n)),
            ),
          );
          // Client-side descending sort by createdAt to guarantee newest is on top
          _notifications.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          _hasMore = result['pagination']['hasMore'] ?? false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more notifications: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await NotificationService.getUnreadCount(
        cacheFirst: false,
      );
      if (mounted) {
        setState(() {
          _unreadCount = result['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    HapticFeedback.lightImpact();

    try {
      final result = await NotificationService.markAsRead(notificationId);

      if (result['success']) {
        setState(() {
          // Update local notification
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            _notifications[index] = NotificationModel(
              id: _notifications[index].id,
              userId: _notifications[index].userId,
              type: _notifications[index].type,
              title: _notifications[index].title,
              message: _notifications[index].message,
              data: _notifications[index].data,
              isRead: true,
              priority: _notifications[index].priority,
              actionUrl: _notifications[index].actionUrl,
              actionText: _notifications[index].actionText,
              createdAt: _notifications[index].createdAt,
              expiresAt: _notifications[index].expiresAt,
              relatedEntityType: _notifications[index].relatedEntityType,
              relatedEntityId: _notifications[index].relatedEntityId,
              targetRole: _notifications[index].targetRole,
            );
          }

          if (_unreadCount > 0) {
            _unreadCount--;
          }
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notification as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.mediumImpact();

    try {
      final result = await NotificationService.markAllAsRead();

      if (result['success']) {
        setState(() {
          // Mark all local notifications as read
          _notifications = _notifications
              .map(
                (notification) => NotificationModel(
                  id: notification.id,
                  userId: notification.userId,
                  type: notification.type,
                  title: notification.title,
                  message: notification.message,
                  data: notification.data,
                  isRead: true,
                  priority: notification.priority,
                  actionUrl: notification.actionUrl,
                  actionText: notification.actionText,
                  createdAt: notification.createdAt,
                  expiresAt: notification.expiresAt,
                  relatedEntityType: notification.relatedEntityType,
                  relatedEntityId: notification.relatedEntityId,
                  targetRole: notification.targetRole,
                ),
              )
              .toList();
          _unreadCount = 0;
        });
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking all notifications as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    HapticFeedback.lightImpact();

    try {
      final result = await NotificationService.deleteNotification(
        notificationId,
      );

      if (result['success']) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notificationId);
          final deletedNotification = _notifications.firstWhere(
            (n) => n.id == notificationId,
            orElse: () => NotificationModel(
              id: '',
              userId: '',
              type: '',
              title: '',
              message: '',
              data: {},
              isRead: false,
              priority: 'medium',
              createdAt: DateTime.now(),
            ),
          );

          if (!deletedNotification.isRead && _unreadCount > 0) {
            _unreadCount--;
          }
        });
      }
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read if unread
    if (notification.isUnread) {
      _markAsRead(notification.id);
    }

    // Navigate to related screen if action URL exists
    if (notification.actionUrl != null) {
      // This would integrate with your navigation system
      print('Navigate to: ${notification.actionUrl}');
      // Example: Navigator.pushNamed(context, notification.actionUrl!);
    }
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isUnread ? const Color(0xFFF0F4FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: notification.isUnread
            ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)
            : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon with custom background
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification.typeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.typeIcon,
                      color: notification.typeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: const Color(0xFF1E225E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  notification.timeAgo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: notification.isUnread
                                        ? AppColors.primary
                                        : const Color(0xFF8A92A6),
                                    fontWeight: notification.isUnread
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteNotification(notification.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: notification.isUnread
                                ? Colors.black87
                                : const Color(0xFF6C757D),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Priority indicator
                  if (notification.isHighPriority)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: notification.priorityColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),

              // Action button
              if (notification.actionText != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 14,
                    left: 52,
                  ), // Align with text
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleNotificationTap(notification),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        notification.actionText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Notifications ($_unreadCount)',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text('Mark all as read'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal scrolling Filter Chips
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _typeOptions.length,
              itemBuilder: (context, index) {
                final type = _typeOptions[index];
                final isSelected = _selectedType == type;

                // Get corresponding premium icon for the type
                IconData getIcon(String t) {
                  switch (t) {
                    case 'All':
                      return Icons.all_inclusive;
                    case 'Push':
                      return Icons.phonelink_ring;
                    case 'Normal':
                      return Icons.storage;
                    case 'Booking':
                      return Icons.calendar_today;
                    case 'Message':
                      return Icons.chat;
                    case 'Review':
                      return Icons.star;
                    case 'System':
                      return Icons.info;
                    case 'Appeal':
                      return Icons.gavel;
                    case 'Activity':
                      return Icons.local_activity;
                    case 'Reminder':
                      return Icons.alarm;
                    case 'Follow':
                      return Icons.person_add;
                    case 'Reaction':
                      return Icons.favorite;
                    default:
                      return Icons.notifications;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedType = type;
                      });
                      _loadNotifications(refresh: true);
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.outline.withOpacity(0.5),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getIcon(type),
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Notifications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Color(0xFF6C757D),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadNotifications(refresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _notifications.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
