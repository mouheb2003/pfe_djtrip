import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

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
    'Booking',
    'Message',
    'Review',
    'System',
    'Appeal',
    'Activity',
    'Reminder',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
    
    // Set up scroll listener for infinite loading
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
      final result = await NotificationService.getUserNotifications(
        type: _selectedType == 'All' ? null : _selectedType.toLowerCase(),
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
            _notifications.addAll(List<NotificationModel>.from(
              result['notifications'].map((n) => NotificationModel.fromJson(n)),
            ));
          }
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
          _notifications.addAll(List<NotificationModel>.from(
            result['notifications'].map((n) => NotificationModel.fromJson(n)),
          ));
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
      final result = await NotificationService.getUnreadCount(cacheFirst: false);
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
          final index = _notifications.indexWhere((n) => n.id == notificationId);
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
          _notifications = _notifications.map((notification) => NotificationModel(
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
          )).toList();
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
      final result = await NotificationService.deleteNotification(notificationId);
      
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notification.typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      notification.typeIcon,
                      color: notification.typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E225E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF6C757D),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Priority indicator
                  if (notification.isHighPriority)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: notification.priorityColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                ],
              ),
              
              // Action button
              if (notification.actionText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleNotificationTap(notification),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4B63FF),
                        side: const BorderSide(color: Color(0xFF4B63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        notification.actionText!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Time and unread indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    notification.timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF6C757D),
                    ),
                  ),
                  if (notification.isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4B63FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
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
        leading: IconButton(
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
          // Filter dropdown
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              underline: const SizedBox(),
              items: _typeOptions.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
                _loadNotifications(refresh: true);
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
