import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/user_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isLoading = false;
  
  // Notification settings state
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _bookingReminders = true;
  bool _activityUpdates = true;
  bool _newMessages = true;
  bool _promotionalEmails = false;
  bool _weeklyDigest = false;
  bool _specialOffers = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final user = await UserService.getProfile();
      if (user != null && mounted) {
        final settings = user['notification_settings'] as Map<String, dynamic>?;
        if (settings != null) {
          setState(() {
            _pushNotifications = settings['push_notifications'] ?? true;
            _emailNotifications = settings['email_notifications'] ?? true;
            _bookingReminders = settings['booking_reminders'] ?? true;
            _activityUpdates = settings['activity_updates'] ?? true;
            _newMessages = settings['new_messages'] ?? true;
            _promotionalEmails = settings['promotional_emails'] ?? false;
            _weeklyDigest = settings['weekly_digest'] ?? false;
            _specialOffers = settings['special_offers'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      setState(() {
        switch (key) {
          case 'push_notifications':
            _pushNotifications = value;
            break;
          case 'email_notifications':
            _emailNotifications = value;
            break;
          case 'booking_reminders':
            _bookingReminders = value;
            break;
          case 'activity_updates':
            _activityUpdates = value;
            break;
          case 'new_messages':
            _newMessages = value;
            break;
          case 'promotional_emails':
            _promotionalEmails = value;
            break;
          case 'weekly_digest':
            _weeklyDigest = value;
            break;
          case 'special_offers':
            _specialOffers = value;
            break;
        }
      });

      final success = await UserService.updateNotificationSettings({key: value});
      if (!success && mounted) {
        // Revert on failure
        setState(() {
          switch (key) {
            case 'push_notifications':
              _pushNotifications = !value;
              break;
            case 'email_notifications':
              _emailNotifications = !value;
              break;
            case 'booking_reminders':
              _bookingReminders = !value;
              break;
            case 'activity_updates':
              _activityUpdates = !value;
              break;
            case 'new_messages':
              _newMessages = !value;
              break;
            case 'promotional_emails':
              _promotionalEmails = !value;
              break;
            case 'weekly_digest':
              _weeklyDigest = !value;
              break;
            case 'special_offers':
              _specialOffers = !value;
              break;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification setting'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating notification setting: $e');
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
            // Notification Methods Section
            _buildSectionHeader('Notification Methods'),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Receive notifications on your device',
              value: _pushNotifications,
              onChanged: (value) => _updateNotificationSetting('push_notifications', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.email,
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: _emailNotifications,
              onChanged: (value) => _updateNotificationSetting('email_notifications', value),
            ),

            const SizedBox(height: 24),
            
            // Activity Notifications Section
            _buildSectionHeader('Activity Notifications'),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: Icons.event,
              title: 'Booking Reminders',
              subtitle: 'Get reminded about upcoming bookings',
              value: _bookingReminders,
              onChanged: (value) => _updateNotificationSetting('booking_reminders', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.update,
              title: 'Activity Updates',
              subtitle: 'Stay informed about activity changes',
              value: _activityUpdates,
              onChanged: (value) => _updateNotificationSetting('activity_updates', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.message,
              title: 'New Messages',
              subtitle: 'Get notified when someone messages you',
              value: _newMessages,
              onChanged: (value) => _updateNotificationSetting('new_messages', value),
            ),

            const SizedBox(height: 24),

            // Marketing Section
            _buildSectionHeader('Marketing'),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: Icons.campaign,
              title: 'Promotional Emails',
              subtitle: 'Receive special offers and promotions',
              value: _promotionalEmails,
              onChanged: (value) => _updateNotificationSetting('promotional_emails', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.summarize,
              title: 'Weekly Digest',
              subtitle: 'Get a weekly summary of activities',
              value: _weeklyDigest,
              onChanged: (value) => _updateNotificationSetting('weekly_digest', value),
            ),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.local_offer,
              title: 'Special Offers',
              subtitle: 'Exclusive deals and discounts',
              value: _specialOffers,
              onChanged: (value) => _updateNotificationSetting('special_offers', value),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E225E),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4B63FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E225E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4B63FF),
            activeTrackColor: const Color(0xFFE8E5FF),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Test Notifications Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test notification sent!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.notifications_active, size: 20),
            label: const Text(
              'Test Notifications',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B63FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Clear All Notifications Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Notifications'),
                  content: const Text('Are you sure you want to clear all notifications?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All notifications cleared'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.clear_all, size: 20),
            label: const Text(
              'Clear All Notifications',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4B63FF),
              side: const BorderSide(color: Color(0xFF4B63FF), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
