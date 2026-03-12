import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../models/touriste.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/notification_helper.dart';
import 'auth/new_login_screen.dart';
import 'edit_profile_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isUploadingAvatar = false;
  bool _isLoadingUserData = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    // Reload fresh user data when screen opens
    _refreshUserData();
  }

  // Reload user data from server
  Future<void> _refreshUserData() async {
    if (_isLoadingUserData) return; // Prevent multiple simultaneous calls

    setState(() {
      _isLoadingUserData = true;
    });

    try {
      print('🔄 Refreshing user data...');
      final result = await UserService.getUserInfo();

      if (result['success'] && result['user'] != null) {
        setState(() {
          _currentUser = result['user'];
          _isLoadingUserData = false;
        });
        print('✅ User data refreshed with avatar: ${_currentUser.avatar}');
      } else {
        setState(() {
          _isLoadingUserData = false;
        });
        print('⚠️ Failed to refresh user data');
      }
    } catch (e) {
      setState(() {
        _isLoadingUserData = false;
      });
      print('❌ Error refreshing user data: $e');
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('✅ Image selected: ${pickedFile.path}');

        setState(() {
          _isUploadingAvatar = true;
        });

        print('📤 Uploading to server...');
        final result = await UserService.uploadAvatar(File(pickedFile.path));
        print('📥 Server response: $result');

        setState(() {
          _isUploadingAvatar = false;
        });

        if (result['success']) {
          // Update current user with new avatar
          if (result['user'] != null) {
            setState(() {
              _currentUser = result['user'];
            });
          }

          // Refresh data from server to ensure everything is in sync
          await _refreshUserData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Profile picture updated successfully!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          String errorMessage = result['message'] ?? 'Failed to upload image';

          // Check if backend is not running
          if (errorMessage.contains('FormatException') ||
              errorMessage.contains('DOCTYPE') ||
              errorMessage.contains('Connection') ||
              errorMessage.contains('Failed host lookup')) {
            errorMessage =
                '❌ Backend server not available. Please start the backend server.';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        print('❌ No image selected');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showAvatarChangeDialog() {
    final bool hasPhoto = _currentUser.avatar != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      border: Border.all(
                        color: const Color(0xFFFF6B1A).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _currentUser.avatar != null
                          ? Image.network(
                              _currentUser.avatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.grey[400],
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 28,
                              color: Colors.grey[400],
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Picture',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPhoto
                            ? 'Edit or delete your photo'
                            : 'Add a profile picture',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSheetBtn(
                icon: Icons.edit_outlined,
                label: 'Edit photo',
                color: const Color(0xFFFF6B1A),
                bgColor: const Color(0xFFFF6B1A).withOpacity(0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditSourcePicker();
                },
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 12),
                _buildSheetBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete photo',
                  color: Colors.red,
                  bgColor: Colors.red.withOpacity(0.07),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteAvatar();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a source',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSheetBtn(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                sublabel: 'Works on real device',
                color: const Color(0xFFFF6B1A),
                bgColor: const Color(0xFFFF6B1A).withOpacity(0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildSheetBtn(
                icon: Icons.photo_library_outlined,
                label: 'From gallery',
                sublabel: 'Works everywhere',
                color: const Color(0xFFFF6B1A),
                bgColor: const Color(0xFFFF6B1A).withOpacity(0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetBtn({
    required IconData icon,
    required String label,
    String? sublabel,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color == Colors.red
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAvatar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete photo?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile photo will be permanently deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteAvatarCloud();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAvatarCloud() async {
    setState(() {
      _isUploadingAvatar = true;
    });

    final result = await UserService.deleteAvatarFromCloud();

    setState(() {
      _isUploadingAvatar = false;
    });

    if (result['success'] == true) {
      await _refreshUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile photo deleted'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error deleting photo'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _shareProfile(BuildContext context) async {
    final languePreferee = _currentUser is Touriste
        ? (_currentUser as Touriste).languePreferee
        : null;
    final profileText =
        '''
🌍 DJTrip Profile

👤 ${_currentUser.fullname}
📧 ${_currentUser.email}
${_currentUser.age != null ? '🎂 ${_currentUser.age} years old\n' : ''}
${_currentUser.paysOrigine != null ? '🌎 ${_currentUser.paysOrigine}\n' : ''}
${_currentUser.userType == 'Touriste' && languePreferee != null ? '🗣️ $languePreferee\n' : ''}
${_currentUser.bio != null && _currentUser.bio!.isNotEmpty ? '📝 ${_currentUser.bio}\n' : ''}

✈️ ${_currentUser.userType} on DJTrip
''';

    try {
      await Clipboard.setData(ClipboardData(text: profileText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile copied to clipboard!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing error'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.orange.shade50.withOpacity(0.3)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logout Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Logout Button
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();

      // Show success notification
      NotificationHelper.showSuccess(
        context,
        'Logged out successfully. See you soon!',
      );

      // Wait a moment for notification to show
      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => NewLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar with profile photo
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Color(0xFFFF6B1A),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB84D), Color(0xFFFF6B1A)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 4),
                      // Avatar with edit button
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _isUploadingAvatar
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF6B1A),
                                      ),
                                    ),
                                  )
                                : _currentUser.avatar != null
                                ? ClipOval(
                                    child: Image.network(
                                      _currentUser.avatar!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 45,
                                              color: Color(0xFFFF6B1A),
                                            );
                                          },
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 45,
                                    color: Color(0xFFFF6B1A),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingAvatar
                                  ? null
                                  : _showAvatarChangeDialog,
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Color(0xFFFF6B1A),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Color(0xFFFF6B1A),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (_currentUser.avatar == null) ...[
                        Text(
                          'Add photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _currentUser.fullname,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      // Age and Language
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_currentUser.age != null) ...[
                              Icon(
                                Icons.cake,
                                size: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${_currentUser.age} years old',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                            if (_currentUser.age != null &&
                                _currentUser is Touriste)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            if (_currentUser is Touriste) ...[
                              Icon(
                                Icons.language,
                                size: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  (_currentUser as Touriste).languePreferee,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Bio
                      if (_currentUser.bio != null &&
                          _currentUser.bio!.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _currentUser.bio!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _currentUser.email,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Badge type d'utilisateur
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B1A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(0xFFFF6B1A).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentUser.userType == 'Touriste'
                              ? Icons.luggage
                              : Icons.business,
                          color: Color(0xFFFF6B1A),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _currentUser.userType == 'Touriste'
                              ? 'Tourist'
                              : _currentUser.userType == 'Organisateur'
                              ? 'Organizer'
                              : _currentUser.userType,
                          style: TextStyle(
                            color: Color(0xFFFF6B1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Boutons d'action compacts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCompactButton(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: Color(0xFFFF6B1A),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(user: _currentUser),
                            ),
                          );
                          // Refresh user data after returning from edit screen
                          _refreshUserData();
                        },
                      ),
                      SizedBox(width: 12),
                      _buildCompactButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        color: Colors.blue,
                        onTap: () {
                          _shareProfile(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Profile information
                  _buildInfoCard(
                    icon: Icons.cake_outlined,
                    title: 'Age',
                    value: _currentUser.age != null
                        ? '${_currentUser.age} years old'
                        : 'Not specified',
                  ),
                  SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: _currentUser.numTel ?? 'Not specified',
                  ),
                  SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.public_outlined,
                    title: 'Country of origin',
                    value: _currentUser.paysOrigine ?? 'Not specified',
                  ),

                  // Preferred language
                  if (_currentUser is Touriste) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.language_outlined,
                      title: 'Preferred language',
                      value: (_currentUser as Touriste).languePreferee,
                    ),
                  ],

                  SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.info_outline,
                    title: 'Bio',
                    value: _currentUser.bio ?? 'Not specified',
                  ),

                  // Interests
                  if (_currentUser is Touriste &&
                      (_currentUser as Touriste).centresInteret.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildPreferencesCard(
                      (_currentUser as Touriste).centresInteret,
                    ),
                  ],

                  SizedBox(height: 24),

                  // Paramètres
                  _buildSectionTitle('Settings'),
                  _buildSettingsCard(
                    icon: Icons.favorite_outline,
                    title: 'My Preferences',
                    subtitle:
                        _currentUser is Touriste &&
                            (_currentUser as Touriste).centresInteret.isNotEmpty
                        ? '${(_currentUser as Touriste).centresInteret.length} interest(s)'
                        : 'Set your interests',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PreferencesScreen(
                            initialPreferences: _currentUser is Touriste
                                ? (_currentUser as Touriste).centresInteret
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  _buildSettingsCard(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle:
                        'Email: ${_currentUser.notificationsEmail ? "Enabled" : "Disabled"}',
                    onTap: () {
                      // TODO: Paramètres notifications
                    },
                  ),
                  SizedBox(height: 12),
                  _buildSettingsCard(
                    icon: Icons.security_outlined,
                    title: 'Privacy',
                    subtitle: 'Manage your data',
                    onTap: () {
                      // TODO: Paramètres confidentialité
                    },
                  ),
                  SizedBox(height: 12),
                  _buildSettingsCard(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'FAQ and contact',
                    onTap: () {
                      // TODO: Aide
                    },
                  ),
                  SizedBox(height: 24),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: Icon(Icons.logout),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey[700], size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.grey[700], size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(List<String> preferences) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B1A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: Color(0xFFFF6B1A),
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Interests',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: preferences.map((pref) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B1A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFFFF6B1A).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    pref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFF6B1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
