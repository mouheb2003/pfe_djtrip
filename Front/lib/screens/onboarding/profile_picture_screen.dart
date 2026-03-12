import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'permissions_screen.dart';

class ProfilePictureScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profileData;

  const ProfilePictureScreen({
    super.key,
    required this.user,
    required this.profileData,
  });

  @override
  State<ProfilePictureScreen> createState() => _ProfilePictureScreenState();
}

class _ProfilePictureScreenState extends State<ProfilePictureScreen> {
  File? _imageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
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
          _imageFile = File(pickedFile.path);
        });
      } else {
        print('❌ No image selected');
      }
    } catch (e) {
      print('❌ Error selecting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Profile Picture',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.photo_camera, color: Color(0xFFFF6B1A)),
                  title: Text('Take a photo'),
                  subtitle: Text(
                    'Works on real device',
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Color(0xFFFF6B1A)),
                  title: Text('Choose from gallery'),
                  subtitle: Text(
                    'Works everywhere',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_imageFile != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imageFile = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadAndContinue() async {
    if (_imageFile == null) {
      // Skip - go directly to permissions screen
      _navigateToPermissions();
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      print('📤 Uploading avatar...');
      final result = await UserService.uploadAvatar(_imageFile!);
      print('📥 Upload result: $result');

      if (result['success']) {
        // Update the user object with the new avatar URL
        final updatedUser = result['user'] as User;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile picture uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Navigate to permissions screen with updated user
        _navigateToPermissions(updatedUser: updatedUser);
      } else {
        setState(() {
          _isUploading = false;
        });

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
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _navigateToPermissions({User? updatedUser}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PermissionsScreen(
          user: updatedUser ?? widget.user,
          profileData: widget.profileData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B1A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _navigateToPermissions,
            child: Text(
              'Skip',
              style: TextStyle(
                color: _isUploading ? Colors.grey : Color(0xFFFF6B1A),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= 2
                            ? Color(0xFFFF6B1A)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      'Add Profile Picture',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Add a photo so your friends can recognize you',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 50),

                    // Profile picture preview
                    GestureDetector(
                      onTap: _isUploading ? null : _showImageSourceDialog,
                      child: Stack(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              border: Border.all(
                                color: Color(0xFFFF6B1A),
                                width: 3,
                              ),
                            ),
                            child: _imageFile != null
                                ? ClipOval(
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 100,
                                    color: Colors.grey[400],
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFF6B1A),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                _imageFile != null
                                    ? Icons.edit
                                    : Icons.add_a_photo,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    // Upload button
                    if (_imageFile != null)
                      TextButton.icon(
                        onPressed: _isUploading ? null : _showImageSourceDialog,
                        icon: Icon(
                          Icons.change_circle,
                          color: Color(0xFFFF6B1A),
                        ),
                        label: Text(
                          'Change Photo',
                          style: TextStyle(
                            color: Color(0xFFFF6B1A),
                            fontSize: 16,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _isUploading ? null : _showImageSourceDialog,
                        icon: Icon(Icons.add_photo_alternate),
                        label: Text('Select Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFFFF6B1A),
                          side: BorderSide(color: Color(0xFFFF6B1A)),
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    SizedBox(height: 20),

                    if (_imageFile != null)
                      Text(
                        'Looks great! 📸',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
