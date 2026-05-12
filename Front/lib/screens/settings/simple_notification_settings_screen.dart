import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/fcm_notification_service.dart';
import '../../theme/app_theme.dart';

class SimpleNotificationSettingsScreen extends StatefulWidget {
  const SimpleNotificationSettingsScreen({super.key});

  @override
  State<SimpleNotificationSettingsScreen> createState() => _SimpleNotificationSettingsScreenState();
}

class _SimpleNotificationSettingsScreenState extends State<SimpleNotificationSettingsScreen> {
  bool _isLoading = false;
  bool _pushNotifEnabled = true;
  bool _emailNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final user = await UserService.getProfile();
      if (user != null && mounted) {
        setState(() {
          _pushNotifEnabled = (user['push_notif_enabled'] as bool?) ?? true;
          _emailNotifications = (user['notifications_email'] as bool?) ?? true;
        });
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      setState(() {
        if (key == 'push_notif_enabled') {
          _pushNotifEnabled = value;
        } else if (key == 'notifications_email') {
          _emailNotifications = value;
        }
      });

      // Handle FCM token management for push notifications
      if (key == 'push_notif_enabled') {
        if (value) {
          // Enable push notifications - send token to backend
          await FcmNotificationService().sendTokenToBackend();
        } else {
          // Disable push notifications - delete token from backend
          await FcmNotificationService().deleteToken();
        }
      }

      // Update backend
      Map<String, dynamic> updates = {};
      if (key == 'push_notif_enabled') {
        updates['push_notif_enabled'] = value;
      } else if (key == 'notifications_email') {
        updates['notifications_email'] = value;
      }

      final success = await UserService.updateNotificationSettings(Map<String, bool>.from(updates));
      if (!success && mounted) {
        // Revert on failure
        setState(() {
          if (key == 'push_notif_enabled') {
            _pushNotifEnabled = !value;
          } else if (key == 'notifications_email') {
            _emailNotifications = !value;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification setting'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification setting updated successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      print('Error updating notification setting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating notification setting'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // FCM Push Notifications
            Container(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.notifications,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Push Notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Receive notifications on your device',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _pushNotifEnabled,
                          onChanged: (value) => _updateNotificationSetting('push_notif_enabled', value),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Email Notifications
            Container(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.email,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email Notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Receive updates via email',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _emailNotifications,
                          onChanged: (value) => _updateNotificationSetting('notifications_email', value),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Info section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notification Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Push notifications are delivered to your device instantly\n• Email notifications are sent to your registered email address\n• You can enable or disable each type independently',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
