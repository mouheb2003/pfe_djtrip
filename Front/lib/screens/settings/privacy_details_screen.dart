import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import 'privacy_advanced_screen.dart';

class PrivacyDetailsScreen extends StatefulWidget {
  final String title;
  final String description;

  const PrivacyDetailsScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  State<PrivacyDetailsScreen> createState() => _PrivacyDetailsScreenState();
}

class _PrivacyDetailsScreenState extends State<PrivacyDetailsScreen> {
  bool _isLoading = true;
  String? _userAvatar;
  String _userName = 'User';
  Map<String, dynamic> _privacyData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserService.getProfile();
      if (mounted) {
        if (user != null) {
          setState(() {
            _userAvatar = user['avatar'];
            _userName = (user['fullname'] ?? '').isNotEmpty ? user['fullname'] : 'User';
            _privacyData = {
              'profileViews': user['profileViews'] ?? 0,
              'lastActive': user['lastActive'] ?? 'Never',
              'dataShared': user['dataShared'] ?? false,
              'locationHistory': user['locationHistory'] ?? [],
              'blockedUsers': user['blockedUsers'] ?? [],
            };
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading privacy details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildUserCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Avatar and Info
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _userAvatar != null
                      ? NetworkImage(_userAvatar!)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: _userAvatar == null
                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Privacy Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profile Views'),
                      Text(
                        '${_privacyData['profileViews'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Active'),
                      Text(
                        _privacyData['lastActive'] ?? 'Never',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'PRIVACY OPTIONS',
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
              ListTile(
                title: const Text('Advanced Privacy Settings'),
                subtitle: const Text('Fine-tune your privacy preferences'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PrivacyAdvancedScreen(
                        title: widget.title,
                        userAvatar: _userAvatar,
                        userName: _userName,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Blocked Users'),
                subtitle: Text('${(_privacyData['blockedUsers'] as List?)?.length ?? 0} users blocked'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to blocked users screen
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Data Download'),
                subtitle: const Text('Download your personal data'),
                trailing: const Icon(Icons.download, size: 20),
                onTap: () {
                  _showDataDownloadDialog();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDataDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Your Data'),
        content: const Text(
          'We\'ll prepare a copy of your personal data and send it to your email address. This may take up to 24 hours.',
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
                  content: Text('Data download request sent'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildUserCard(),
                _buildPrivacyOptions(),
              ],
            ),
    );
  }
}
