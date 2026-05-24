import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'privacy_policy_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  final String? userId; // Optional: if provided, edit specific user's settings
  
  const PrivacySettingsScreen({
    super.key,
    this.userId,
  });

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  // Privacy settings state
  bool _profileVisibility = true;
  bool _showOnlineStatus = true;
  bool _showLastSeen = false;
  bool _allowDirectMessages = true;
  bool _showPhone = false;
  bool _showEmail = false;
  bool _allowPhoneCalls = true;
  bool _allowLocationSharing = false;
  bool _allowDataAnalytics = false;
  bool _showRelations = true;
  
  // Local cache to prevent reset when re-entering screen
  Map<String, bool>? _localPrivacySettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings(); // Load from backend first
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen regains focus (e.g., when navigating back)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoading) {
        _loadPrivacySettings();
      }
    });
  }

  // Load local cache first to prevent reset
  Future<void> _loadLocalPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('privacy_settings_cache');
      if (settingsJson != null) {
        final settings = Map<String, bool>.fromEntries(
          settingsJson.split(',').map((e) {
            final parts = e.split(':');
            return MapEntry(parts[0], parts[1] == 'true');
          })
        );
        
        if (mounted) {
          setState(() {
            _localPrivacySettings = settings;
            _applyLocalSettings(settings);
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading local privacy settings: $e');
    }
  }
  
  // Save settings to local cache
  Future<void> _saveLocalPrivacySettings(Map<String, bool> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = settings.entries.map((e) => '${e.key}:${e.value}').join(',');
      await prefs.setString('privacy_settings_cache', settingsJson);
      _localPrivacySettings = settings;
    } catch (e) {
      debugPrint('⚠️ Error saving local privacy settings: $e');
    }
  }
  
  // Apply local settings to UI variables
  void _applyLocalSettings(Map<String, bool> settings) {
    _profileVisibility = settings['profileVisibility'] ?? settings['profile_visibility'] ?? true;
    _showOnlineStatus = settings['showOnlineStatus'] ?? settings['show_online_status'] ?? true;
    _showLastSeen = settings['showLastSeen'] ?? settings['show_last_seen'] ?? false;
    _allowDirectMessages = settings['allowDirectMessages'] ?? settings['allow_direct_messages'] ?? true;
    _showPhone = settings['showPhone'] ?? settings['show_phone'] ?? false;
    _showEmail = settings['showEmail'] ?? settings['show_email'] ?? false;
    _allowPhoneCalls = settings['allowPhoneCalls'] ?? settings['allow_phone_calls'] ?? true;
    _allowLocationSharing = settings['allowLocationSharing'] ?? settings['allow_location_sharing'] ?? false;
    _allowDataAnalytics = settings['allowDataAnalytics'] ?? settings['allow_data_analytics'] ?? false;
    _showRelations = settings['showRelations'] ?? settings['show_relations'] ?? true;
    _allowLocationSharing = settings['allowLocationSharing'] ?? settings['allow_location_sharing'] ?? false;
    _allowDataAnalytics = settings['allowDataAnalytics'] ?? settings['allow_data_analytics'] ?? false;
  }

  Future<void> _loadPrivacySettings() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic>? user;
      
      if (widget.userId != null) {
        // Load specific user's privacy settings (for admin/editing other users)
        debugPrint('🔒 Loading privacy settings for user: ${widget.userId}');
        user = await UserService.getUserById(widget.userId!);
      } else {
        // Load current user's privacy settings
        debugPrint('🔒 Loading current user privacy settings');
        user = await UserService.getProfile();
      }
      
      if (user != null && mounted) {
        // Privacy settings are stored directly in user document, not nested
        final settings = {
          'profileVisibility': user['profileVisibility'] ?? true,
          'showOnlineStatus': user['showOnlineStatus'] ?? true,
          'showLastSeen': user['showLastSeen'] ?? false,
          'allowDirectMessages': user['allowDirectMessages'] ?? true,
          'showPhone': user['showPhone'] ?? false,
          'showEmail': user['showEmail'] ?? false,
          'allowPhoneCalls': user['allowPhoneCalls'] ?? true,
          'allowLocationSharing': user['allowLocationSharing'] ?? false,
          'allowDataAnalytics': user['allowDataAnalytics'] ?? false,
        };
        
        debugPrint('🔒 Loaded privacy settings from backend: $settings');
        
        final boolSettings = settings.map((key, value) => MapEntry(key, value as bool));
        
        setState(() {
          _applyLocalSettings(boolSettings);
          _saveLocalPrivacySettings(boolSettings);
          _isLoading = false;
        });
      } else {
        debugPrint('⚠️ No user data found, trying local cache');
        // Fallback to local cache if backend fails
        await _loadLocalPrivacySettings();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading privacy settings: $e');
      debugPrint('⚠️ Falling back to local cache');
      
      // Fallback to local cache if backend fails
      await _loadLocalPrivacySettings();
      setState(() => _isLoading = false);
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using cached settings. Network error occurred.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    bool success = false;
    
    try {
      debugPrint('🔒 Updating privacy setting: $key = $value');
      
      // Update UI immediately for better UX
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
          case 'allow_phone_calls':
            _allowPhoneCalls = value;
            break;
          case 'allow_location_sharing':
            _allowLocationSharing = value;
            break;
          case 'allow_data_analytics':
            _allowDataAnalytics = value;
            break;
        }
      });
      
      // Send update to backend
      switch (key) {
        case 'profile_visibility':
          success = await UserService.updatePrivacySettingsNew({'profileVisibility': value});
          break;
        case 'show_online_status':
          success = await UserService.updatePrivacySettingsNew({'showOnlineStatus': value});
          break;
        case 'show_last_seen':
          success = await UserService.updatePrivacySettingsNew({'showLastSeen': value});
          break;
        case 'allow_direct_messages':
          success = await UserService.updatePrivacySettingsNew({'allowDirectMessages': value});
          break;
        case 'show_phone':
          success = await UserService.updatePrivacySettingsNew({'showPhone': value});
          break;
        case 'show_email':
          success = await UserService.updatePrivacySettingsNew({'showEmail': value});
          break;
        case 'allow_phone_calls':
          success = await UserService.updatePrivacySettingsNew({'allowPhoneCalls': value});
          break;
        case 'allow_location_sharing':
          success = await UserService.updatePrivacySettingsNew({'allowLocationSharing': value});
          break;
        case 'allow_data_analytics':
          success = await UserService.updatePrivacySettingsNew({'allowDataAnalytics': value});
          break;
      }
      
      // Save to local cache immediately
      final currentSettings = {
        'profile_visibility': _profileVisibility,
        'show_online_status': _showOnlineStatus,
        'show_last_seen': _showLastSeen,
        'allow_direct_messages': _allowDirectMessages,
        'show_phone': _showPhone,
        'show_email': _showEmail,
        'allow_phone_calls': _allowPhoneCalls,
        'allow_location_sharing': _allowLocationSharing,
        'allow_data_analytics': _allowDataAnalytics,
        'showRelations': _showRelations,
      };
      await _saveLocalPrivacySettings(currentSettings);
      
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
            case 'allow_phone_calls':
              _allowPhoneCalls = !value;
              break;
            case 'allow_location_sharing':
              _allowLocationSharing = !value;
              break;
            case 'allow_data_analytics':
              _allowDataAnalytics = !value;
              break;
            case 'showRelations':
              _showRelations = !value;
              break;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update privacy setting'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy setting updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating privacy setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred while updating privacy setting'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
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
              onChanged: (value) =>
                  _updatePrivacySetting('profile_visibility', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.online_prediction,
              title: 'Show Online Status',
              subtitle: 'Let others see when you\'re online',
              value: _showOnlineStatus,
              onChanged: (value) =>
                  _updatePrivacySetting('show_online_status', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.access_time,
              title: 'Show Last Seen',
              subtitle: 'Show when you were last active',
              value: _showLastSeen,
              onChanged: (value) =>
                  _updatePrivacySetting('show_last_seen', value),
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
              onChanged: (value) =>
                  _updatePrivacySetting('allow_direct_messages', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.people_outline,
              title: 'Show Follower/Following',
              subtitle: 'Allow others to see your connections',
              value: _showRelations,
              onChanged: (value) => _updatePrivacySetting('showRelations', value),
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
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.phone,
              title: 'Allow Phone Calls',
              subtitle: 'Let users call you directly',
              value: _allowPhoneCalls,
              onChanged: (value) =>
                  _updatePrivacySetting('allow_phone_calls', value),
            ),

            const SizedBox(height: 24),

            // Privacy Lists Section
            _buildSectionHeader('Privacy Lists'),
            const SizedBox(height: 12),
            _buildPrivacyListTile(
              icon: Icons.block,
              title: 'Blocked Users',
              subtitle: 'Manage users you have blocked',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyListScreen(type: PrivacyListType.blocked),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildPrivacyListTile(
              icon: Icons.volume_off,
              title: 'Muted Users',
              subtitle: 'Manage users you have muted',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyListScreen(type: PrivacyListType.muted),
                ),
              ),
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
              onChanged: (value) =>
                  _updatePrivacySetting('allow_location_sharing', value),
            ),
            const SizedBox(height: 8),
            _buildPrivacyCard(
              icon: Icons.analytics,
              title: 'Data Analytics',
              subtitle: 'Help us improve with anonymous usage data',
              value: _allowDataAnalytics,
              onChanged: (value) =>
                  _updatePrivacySetting('allow_data_analytics', value),
            ),

            const SizedBox(height: 32),

            // Public Profile Preview Section
            _buildSectionHeader('Public Profile Preview'),
            const SizedBox(height: 12),
            _buildPublicProfilePreview(),

            const SizedBox(height: 32),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1E225E),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
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
            child: Icon(icon, color: const Color(0xFF4B63FF), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E225E),
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

  Widget _buildPublicProfilePreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visibility Status
          Row(
            children: [
              Icon(
                _profileVisibility ? Icons.visibility : Icons.visibility_off,
                color: _profileVisibility ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _profileVisibility
                      ? 'Your profile is PUBLIC'
                      : 'Your profile is HIDDEN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _profileVisibility ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // What Others See
          const Text(
            'Others can see:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF717BBC),
            ),
          ),
          const SizedBox(height: 12),

          // Visible Fields
          _buildVisibilityItem('Avatar & Profile Picture', true, Icons.image),
          _buildVisibilityItem('Bio & Description', true, Icons.description),
          _buildVisibilityItem(
            'Online Status',
            _showOnlineStatus,
            Icons.online_prediction,
          ),
          _buildVisibilityItem('Last Seen', _showLastSeen, Icons.access_time),
          _buildVisibilityItem('Phone Number', _showPhone, Icons.phone),
          _buildVisibilityItem('Email Address', _showEmail, Icons.email),
          _buildVisibilityItem(
            'Location/Country',
            _allowLocationSharing,
            Icons.location_on,
          ),
          _buildVisibilityItem('Activities & Reviews', true, Icons.star),
          _buildVisibilityItem(
            'Receive Messages',
            _allowDirectMessages,
            Icons.mail,
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityItem(String title, bool isVisible, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isVisible
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isVisible ? Icons.check : Icons.close,
              size: 14,
              color: isVisible ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: Color(0xFF717BBC)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isVisible 
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E225E))
                    : Colors.grey[400],
                fontWeight: FontWeight.w500,
                decoration: isVisible
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // View Privacy Policy Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
            icon: const Icon(Icons.privacy_tip, size: 20),
            label: const Text(
              'View Privacy Policy',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 12),
        // Delete Account Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              _showDeleteAccountDialog();
            },
            icon: const Icon(Icons.delete_forever, size: 20),
            label: const Text(
              'Delete Account',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone and will permanently delete:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '• Your profile and personal information\n'
              '• All your activities and bookings\n'
              '• Your messages and conversations\n'
              '• Your photos and files',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Delete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      setState(() => _isLoading = true);

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      final result = await UserService.deleteAccount();

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Sign out and navigate to login
        await AuthService.logout();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while deleting your account'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPrivacyListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E5FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF4B63FF), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E225E),
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
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

enum PrivacyListType { blocked, muted }

class PrivacyListScreen extends StatefulWidget {
  final PrivacyListType type;

  const PrivacyListScreen({super.key, required this.type});

  @override
  State<PrivacyListScreen> createState() => _PrivacyListScreenState();
}

class _PrivacyListScreenState extends State<PrivacyListScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    final result = await UserService.getBlockedAndMutedUsers();
    if (mounted) {
      setState(() {
        if (widget.type == PrivacyListType.blocked) {
          _users = List<Map<String, dynamic>>.from(result['blockedUsers'] ?? []);
        } else {
          _users = List<Map<String, dynamic>>.from(result['mutedUsers'] ?? []);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(String userId) async {
    bool success = false;
    if (widget.type == PrivacyListType.blocked) {
      success = await UserService.unblockUser(userId);
    } else {
      success = await UserService.unmuteUser(userId);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.type == PrivacyListType.blocked
                ? 'User unblocked successfully'
                : 'User unmuted successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadList();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == PrivacyListType.blocked ? 'Blocked Users' : 'Muted Users';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.type == PrivacyListType.blocked
                            ? Icons.block
                            : Icons.volume_off,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${title.toLowerCase()} yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final fullname = user['fullname']?.toString() ?? 'User';
                    final avatar = user['avatar']?.toString() ?? '';
                    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            backgroundColor: const Color(0xFFE8E5FF),
                            child: avatar.isEmpty
                                ? const Icon(Icons.person, color: Color(0xFF4B63FF))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              fullname,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E225E),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _handleAction(userId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.type == PrivacyListType.blocked
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFECFDF5),
                              foregroundColor: widget.type == PrivacyListType.blocked
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF059669),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              widget.type == PrivacyListType.blocked ? 'Unblock' : 'Unmute',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
