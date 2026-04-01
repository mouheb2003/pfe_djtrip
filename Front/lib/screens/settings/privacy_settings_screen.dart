import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import 'privacy_details_screen.dart';
import 'delete_account_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = true;
  Map<String, bool> _privacySettings = {
    'profileVisibility': true,
    'showOnlineStatus': true,
    'showLastSeen': false,
    'allowDirectMessages': true,
    'showPhone': false,
    'showEmail': false,
    'allowLocationSharing': false,
    'allowDataAnalytics': false,
  };

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
    // Timeout safety - stop loading after 5 seconds max
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _loadPrivacySettings() async {
    print('🔄 Loading privacy settings...');
    try {
      final user = await UserService.getProfile();
      print('✅ User loaded: ${user != null ? 'yes' : 'null'}');
      
      if (!mounted) return;
      
      if (user != null) {
        // Debug: print all user keys
        print('📋 User keys: ${user.keys.toList()}');
        
        setState(() {
          _privacySettings['profileVisibility'] = user['profileVisibility'] ?? true;
          _privacySettings['showOnlineStatus'] = user['showOnlineStatus'] ?? true;
          _privacySettings['showLastSeen'] = user['showLastSeen'] ?? false;
          _privacySettings['allowDirectMessages'] = user['allowDirectMessages'] ?? true;
          _privacySettings['showPhone'] = user['showPhone'] ?? false;
          _privacySettings['showEmail'] = user['showEmail'] ?? false;
          _privacySettings['allowLocationSharing'] = user['allowLocationSharing'] ?? false;
          _privacySettings['allowDataAnalytics'] = user['allowDataAnalytics'] ?? false;
          _isLoading = false;
        });
        print('✅ Privacy settings loaded successfully');
      } else {
        print('⚠️ User is null, showing default settings');
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('❌ Error loading privacy settings: $e');
      print('📍 Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    setState(() {
      _privacySettings[key] = value;
    });

    try {
      await UserService.updatePrivacySettings({key: value});
    } catch (e) {
      // Revert on error
      setState(() {
        _privacySettings[key] = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating privacy settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required String key,
    required bool value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {
          _updatePrivacySetting(key, newValue);
        },
        activeColor: AppColors.primary,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Profile Section
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'PROFILE PRIVACY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'Profile Visibility',
                        subtitle: 'Control who can see your profile',
                        key: 'profileVisibility',
                        value: _privacySettings['profileVisibility']!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyDetailsScreen(
                                title: 'Profile Visibility',
                                description: 'Choose who can see your profile information',
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        title: 'Show Online Status',
                        subtitle: 'Let others see when you\'re online',
                        key: 'showOnlineStatus',
                        value: _privacySettings['showOnlineStatus']!,
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        title: 'Show Last Seen',
                        subtitle: 'Let others see when you were last active',
                        key: 'showLastSeen',
                        value: _privacySettings['showLastSeen']!,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Communication Section
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'COMMUNICATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'Allow Direct Messages',
                        subtitle: 'Let people send you messages directly',
                        key: 'allowDirectMessages',
                        value: _privacySettings['allowDirectMessages']!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyDetailsScreen(
                                title: 'Direct Messages',
                                description: 'Control who can send you direct messages',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Contact Information Section
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'CONTACT INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'Show Phone Number',
                        subtitle: 'Display your phone number on your profile',
                        key: 'showPhone',
                        value: _privacySettings['showPhone']!,
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        title: 'Show Email Address',
                        subtitle: 'Display your email address on your profile',
                        key: 'showEmail',
                        value: _privacySettings['showEmail']!,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Data & Analytics Section
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'DATA & ANALYTICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        title: 'Location Sharing',
                        subtitle: 'Share your location for better recommendations',
                        key: 'allowLocationSharing',
                        value: _privacySettings['allowLocationSharing']!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyDetailsScreen(
                                title: 'Location Sharing',
                                description: 'Control how your location data is used',
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        title: 'Data Analytics',
                        subtitle: 'Help us improve DJTrip with usage data',
                        key: 'allowDataAnalytics',
                        value: _privacySettings['allowDataAnalytics']!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyDetailsScreen(
                                title: 'Data Analytics',
                                description: 'Learn how we use your data to improve our services',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Danger Zone - Delete Account
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'DANGER ZONE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.red.withOpacity(0.05),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
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
