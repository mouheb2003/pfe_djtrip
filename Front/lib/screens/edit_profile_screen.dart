import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../models/touriste.dart';
import '../services/user_service.dart';
import 'country_selection_screen.dart';
import 'language_selection_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullnameController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  String? _selectedCountry;
  String? _selectedLanguage;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _avatarDeleted = false;
  final ImagePicker _picker = ImagePicker();

  // Country code picker state
  String? _selectedDialCode;
  String? _selectedFlag;
  String? _phoneFormat;

  static const List<Map<String, String>> _countryCodes = [
    {'flag': '🇹🇳', 'name': 'Tunisia', 'dial': '+216', 'format': '20 123 456'},
    {
      'flag': '🇩🇿',
      'name': 'Algeria',
      'dial': '+213',
      'format': '655 123 456',
    },
    {
      'flag': '🇲🇦',
      'name': 'Morocco',
      'dial': '+212',
      'format': '6 12 34 56 78',
    },
    {'flag': '🇱🇾', 'name': 'Libya', 'dial': '+218', 'format': '91 234 5678'},
    {'flag': '🇪🇬', 'name': 'Egypt', 'dial': '+20', 'format': '10 1234 5678'},
    {
      'flag': '🇫🇷',
      'name': 'France',
      'dial': '+33',
      'format': '6 12 34 56 78',
    },
    {
      'flag': '🇧🇪',
      'name': 'Belgium',
      'dial': '+32',
      'format': '470 12 34 56',
    },
    {
      'flag': '🇨🇭',
      'name': 'Switzerland',
      'dial': '+41',
      'format': '76 123 45 67',
    },
    {
      'flag': '🇩🇪',
      'name': 'Germany',
      'dial': '+49',
      'format': '151 12345678',
    },
    {'flag': '🇮🇹', 'name': 'Italy', 'dial': '+39', 'format': '312 345 6789'},
    {'flag': '🇪🇸', 'name': 'Spain', 'dial': '+34', 'format': '612 345 678'},
    {
      'flag': '🇬🇧',
      'name': 'United Kingdom',
      'dial': '+44',
      'format': '7911 123456',
    },
    {
      'flag': '🇳🇱',
      'name': 'Netherlands',
      'dial': '+31',
      'format': '6 12345678',
    },
    {
      'flag': '🇵🇹',
      'name': 'Portugal',
      'dial': '+351',
      'format': '912 345 678',
    },
    {'flag': '🇸🇪', 'name': 'Sweden', 'dial': '+46', 'format': '70 123 45 67'},
    {
      'flag': '🇹🇷',
      'name': 'Turkey',
      'dial': '+90',
      'format': '532 123 45 67',
    },
    {
      'flag': '🇸🇦',
      'name': 'Saudi Arabia',
      'dial': '+966',
      'format': '50 123 4567',
    },
    {
      'flag': '🇦🇪',
      'name': 'United Arab Emirates',
      'dial': '+971',
      'format': '50 123 4567',
    },
    {'flag': '🇶🇦', 'name': 'Qatar', 'dial': '+974', 'format': '3312 3456'},
    {'flag': '🇰🇼', 'name': 'Kuwait', 'dial': '+965', 'format': '5012 3456'},
    {
      'flag': '🇺🇸',
      'name': 'United States',
      'dial': '+1',
      'format': '(555) 123-4567',
    },
    {
      'flag': '🇨🇦',
      'name': 'Canada',
      'dial': '+1',
      'format': '(555) 123-4567',
    },
    {
      'flag': '🇧🇷',
      'name': 'Brazil',
      'dial': '+55',
      'format': '11 91234-5678',
    },
    {
      'flag': '🇦🇺',
      'name': 'Australia',
      'dial': '+61',
      'format': '412 345 678',
    },
    {'flag': '🇯🇵', 'name': 'Japan', 'dial': '+81', 'format': '90 1234 5678'},
    {'flag': '🇨🇳', 'name': 'China', 'dial': '+86', 'format': '131 2345 6789'},
  ];

  @override
  void initState() {
    super.initState();
    _fullnameController = TextEditingController(text: widget.user.fullname);
    _ageController = TextEditingController(
      text: widget.user.age != null ? widget.user.age.toString() : '',
    );
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _selectedCountry = widget.user.paysOrigine;
    _selectedLanguage = widget.user is Touriste
        ? (widget.user as Touriste).languePreferee
        : null;
    // Parse existing phone number to extract dial code
    final existingPhone = widget.user.numTel ?? '';
    String rawPhone = existingPhone;
    for (final c in _countryCodes) {
      if (existingPhone.startsWith(c['dial']!)) {
        _selectedDialCode = c['dial'];
        _selectedFlag = c['flag'];
        _phoneFormat = c['format'];
        rawPhone = existingPhone.substring(c['dial']!.length).trim();
        break;
      }
    }
    _phoneController = TextEditingController(text: rawPhone);
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        print('✅ Image selected: ${image.path}');
        setState(() {
          _selectedImage = File(image.path);
        });

        // Upload immediately
        await _uploadAvatar();
      } else {
        print('❌ No image selected');
      }
    } catch (e) {
      print('❌ Error selecting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    print('📤 Uploading avatar...');
    final result = await UserService.uploadAvatar(_selectedImage!);
    print('📥 Upload result: $result');

    setState(() {
      _isUploadingImage = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Update user object if returned
      if (result['user'] != null) {
        // Optionally: trigger a refresh of the parent screen
      }
    } else {
      String errorMessage = result['message'] ?? 'Failed to upload';

      // Check if backend is not running
      if (errorMessage.contains('FormatException') ||
          errorMessage.contains('DOCTYPE') ||
          errorMessage.contains('Connection') ||
          errorMessage.contains('Failed host lookup')) {
        errorMessage =
            '❌ Backend server not available. Please start the backend.';
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
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select dial code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _countryCodes.length,
                    itemBuilder: (ctx, index) {
                      final c = _countryCodes[index];
                      final isSelected =
                          c['dial'] == _selectedDialCode &&
                          c['flag'] == _selectedFlag;
                      return ListTile(
                        leading: Text(
                          c['flag']!,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(c['name']!),
                        trailing: Text(
                          c['dial']!,
                          style: const TextStyle(
                            color: Color(0xFFFF6B1A),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: const Color(
                          0xFFFF6B1A,
                        ).withOpacity(0.08),
                        onTap: () {
                          setState(() {
                            _selectedDialCode = c['dial'];
                            _selectedFlag = c['flag'];
                            _phoneFormat = c['format'];
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImageSourceDialog() {
    final bool hasPhoto =
        !_avatarDeleted &&
        (_selectedImage != null || widget.user.avatar != null);

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
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title + avatar preview
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
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : !_avatarDeleted && widget.user.avatar != null
                          ? Image.network(
                              widget.user.avatar!,
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
              // Modifier button
              _buildSheetButton(
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
                _buildSheetButton(
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
              _buildSheetButton(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                sublabel: 'Works on real device',
                color: const Color(0xFFFF6B1A),
                bgColor: const Color(0xFFFF6B1A).withOpacity(0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildSheetButton(
                icon: Icons.photo_library_outlined,
                label: 'From gallery',
                sublabel: 'Works everywhere',
                color: const Color(0xFFFF6B1A),
                bgColor: const Color(0xFFFF6B1A).withOpacity(0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetButton({
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
              'Your profile photo will be removed. This will take effect after saving.',
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
                    _deleteAvatar();
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

  Future<void> _deleteAvatar() async {
    setState(() {
      _isUploadingImage = true;
    });

    final result = await UserService.deleteAvatarFromCloud();

    setState(() {
      _isUploadingImage = false;
    });

    if (result['success'] == true) {
      setState(() {
        _selectedImage = null;
        _avatarDeleted = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final updateData = {
      'fullname': _fullnameController.text.trim(),
      if (_ageController.text.isNotEmpty)
        'age': int.tryParse(_ageController.text),
      if (_phoneController.text.isNotEmpty)
        'num_tel':
            '${_selectedDialCode != null ? '${_selectedDialCode!} ' : ''}${_phoneController.text.trim()}',
      if (_phoneController.text.isEmpty) 'num_tel': null,
      if (_bioController.text.isNotEmpty) 'bio': _bioController.text.trim(),
      if (_selectedCountry != null) 'pays_origine': _selectedCountry,
      if (_selectedLanguage != null && widget.user.userType == 'Touriste')
        'langue_preferee': _selectedLanguage,
      if (_avatarDeleted) 'avatar': null,
    };

    final result = await UserService.updateProfile(updateData);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return with success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(
                            color: Color(0xFFFF6B1A).withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _isUploadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : !_avatarDeleted && widget.user.avatar != null
                              ? Image.network(
                                  widget.user.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey[400],
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B1A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_avatarDeleted ||
                    (_selectedImage == null && widget.user.avatar == null)) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tap to add a photo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF6B1A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Full name
                _buildTextField(
                  controller: _fullnameController,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Age
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final age = int.tryParse(value);
                      if (age == null || age < 13 || age > 120) {
                        return 'Invalid age (13-120)';
                      }
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // Phone
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showCountryCodePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedFlag ?? '🌍',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedDialCode ?? '+??',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDialCode != null
                                          ? Colors.black87
                                          : Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: Colors.grey[500],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: _phoneFormat ?? 'Phone number',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Country - Selector
                _buildSelectionField(
                  label: 'Country of origin',
                  icon: Icons.public_outlined,
                  value: _selectedCountry,
                  hint: 'Select a country',
                  onTap: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CountrySelectionScreen(
                          selectedCountry: _selectedCountry,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _selectedCountry = result;
                      });
                    }
                  },
                ),
                SizedBox(height: 20),

                // Preferred language - If Tourist
                if (widget.user.userType == 'Touriste') ...[
                  _buildSelectionField(
                    label: 'Preferred language',
                    icon: Icons.language_outlined,
                    value: _selectedLanguage,
                    hint: 'Select a language',
                    onTap: () async {
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LanguageSelectionScreen(
                            selectedLanguage: _selectedLanguage,
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _selectedLanguage = result;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 20),
                ],

                // Bio
                _buildTextField(
                  controller: _bioController,
                  label: 'Biography',
                  icon: Icons.edit_outlined,
                  maxLines: 4,
                  maxLength: 500,
                ),
                SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Save changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Color(0xFFFF6B1A)),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFFF6B1A), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionField({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFFF6B1A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 15,
                      color: value != null ? Colors.black87 : Colors.grey[500],
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
