import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../settings/privacy_settings_screen.dart';
import '../auth/login_screen.dart';

class PrivacyOnboardingScreen extends StatefulWidget {
  const PrivacyOnboardingScreen({super.key});

  @override
  State<PrivacyOnboardingScreen> createState() => _PrivacyOnboardingScreenState();
}

class _PrivacyOnboardingScreenState extends State<PrivacyOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Privacy settings defaults
  bool _profileVisibility = true;
  bool _allowDirectMessages = true;
  bool _showOnlineStatus = true;
  bool _allowLocationSharing = false;
  bool _allowPhoneCalls = true;

  final List<Map<String, dynamic>> _privacyPages = [
    {
      'title': 'Profile Visibility',
      'subtitle': 'Control who can see your profile',
      'description': 'Choose whether other users can see your profile information, photos, and activities.',
      'icon': Icons.visibility,
      'key': 'profile_visibility',
      'value': true,
      'color': AppColors.primary,
    },
    {
      'title': 'Direct Messages',
      'subtitle': 'Control who can contact you',
      'description': 'Allow other users to send you messages directly through the app.',
      'icon': Icons.message,
      'key': 'allow_direct_messages',
      'value': true,
      'color': Colors.green,
    },
    {
      'title': 'Online Status',
      'subtitle': 'Control your visibility',
      'description': 'Let others see when you\'re online and active in the app.',
      'icon': Icons.online_prediction,
      'key': 'show_online_status',
      'value': true,
      'color': Colors.blue,
    },
    {
      'title': 'Location Sharing',
      'subtitle': 'Control your location data',
      'description': 'Share your location to get better recommendations and nearby activities.',
      'icon': Icons.location_on,
      'key': 'allow_location_sharing',
      'value': false,
      'color': Colors.orange,
    },
    {
      'title': 'Phone Calls',
      'subtitle': 'Control direct calls',
      'description': 'Allow other users to call you directly through the app.',
      'icon': Icons.phone,
      'key': 'allow_phone_calls',
      'value': true,
      'color': Colors.purple,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _privacyPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _updateSetting(String key, bool value) {
    setState(() {
      switch (key) {
        case 'profile_visibility':
          _profileVisibility = value;
          break;
        case 'allow_direct_messages':
          _allowDirectMessages = value;
          break;
        case 'show_online_status':
          _showOnlineStatus = value;
          break;
        case 'allow_location_sharing':
          _allowLocationSharing = value;
          break;
        case 'allow_phone_calls':
          _allowPhoneCalls = value;
          break;
      }
    });
  }

  Future<void> _saveAndContinue() async {
    try {
      // Save privacy settings
      final settings = {
        'profile_visibility': _profileVisibility,
        'allow_direct_messages': _allowDirectMessages,
        'show_online_status': _showOnlineStatus,
        'allow_location_sharing': _allowLocationSharing,
        'allow_phone_calls': _allowPhoneCalls,
      };

      // Call UserService to save settings
      // await UserService.updatePrivacySettingsNew(settings);

      if (mounted) {
        // Navigate to privacy settings screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const PrivacySettingsScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving privacy settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: _previousPage,
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'Skip',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: List.generate(
                _privacyPages.length,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < _privacyPages.length - 1 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? _privacyPages[index]['color']
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _privacyPages.length,
              itemBuilder: (context, index) {
                final page = _privacyPages[index];
                return _buildPrivacyPage(page, index);
              },
            ),
          ),

          // Bottom navigation
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _privacyPages[_currentPage]['color'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == _privacyPages.length - 1
                          ? 'Complete Setup'
                          : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage(Map<String, dynamic> page, int index) {
    bool currentValue;
    switch (page['key']) {
      case 'profile_visibility':
        currentValue = _profileVisibility;
        break;
      case 'allow_direct_messages':
        currentValue = _allowDirectMessages;
        break;
      case 'show_online_status':
        currentValue = _showOnlineStatus;
        break;
      case 'allow_location_sharing':
        currentValue = _allowLocationSharing;
        break;
      case 'allow_phone_calls':
        currentValue = _allowPhoneCalls;
        break;
      default:
        currentValue = true;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: (page['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page['icon'] as IconData,
              size: 60,
              color: page['color'] as Color,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            page['title'] as String,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E225E),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            page['subtitle'] as String,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page['description'] as String,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Toggle switch
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentValue ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: currentValue ? page['color'] as Color : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentValue
                            ? 'This feature is currently active'
                            : 'This feature is currently disabled',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: currentValue,
                  onChanged: (value) {
                    _updateSetting(page['key'] as String, value);
                  },
                  activeColor: page['color'] as Color,
                  activeTrackColor: (page['color'] as Color).withOpacity(0.2),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Privacy tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (page['color'] as Color).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (page['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: page['color'] as Color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getPrivacyTip(page['key'] as String),
                    style: TextStyle(
                      fontSize: 14,
                      color: (page['color'] as Color).withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrivacyTip(String key) {
    switch (key) {
      case 'profile_visibility':
        return 'When disabled, other users will see a private profile message instead of your information.';
      case 'allow_direct_messages':
        return 'You can always block specific users even if direct messages are enabled.';
      case 'show_online_status':
        return 'This helps others know when you\'re available for quick responses.';
      case 'allow_location_sharing':
        return 'Your exact location is never shared - only your general area for recommendations.';
      case 'allow_phone_calls':
        return 'Users need your phone number to call you, even if this is enabled.';
      default:
        return 'You can change these settings anytime in the Privacy Settings menu.';
    }
  }
}
