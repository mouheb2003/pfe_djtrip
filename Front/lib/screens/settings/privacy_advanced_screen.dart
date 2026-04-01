import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'delete_account_screen.dart';

class PrivacyAdvancedScreen extends StatefulWidget {
  final String title;
  final String? userAvatar;
  final String userName;

  const PrivacyAdvancedScreen({
    super.key,
    required this.title,
    this.userAvatar,
    required this.userName,
  });

  @override
  State<PrivacyAdvancedScreen> createState() => _PrivacyAdvancedScreenState();
}

class _PrivacyAdvancedScreenState extends State<PrivacyAdvancedScreen> {
  bool _isLoading = true;
  Map<String, bool> _advancedSettings = {
    'discoverability': true,
    'searchIndexing': true,
    'activityTracking': false,
    'personalizedAds': false,
    'thirdPartySharing': false,
    'cookiesEnabled': true,
    'biometricAuth': false,
    'twoFactorAuth': false,
  };

  @override
  void initState() {
    super.initState();
    _loadAdvancedSettings();
  }

  Future<void> _loadAdvancedSettings() async {
    try {
      final user = await UserService.getProfile();
      if (mounted) {
        if (user != null) {
          setState(() {
            _advancedSettings['discoverability'] = user['discoverability'] ?? true;
            _advancedSettings['searchIndexing'] = user['searchIndexing'] ?? true;
            _advancedSettings['activityTracking'] = user['activityTracking'] ?? false;
            _advancedSettings['personalizedAds'] = user['personalizedAds'] ?? false;
            _advancedSettings['thirdPartySharing'] = user['thirdPartySharing'] ?? false;
            _advancedSettings['cookiesEnabled'] = user['cookiesEnabled'] ?? true;
            _advancedSettings['biometricAuth'] = user['biometricAuth'] ?? false;
            _advancedSettings['twoFactorAuth'] = user['twoFactorAuth'] ?? false;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading advanced settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAdvancedSetting(String key, bool value) async {
    setState(() {
      _advancedSettings[key] = value;
    });

    try {
      await UserService.updateAdvancedSettings({key: value});
    } catch (e) {
      // Revert on error
      setState(() {
        _advancedSettings[key] = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.userAvatar != null
                ? NetworkImage(widget.userAvatar!)
                : null,
            backgroundColor: Colors.white,
            child: widget.userAvatar == null
                ? Icon(Icons.person, size: 50, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            widget.userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCategory({
    required String title,
    required List<Map<String, dynamic>> settings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
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
            children: settings.map((setting) {
              return Column(
                children: [
                  ListTile(
                    title: Text(
                      setting['title'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(setting['subtitle']),
                    trailing: Switch(
                      value: _advancedSettings[setting['key']] ?? false,
                      onChanged: (value) {
                        _updateAdvancedSetting(setting['key'], value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  if (setting != settings.last) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
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
          child: Column(
            children: [
              ListTile(
                title: const Text('Clear Activity History'),
                subtitle: const Text('Remove all your activity logs'),
                trailing: const Icon(Icons.history, color: Colors.orange),
                onTap: () => _showClearHistoryDialog(),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Delete Account'),
                subtitle: const Text('Permanently delete your account'),
                trailing: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DeleteAccountScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity History'),
        content: const Text(
          'This will remove all your activity logs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Activity history cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: const Text(
          'Delete Account?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data.\n\nThis action cannot be undone!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  
                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  
                  // Call API to delete account
                  final result = await UserService.deleteAccount();
                  
                  if (!mounted) return;
                  Navigator.of(context).pop(); // Close loading
                  
                  if (result['success'] == true) {
                    // Clear auth and logout
                    await AuthService.logout();
                    
                    if (!mounted) return;
                    
                    // Navigate to login
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your account has been deleted'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed to delete account'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete Permanently',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Privacy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserHeader(),
            
            _buildSettingCategory(
              title: 'DISCOVERABILITY',
              settings: [
                {
                  'title': 'Profile Discoverability',
                  'subtitle': 'Allow others to find your profile',
                  'key': 'discoverability',
                },
                {
                  'title': 'Search Engine Indexing',
                  'subtitle': 'Allow your profile to appear in search results',
                  'key': 'searchIndexing',
                },
              ],
            ),

            _buildSettingCategory(
              title: 'DATA & TRACKING',
              settings: [
                {
                  'title': 'Activity Tracking',
                  'subtitle': 'Track your app usage for better experience',
                  'key': 'activityTracking',
                },
                {
                  'title': 'Personalized Ads',
                  'subtitle': 'Show ads based on your interests',
                  'key': 'personalizedAds',
                },
                {
                  'title': 'Third-party Sharing',
                  'subtitle': 'Share data with trusted partners',
                  'key': 'thirdPartySharing',
                },
                {
                  'title': 'Cookies',
                  'subtitle': 'Allow cookies for better functionality',
                  'key': 'cookiesEnabled',
                },
              ],
            ),

            _buildSettingCategory(
              title: 'SECURITY',
              settings: [
                {
                  'title': 'Biometric Authentication',
                  'subtitle': 'Use fingerprint or face recognition',
                  'key': 'biometricAuth',
                },
                {
                  'title': 'Two-Factor Authentication',
                  'subtitle': 'Add an extra layer of security',
                  'key': 'twoFactorAuth',
                },
              ],
            ),

            _buildDangerZone(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
