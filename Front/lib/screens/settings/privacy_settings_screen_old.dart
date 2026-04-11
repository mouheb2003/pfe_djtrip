import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';
import 'privacy_policy_screen.dart';
import 'delete_account_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = false;
  
  // Privacy settings state
  bool _profileVisibility = true;
  bool _showOnlineStatus = true;
  bool _showLastSeen = false;
  bool _allowDirectMessages = true;
  bool _showPhone = false;
  bool _showEmail = false;
  bool _allowLocationSharing = false;
  bool _allowDataAnalytics = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final user = await UserService.getProfile();
      if (user != null && mounted) {
        final settings = user['privacy_settings'] as Map<String, dynamic>?;
        if (settings != null) {
          setState(() {
            _profileVisibility = settings['profile_visibility'] ?? true;
            _showOnlineStatus = settings['show_online_status'] ?? true;
            _showLastSeen = settings['show_last_seen'] ?? false;
            _allowDirectMessages = settings['allow_direct_messages'] ?? true;
            _showPhone = settings['show_phone'] ?? false;
            _showEmail = settings['show_email'] ?? false;
            _allowLocationSharing = settings['allow_location_sharing'] ?? false;
            _allowDataAnalytics = settings['allow_data_analytics'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
    }
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    try {
      setState(() {
        switch (key) {
          case 'profile_visibility':
            _profileVisibility = value;
            break;
          case 'show_online_status':
            _showOnlineStatus = value;
            break;
          case 'show_last_seen':
            _showLastSeen = value;
            break;
          case 'allow_direct_messages':
            _allowDirectMessages = value;
            break;
          case 'show_phone':
            _showPhone = value;
            break;
          case 'show_email':
            _showEmail = value;
            break;
          case 'allow_location_sharing':
            _allowLocationSharing = value;
            break;
          case 'allow_data_analytics':
            _allowDataAnalytics = value;
            break;
        }
      });

      final success = await UserService.updatePrivacySettingsNew({key: value});
      if (!success && mounted) {
        // Revert on failure
        setState(() {
          switch (key) {
            case 'profile_visibility':
              _profileVisibility = !value;
              break;
            case 'show_online_status':
              _showOnlineStatus = !value;
              break;
            case 'show_last_seen':
              _showLastSeen = !value;
              break;
            case 'allow_direct_messages':
              _allowDirectMessages = !value;
              break;
            case 'show_phone':
              _showPhone = !value;
              break;
            case 'show_email':
              _showEmail = !value;
              break;
            case 'allow_location_sharing':
              _allowLocationSharing = !value;
              break;
            case 'allow_data_analytics':
              _allowDataAnalytics = !value;
              break;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update privacy setting'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating privacy setting: $e');
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
          'Privacy Settings',
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
            // Profile Visibility Section
            _buildSectionHeader('Profile Visibility'),
            const SizedBox(height: 12),
            _buildPrivacyCard(
              icon: Icons.visibility,
              title: 'Profile Visibility',
              subtitle: 'Make your profile visible to other users',
              value: _profileVisibility,
              onChanged: (value) => _updatePrivacySetting('profile_visibility', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.online_prediction,
              title: 'Show Online Status',
              subtitle: 'Let others see when you\'re online',
              value: _showOnlineStatus,
              onChanged: (value) => _updatePrivacySetting('show_online_status', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.access_time,
              title: 'Show Last Seen',
              subtitle: 'Show when you were last active',
              value: _showLastSeen,
              onChanged: (value) => _updatePrivacySetting('show_last_seen', value),
            ),

            const SizedBox(height: 24),
            
            // Communication Section
            _buildSectionHeader('Communication'),
            const SizedBox(height: 12),
            _buildPrivacyCard(
              icon: Icons.message,
              title: 'Allow Direct Messages',
              subtitle: 'Let users send you messages directly',
              value: _allowDirectMessages,
              onChanged: (value) => _updatePrivacySetting('allow_direct_messages', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.phone,
              title: 'Show Phone Number',
              subtitle: 'Display your phone number on your profile',
              value: _showPhone,
              onChanged: (value) => _updatePrivacySetting('show_phone', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.email,
              title: 'Show Email',
              subtitle: 'Display your email on your profile',
              value: _showEmail,
              onChanged: (value) => _updatePrivacySetting('show_email', value),
            ),

            const SizedBox(height: 24),

            // Data & Location Section
            _buildSectionHeader('Data & Location'),
            const SizedBox(height: 12),
            _buildPrivacyCard(
              icon: Icons.location_on,
              title: 'Location Sharing',
              subtitle: 'Share your location for better recommendations',
              value: _allowLocationSharing,
              onChanged: (value) => _updatePrivacySetting('allow_location_sharing', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.analytics,
              title: 'Data Analytics',
              subtitle: 'Help us improve with anonymous usage data',
              value: _allowDataAnalytics,
              onChanged: (value) => _updatePrivacySetting('allow_data_analytics', value),
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

  Widget _buildPrivacyCard({
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
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently delete your account and all data',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.red,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DeleteAccountScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
