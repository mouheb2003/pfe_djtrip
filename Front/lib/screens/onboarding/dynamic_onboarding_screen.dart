import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';
import '../../services/navigation_service.dart';
import '../../services/user_service.dart';
import '../../config/app_routes.dart';

class DynamicOnboardingScreen extends StatefulWidget {
  const DynamicOnboardingScreen({super.key});

  @override
  State<DynamicOnboardingScreen> createState() => _DynamicOnboardingScreenState();
}

class _DynamicOnboardingScreenState extends State<DynamicOnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  int _currentStep = 0;
  List<Map<String, dynamic>> _steps = [];
  Map<String, dynamic> _onboardingData = {};
  bool _isLoading = false;
  bool _isCompleting = false;

  // Form controllers
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _languageController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _languagesController = TextEditingController();
  final _bioController = TextEditingController();
  final _reasonToJoinController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedCountry;
  String? _selectedLanguage;
  String? _selectedPhoneCountry;
  List<String> _selectedActivities = [];
  List<String> _selectedLanguages = [];
  List<String> _selectedInterests = [];
  String? _coverPhotoUrl;
  String? _profilePhotoUrl;
  bool _isUploadingProfilePhoto = false;
  bool _isUploadingCoverPhoto = false;

  @override
  void initState() {
    super.initState();
    
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // Add listener for instant phone number validation
    _phoneController.addListener(() {
      setState(() {
        // Trigger rebuild to update Next button state
      });
    });
    
    _loadOnboardingData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _languageController.dispose();
    _activitiesController.dispose();
    _languagesController.dispose();
    _bioController.dispose();
    _reasonToJoinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadOnboardingData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await AuthService.getUser();
      final userType = user?['userType'] ?? 'Touriste';
      
      setState(() {
        _steps = OnboardingService.getOnboardingSteps(userType);
        _isLoading = false;
      });
      
      _progressController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading onboarding: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentStep = page);
  }

  Future<void> _showImagePickerProfile() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E225E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      _buildPhotoOption(
                        icon: Icons.camera_alt,
                        title: 'Take Photo',
                        subtitle: 'Use camera to take a new photo',
                        onTap: () {
                          Navigator.of(context).pop();
                          _pickProfilePictureFromCamera();
                        },
                      ),
                      Container(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      _buildPhotoOption(
                        icon: Icons.photo_library,
                        title: 'Choose from Gallery',
                        subtitle: 'Select an existing photo from your gallery',
                        onTap: () {
                          Navigator.of(context).pop();
                          _pickProfilePictureFromGallery();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Color(0xFF6C757D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4B63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4B63FF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E225E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C757D),
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

  Future<void> _pickProfilePictureFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.lightImpact();
        
        // Upload to Cloudinary immediately
        setState(() => _isUploadingProfilePhoto = true);
        
        try {
          final success = await UserService.updateAvatar(File(image.path));
          if (success && mounted) {
            setState(() {
              _onboardingData['avatar'] = image.path;
              _profilePhotoUrl = image.path;
              _isUploadingProfilePhoto = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo uploaded successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingProfilePhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload profile photo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  Future<void> _pickProfilePictureFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.lightImpact();
        
        // Upload to Cloudinary immediately
        setState(() => _isUploadingProfilePhoto = true);
        
        try {
          final success = await UserService.updateAvatar(File(image.path));
          if (success && mounted) {
            setState(() {
              _onboardingData['avatar'] = image.path;
              _profilePhotoUrl = image.path;
              _isUploadingProfilePhoto = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo uploaded successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingProfilePhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload profile photo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  Future<void> _showImagePickerCover() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Cover Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E225E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      _buildPhotoOption(
                        icon: Icons.camera_alt,
                        title: 'Take Photo',
                        subtitle: 'Use camera to take a new photo',
                        onTap: () {
                          Navigator.of(context).pop();
                          _pickCoverPhotoFromCamera();
                        },
                      ),
                      Container(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      _buildPhotoOption(
                        icon: Icons.photo_library,
                        title: 'Choose from Gallery',
                        subtitle: 'Select an existing photo from your gallery',
                        onTap: () {
                          Navigator.of(context).pop();
                          _pickCoverPhotoFromGallery();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Color(0xFF6C757D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCoverPhotoFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.lightImpact();
        
        // Upload to Cloudinary immediately
        setState(() => _isUploadingCoverPhoto = true);
        
        try {
          final success = await UserService.updateCoverPhoto(File(image.path));
          if (success && mounted) {
            setState(() {
              _onboardingData['cover_photo'] = image.path;
              _coverPhotoUrl = image.path;
              _isUploadingCoverPhoto = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cover photo uploaded successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingCoverPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload cover photo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  Future<void> _pickCoverPhotoFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.lightImpact();
        
        // Upload to Cloudinary immediately
        setState(() => _isUploadingCoverPhoto = true);
        
        try {
          final success = await UserService.updateCoverPhoto(File(image.path));
          if (success && mounted) {
            setState(() {
              _onboardingData['cover_photo'] = image.path;
              _coverPhotoUrl = image.path;
              _isUploadingCoverPhoto = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cover photo uploaded successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingCoverPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload cover photo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking cover photo: $e'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  
  bool _validateStep(int index) {
    final step = _steps[index];
    final stepId = step['id'] as String;
    
    // Profile picture and cover photo are optional - can skip
    if (stepId == 'profile_picture' || stepId == 'cover_photo') {
      return true;
    }
    
    // Validate based on step type using current input values
    switch (stepId) {
      case 'phone':
        if (_phoneController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter your phone number for ${step['title']}'),
              backgroundColor: const Color(0xFFFFA502),
            ),
          );
          return false;
        }
        
        // Validate phone number format
        if (_selectedPhoneCountry != null) {
          final phoneCountries = [
            {'name': 'France', 'code': '+33', 'flag': '🇫🇷', 'pattern': r'^\d{9}$', 'example': '612345678'},
            {'name': 'United States', 'code': '+1', 'flag': '🇺🇸', 'pattern': r'^\d{10}$', 'example': '2345678901'},
            {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧', 'pattern': r'^\d{10,11}$', 'example': '7123456789'},
            {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪', 'pattern': r'^\d{10,11}$', 'example': '1512345678'},
            {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸', 'pattern': r'^\d{9}$', 'example': '612345678'},
            {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹', 'pattern': r'^\d{10}$', 'example': '3123456789'},
            {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦', 'pattern': r'^\d{10}$', 'example': '4161234567'},
            {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺', 'pattern': r'^\d{9}$', 'example': '412345678'},
            {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵', 'pattern': r'^\d{10,11}$', 'example': '9012345678'},
            {'name': 'China', 'code': '+86', 'flag': '🇨🇳', 'pattern': r'^\d{11}$', 'example': '1312345678'},
            {'name': 'India', 'code': '+91', 'flag': '🇮🇳', 'pattern': r'^\d{10}$', 'example': '9876543210'},
            {'name': 'Brazil', 'code': '+55', 'flag': '🇧🇷', 'pattern': r'^\d{10,11}$', 'example': '11912345678'},
            {'name': 'Mexico', 'code': '+52', 'flag': '🇲🇽', 'pattern': r'^\d{10}$', 'example': '5512345678'},
            {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷', 'pattern': r'^\d{10}$', 'example': '1112345678'},
            {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷', 'pattern': r'^\d{10,11}$', 'example': '1012345678'},
            {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱', 'pattern': r'^\d{9}$', 'example': '612345678'},
            {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪', 'pattern': r'^\d{9}$', 'example': '412345678'},
            {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭', 'pattern': r'^\d{9}$', 'example': '791234567'},
            {'name': 'Sweden', 'code': '+46', 'flag': '🇸🇪', 'pattern': r'^\d{9}$', 'example': '712345678'},
            {'name': 'Norway', 'code': '+47', 'flag': '🇳🇴', 'pattern': r'^\d{8}$', 'example': '41234567'},
            {'name': 'Denmark', 'code': '+45', 'flag': '🇩🇰', 'pattern': r'^\d{8}$', 'example': '12345678'},
            {'name': 'Finland', 'code': '+358', 'flag': '🇫🇮', 'pattern': r'^\d{9,10}$', 'example': '412345678'},
            {'name': 'Poland', 'code': '+48', 'flag': '🇵🇱', 'pattern': r'^\d{9}$', 'example': '512345678'},
            {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺', 'pattern': r'^\d{10}$', 'example': '9123456789'},
            {'name': 'Turkey', 'code': '+90', 'flag': '🇹🇷', 'pattern': r'^\d{10}$', 'example': '5123456789'},
            {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬', 'pattern': r'^\d{10}$', 'example': '1012345678'},
            {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦', 'pattern': r'^\d{9}$', 'example': '812345678'},
            {'name': 'Morocco', 'code': '+212', 'flag': '🇲🇦', 'pattern': r'^\d{9}$', 'example': '612345678'},
            {'name': 'Tunisia', 'code': '+216', 'flag': '🇹🇳', 'pattern': r'^\d{8}$', 'example': '51234567'},
            {'name': 'Algeria', 'code': '+213', 'flag': '🇩🇿', 'pattern': r'^\d{9}$', 'example': '512345678'},
            {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦', 'pattern': r'^\d{9}$', 'example': '501234567'},
            {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'pattern': r'^\d{9}$', 'example': '501234567'},
            {'name': 'Israel', 'code': '+972', 'flag': '🇮🇱', 'pattern': r'^\d{9}$', 'example': '501234567'},
            {'name': 'Thailand', 'code': '+66', 'flag': '🇹🇭', 'pattern': r'^\d{9}$', 'example': '812345678'},
            {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬', 'pattern': r'^\d{8}$', 'example': '81234567'},
            {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾', 'pattern': r'^\d{9,10}$', 'example': '123456789'},
            {'name': 'Indonesia', 'code': '+62', 'flag': '🇮🇩', 'pattern': r'^\d{9,12}$', 'example': '812345678'},
            {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭', 'pattern': r'^\d{10}$', 'example': '9123456789'},
            {'name': 'New Zealand', 'code': '+64', 'flag': '🇳🇿', 'pattern': r'^\d{9}$', 'example': '212345678'},
          ];
          
          final selectedCountry = phoneCountries.firstWhere(
            (country) => country['name'] == _selectedPhoneCountry,
            orElse: () => phoneCountries.first,
          );
          
          final pattern = selectedCountry['pattern'] as String;
          final regex = RegExp(pattern);
          
          if (!regex.hasMatch(_phoneController.text.trim())) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid phone number format for ${selectedCountry['name']}. Example: ${selectedCountry['example']}'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }
        break;
      case 'country':
        if (_selectedCountry == null || _selectedCountry!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select your country'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'language':
        if (_selectedLanguage == null || _selectedLanguage!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select your preferred language'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'specialized_activities':
        if (_selectedActivities.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one activity'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'spoken_languages':
        if (_selectedLanguages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one language'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'interests':
        if (_selectedInterests.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one interest'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'organizer_bio':
      case 'tourist_bio':
        final bio = _bioController.text.trim();
        if (bio.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please provide your bio'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        final minLength = stepId == 'organizer_bio' ? 50 : 30;
        if (bio.length < minLength) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please provide at least $minLength characters for your bio'),
              backgroundColor: const Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      case 'reason_to_join':
        final reason = _reasonToJoinController.text.trim();
        if (reason.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please provide your reason to join'),
              backgroundColor: Color(0xFFFFA502),
            ),
          );
          return false;
        }
        break;
      default:
        return true;
    }
    
    return true;
  }

  Future<Map<String, dynamic>> _getStepData(int index) async {
    final step = _steps[index];
    final stepId = step['id'] as String;
    
    Map<String, dynamic> stepData = {};
    
    switch (stepId) {
      case 'phone':
        final phoneCountries = [
          {'name': 'France', 'code': '+33', 'flag': '🇫🇷', 'pattern': r'^\d{9}$', 'example': '612345678'},
          {'name': 'United States', 'code': '+1', 'flag': '🇺🇸', 'pattern': r'^\d{10}$', 'example': '2345678901'},
          {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧', 'pattern': r'^\d{10,11}$', 'example': '7123456789'},
          {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪', 'pattern': r'^\d{10,11}$', 'example': '1512345678'},
          {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸', 'pattern': r'^\d{9}$', 'example': '612345678'},
          {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹', 'pattern': r'^\d{10}$', 'example': '3123456789'},
          {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦', 'pattern': r'^\d{10}$', 'example': '4161234567'},
          {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺', 'pattern': r'^\d{9}$', 'example': '412345678'},
          {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵', 'pattern': r'^\d{10,11}$', 'example': '9012345678'},
          {'name': 'China', 'code': '+86', 'flag': '🇨🇳', 'pattern': r'^\d{11}$', 'example': '1312345678'},
          {'name': 'India', 'code': '+91', 'flag': '🇮🇳', 'pattern': r'^\d{10}$', 'example': '9876543210'},
          {'name': 'Brazil', 'code': '+55', 'flag': '🇧🇷', 'pattern': r'^\d{10,11}$', 'example': '11912345678'},
          {'name': 'Mexico', 'code': '+52', 'flag': '🇲🇽', 'pattern': r'^\d{10}$', 'example': '5512345678'},
          {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷', 'pattern': r'^\d{10}$', 'example': '1112345678'},
          {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷', 'pattern': r'^\d{10,11}$', 'example': '1012345678'},
          {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱', 'pattern': r'^\d{9}$', 'example': '612345678'},
          {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪', 'pattern': r'^\d{9}$', 'example': '412345678'},
          {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭', 'pattern': r'^\d{9}$', 'example': '791234567'},
          {'name': 'Sweden', 'code': '+46', 'flag': '🇸🇪', 'pattern': r'^\d{9}$', 'example': '712345678'},
          {'name': 'Norway', 'code': '+47', 'flag': '🇳🇴', 'pattern': r'^\d{8}$', 'example': '41234567'},
          {'name': 'Denmark', 'code': '+45', 'flag': '🇩🇰', 'pattern': r'^\d{8}$', 'example': '12345678'},
          {'name': 'Finland', 'code': '+358', 'flag': '🇫🇮', 'pattern': r'^\d{9,10}$', 'example': '412345678'},
          {'name': 'Poland', 'code': '+48', 'flag': '🇵🇱', 'pattern': r'^\d{9}$', 'example': '512345678'},
          {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺', 'pattern': r'^\d{10}$', 'example': '9123456789'},
          {'name': 'Turkey', 'code': '+90', 'flag': '🇹🇷', 'pattern': r'^\d{10}$', 'example': '5123456789'},
          {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬', 'pattern': r'^\d{10}$', 'example': '1012345678'},
          {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦', 'pattern': r'^\d{9}$', 'example': '812345678'},
          {'name': 'Morocco', 'code': '+212', 'flag': '🇲🇦', 'pattern': r'^\d{9}$', 'example': '612345678'},
          {'name': 'Tunisia', 'code': '+216', 'flag': '🇹🇳', 'pattern': r'^\d{8}$', 'example': '51234567'},
          {'name': 'Algeria', 'code': '+213', 'flag': '🇩🇿', 'pattern': r'^\d{9}$', 'example': '512345678'},
          {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦', 'pattern': r'^\d{9}$', 'example': '501234567'},
          {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'pattern': r'^\d{9}$', 'example': '501234567'},
          {'name': 'Israel', 'code': '+972', 'flag': '🇮🇱', 'pattern': r'^\d{9}$', 'example': '501234567'},
          {'name': 'Thailand', 'code': '+66', 'flag': '🇹🇭', 'pattern': r'^\d{9}$', 'example': '812345678'},
          {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬', 'pattern': r'^\d{8}$', 'example': '81234567'},
          {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾', 'pattern': r'^\d{9,10}$', 'example': '123456789'},
          {'name': 'Indonesia', 'code': '+62', 'flag': '🇮🇩', 'pattern': r'^\d{9,12}$', 'example': '812345678'},
          {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭', 'pattern': r'^\d{10}$', 'example': '9123456789'},
          {'name': 'New Zealand', 'code': '+64', 'flag': '🇳🇿', 'pattern': r'^\d{9}$', 'example': '212345678'},
        ];
        
        final selectedPhoneCountry = phoneCountries.firstWhere(
          (country) => country['name'] == _selectedPhoneCountry,
          orElse: () => phoneCountries.first,
        );
        
        stepData = {
          'num_tel': '${selectedPhoneCountry['code']}${_phoneController.text.trim()}',
          'pays_telephone': selectedPhoneCountry['name'],
        };
        break;
      case 'profile_picture':
        stepData = {'avatar': _onboardingData['avatar']};
        break;
      case 'cover_photo':
        stepData = {'cover_photo': _onboardingData['cover_photo']};
        break;
      case 'country':
        stepData = {'pays_origine': _selectedCountry ?? ''};
        break;
      case 'language':
        stepData = {'langue_preferee': _selectedLanguage ?? ''};
        break;
      case 'specialized_activities':
        stepData = {'specialites_activites': _selectedActivities};
        break;
      case 'spoken_languages':
        stepData = {'langues_proposees': _selectedLanguages};
        break;
      case 'organizer_bio':
      case 'tourist_bio':
        stepData = {'bio': _bioController.text.trim()};
        break;
      case 'reason_to_join':
        stepData = {'reasonToJoin': _reasonToJoinController.text.trim()};
        break;
      case 'interests':
        stepData = {'centres_interet': _selectedInterests};
        break;
    }
    return stepData;
  }

  Future<void> _submitAll() async {
    HapticFeedback.heavyImpact();
    FocusScope.of(context).unfocus();

    // 1. Validate all steps
    for (int i = 0; i < _steps.length; i++) {
      if (!_validateStep(i)) return;
    }

    setState(() => _isCompleting = true);

    try {
      // 2. Save all steps data
      for (int i = 0; i < _steps.length; i++) {
        final stepData = await _getStepData(i);
        if (stepData.isNotEmpty) {
          final result = await OnboardingService.updateOnboardingStep(stepData);
          if (!result['success']) {
            throw Exception(result['message'] ?? 'Failed to save ${ _steps[i]['title']}');
          }
        }
      }

      // 3. Complete onboarding
      await _completeOnboarding();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isCompleting = false);
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final result = await OnboardingService.completeOnboarding();
      if (!mounted) return;

      if (result['success'] == true) {
        // Navigate to the appropriate home screen
        await OnboardingService.navigateToAppropriateScreen();
      } else {
        throw Exception(result['message'] ?? 'Failed to complete onboarding');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E225E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill in the information below to get started with DJTrip',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    for (int i = 0; i < _steps.length; i++) ...[
                      _buildStepPage(_steps[i]),
                      if (i < _steps.length - 1) 
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
                          child: Divider(color: Colors.grey.shade200, thickness: 1),
                        ),
                    ],
                    const SizedBox(height: 20),
                    // Bottom Button inside the scroll view or pinned at bottom? 
                    // User said "dans une screen scrollable", usually includes the button at the end.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isCompleting ? null : _submitAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: _isCompleting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Saving Profile...'),
                                  ],
                                )
                              : const Text(
                                  'Complete Profile',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildStepPage(Map<String, dynamic> step) {
    final stepId = step['id'] as String;
    
    switch (stepId) {
      case 'phone':
        return _buildPhoneStep(step);
      case 'profile_picture':
        return _buildProfilePictureStep(step);
      case 'cover_photo':
        return _buildCoverPhotoStep(step);
      case 'country':
        return _buildCountryStep(step);
      case 'language':
        return _buildLanguageStep(step);
      case 'specialized_activities':
        return _buildActivitiesStep(step);
      case 'spoken_languages':
        return _buildLanguagesStep(step);
      case 'organizer_bio':
        return _buildOrganizerBioStep(step);
      case 'tourist_bio':
        return _buildTouristBioStep(step);
      case 'reason_to_join':
        return _buildReasonToJoinStep(step);
      case 'interests':
        return _buildInterestsStep(step);
      default:
        return _buildDefaultStep(step);
    }
  }

  Widget _buildInterestsStep(Map<String, dynamic> step) {
    final interests = [
      {'name': 'Adventure', 'icon': Icons.hiking},
      {'name': 'Culture', 'icon': Icons.museum},
      {'name': 'Food & Dining', 'icon': Icons.restaurant},
      {'name': 'Nature', 'icon': Icons.park},
      {'name': 'History', 'icon': Icons.history_edu},
      {'name': 'Photography', 'icon': Icons.camera_alt},
      {'name': 'Shopping', 'icon': Icons.shopping_bag},
      {'name': 'Nightlife', 'icon': Icons.nightlife},
      {'name': 'Beach', 'icon': Icons.beach_access},
      {'name': 'Sports', 'icon': Icons.sports_soccer},
      {'name': 'Wellness', 'icon': Icons.spa},
      {'name': 'Art', 'icon': Icons.palette},
      {'name': 'Music', 'icon': Icons.music_note},
      {'name': 'Architecture', 'icon': Icons.apartment},
      {'name': 'Wildlife', 'icon': Icons.pets},
      {'name': 'Festivals', 'icon': Icons.celebration},
      {'name': 'Local Life', 'icon': Icons.location_city},
      {'name': 'Spiritual', 'icon': Icons.self_improvement},
      {'name': 'Family', 'icon': Icons.family_restroom},
      {'name': 'Romance', 'icon': Icons.favorite},
      {'name': 'Education', 'icon': Icons.school},
      {'name': 'Technology', 'icon': Icons.computer},
      {'name': 'Transport', 'icon': Icons.directions_car},
      {'name': 'Boating', 'icon': Icons.sailing},
      {'name': 'Camping', 'icon': Icons.cabin},
      {'name': 'Winter Sports', 'icon': Icons.ac_unit},
      {'name': 'Cycling', 'icon': Icons.directions_bike},
      {'name': 'Running', 'icon': Icons.directions_run},
      {'name': 'Swimming', 'icon': Icons.pool},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: interests.map((interest) {
              final isSelected = _selectedInterests.contains(interest['name'] as String);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      interest['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF4B63FF),
                    ),
                    const SizedBox(width: 6),
                    Text(interest['name'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest['name'] as String);
                    } else {
                      _selectedInterests.remove(interest['name'] as String);
                    }
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF4B63FF),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E225E),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4B63FF) : const Color(0xFFE1E4E8),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Selected: ${_selectedInterests.length}',
            style: const TextStyle(
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(Map<String, dynamic> step) {
    final phoneCountries = [
      {'name': 'France', 'code': '+33', 'flag': '🇫🇷', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'United States', 'code': '+1', 'flag': '🇺🇸', 'pattern': r'^\d{10}$', 'example': '2345678901'},
      {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧', 'pattern': r'^\d{10,11}$', 'example': '7123456789'},
      {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪', 'pattern': r'^\d{10,11}$', 'example': '1512345678'},
      {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹', 'pattern': r'^\d{10}$', 'example': '3123456789'},
      {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦', 'pattern': r'^\d{10}$', 'example': '4161234567'},
      {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺', 'pattern': r'^\d{9}$', 'example': '412345678'},
      {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵', 'pattern': r'^\d{10,11}$', 'example': '9012345678'},
      {'name': 'China', 'code': '+86', 'flag': '🇨🇳', 'pattern': r'^\d{11}$', 'example': '1312345678'},
      {'name': 'India', 'code': '+91', 'flag': '🇮🇳', 'pattern': r'^\d{10}$', 'example': '9876543210'},
      {'name': 'Brazil', 'code': '+55', 'flag': '🇧🇷', 'pattern': r'^\d{10,11}$', 'example': '11912345678'},
      {'name': 'Mexico', 'code': '+52', 'flag': '🇲🇽', 'pattern': r'^\d{10}$', 'example': '5512345678'},
      {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷', 'pattern': r'^\d{10}$', 'example': '1112345678'},
      {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷', 'pattern': r'^\d{10,11}$', 'example': '1012345678'},
      {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪', 'pattern': r'^\d{9}$', 'example': '412345678'},
      {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭', 'pattern': r'^\d{9}$', 'example': '791234567'},
      {'name': 'Sweden', 'code': '+46', 'flag': '🇸🇪', 'pattern': r'^\d{9}$', 'example': '712345678'},
      {'name': 'Norway', 'code': '+47', 'flag': '🇳🇴', 'pattern': r'^\d{8}$', 'example': '41234567'},
      {'name': 'Denmark', 'code': '+45', 'flag': '🇩🇰', 'pattern': r'^\d{8}$', 'example': '12345678'},
      {'name': 'Finland', 'code': '+358', 'flag': '🇫🇮', 'pattern': r'^\d{9,10}$', 'example': '412345678'},
      {'name': 'Poland', 'code': '+48', 'flag': '🇵🇱', 'pattern': r'^\d{9}$', 'example': '512345678'},
      {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺', 'pattern': r'^\d{10}$', 'example': '9123456789'},
      {'name': 'Turkey', 'code': '+90', 'flag': '🇹🇷', 'pattern': r'^\d{10}$', 'example': '5123456789'},
      {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬', 'pattern': r'^\d{10}$', 'example': '1012345678'},
      {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦', 'pattern': r'^\d{9}$', 'example': '812345678'},
      {'name': 'Morocco', 'code': '+212', 'flag': '🇲🇦', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Tunisia', 'code': '+216', 'flag': '🇹🇳', 'pattern': r'^\d{8}$', 'example': '51234567'},
      {'name': 'Algeria', 'code': '+213', 'flag': '🇩🇿', 'pattern': r'^\d{9}$', 'example': '512345678'},
      {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'Israel', 'code': '+972', 'flag': '🇮🇱', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'Thailand', 'code': '+66', 'flag': '🇹🇭', 'pattern': r'^\d{9}$', 'example': '812345678'},
      {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬', 'pattern': r'^\d{8}$', 'example': '81234567'},
      {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾', 'pattern': r'^\d{9,10}$', 'example': '123456789'},
      {'name': 'Indonesia', 'code': '+62', 'flag': '🇮🇩', 'pattern': r'^\d{9,12}$', 'example': '812345678'},
      {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭', 'pattern': r'^\d{10}$', 'example': '9123456789'},
      {'name': 'New Zealand', 'code': '+64', 'flag': '🇳🇿', 'pattern': r'^\d{9}$', 'example': '212345678'},
    ];

    final selectedCountry = phoneCountries.firstWhere(
      (country) => country['name'] == _selectedPhoneCountry,
      orElse: () => phoneCountries.first,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              // Country Code Selector
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedPhoneCountry,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4B63FF)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: phoneCountries.map((country) {
                    return DropdownMenuItem<String>(
                      value: country['name'] as String,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            country['flag'] as String,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              country['code'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedPhoneCountry = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Phone Number Input
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: selectedCountry['example'] as String,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4B63FF)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    errorText: _validatePhoneNumber(selectedCountry['pattern'] as String),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Format: ${selectedCountry['example']} (${selectedCountry['code']})',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String? _validatePhoneNumber(String pattern) {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return null;
    
    final regex = RegExp(pattern);
    if (!regex.hasMatch(phoneNumber)) {
      return 'Invalid phone number format';
    }
    
    return null;
  }

  bool _isPhoneNumberValid() {
    final step = _steps[_currentStep];
    // Only validate phone number format for phone step, allow all other steps
    if (step['id'] != 'phone') return true;
    
    final phoneNumber = _phoneController.text.trim();
    // Allow empty phone number (user can skip)
    if (phoneNumber.isEmpty) return true;
    
    // Get selected phone country info
    final phoneCountries = [
      {'name': 'France', 'code': '+33', 'flag': '🇫🇷', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'United States', 'code': '+1', 'flag': '🇺🇸', 'pattern': r'^\d{10}$', 'example': '2345678901'},
      {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧', 'pattern': r'^\d{10,11}$', 'example': '7123456789'},
      {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪', 'pattern': r'^\d{10,11}$', 'example': '1512345678'},
      {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹', 'pattern': r'^\d{10}$', 'example': '3123456789'},
      {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦', 'pattern': r'^\d{10}$', 'example': '4161234567'},
      {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺', 'pattern': r'^\d{9}$', 'example': '412345678'},
      {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵', 'pattern': r'^\d{10,11}$', 'example': '9012345678'},
      {'name': 'China', 'code': '+86', 'flag': '🇨🇳', 'pattern': r'^\d{11}$', 'example': '1312345678'},
      {'name': 'India', 'code': '+91', 'flag': '🇮🇳', 'pattern': r'^\d{10}$', 'example': '9876543210'},
      {'name': 'Brazil', 'code': '+55', 'flag': '🇧🇷', 'pattern': r'^\d{10,11}$', 'example': '11912345678'},
      {'name': 'Mexico', 'code': '+52', 'flag': '🇲🇽', 'pattern': r'^\d{10}$', 'example': '5512345678'},
      {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷', 'pattern': r'^\d{10}$', 'example': '1112345678'},
      {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷', 'pattern': r'^\d{10,11}$', 'example': '1012345678'},
      {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪', 'pattern': r'^\d{9}$', 'example': '412345678'},
      {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭', 'pattern': r'^\d{9}$', 'example': '791234567'},
      {'name': 'Sweden', 'code': '+46', 'flag': '🇸🇪', 'pattern': r'^\d{9}$', 'example': '712345678'},
      {'name': 'Norway', 'code': '+47', 'flag': '🇳🇴', 'pattern': r'^\d{8}$', 'example': '41234567'},
      {'name': 'Denmark', 'code': '+45', 'flag': '🇩🇰', 'pattern': r'^\d{8}$', 'example': '12345678'},
      {'name': 'Finland', 'code': '+358', 'flag': '🇫🇮', 'pattern': r'^\d{9,10}$', 'example': '412345678'},
      {'name': 'Poland', 'code': '+48', 'flag': '🇵🇱', 'pattern': r'^\d{9}$', 'example': '512345678'},
      {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺', 'pattern': r'^\d{10}$', 'example': '9123456789'},
      {'name': 'Turkey', 'code': '+90', 'flag': '🇹🇷', 'pattern': r'^\d{10}$', 'example': '5123456789'},
      {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬', 'pattern': r'^\d{10}$', 'example': '1012345678'},
      {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦', 'pattern': r'^\d{9}$', 'example': '812345678'},
      {'name': 'Morocco', 'code': '+212', 'flag': '🇲🇦', 'pattern': r'^\d{9}$', 'example': '612345678'},
      {'name': 'Tunisia', 'code': '+216', 'flag': '🇹🇳', 'pattern': r'^\d{8}$', 'example': '51234567'},
      {'name': 'Algeria', 'code': '+213', 'flag': '🇩🇿', 'pattern': r'^\d{9}$', 'example': '512345678'},
      {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'Israel', 'code': '+972', 'flag': '🇮🇱', 'pattern': r'^\d{9}$', 'example': '501234567'},
      {'name': 'Thailand', 'code': '+66', 'flag': '🇹🇭', 'pattern': r'^\d{9}$', 'example': '812345678'},
      {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬', 'pattern': r'^\d{8}$', 'example': '81234567'},
      {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾', 'pattern': r'^\d{9,10}$', 'example': '123456789'},
      {'name': 'Indonesia', 'code': '+62', 'flag': '🇮🇩', 'pattern': r'^\d{9,12}$', 'example': '812345678'},
      {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭', 'pattern': r'^\d{10}$', 'example': '9123456789'},
      {'name': 'New Zealand', 'code': '+64', 'flag': '🇳🇿', 'pattern': r'^\d{9}$', 'example': '212345678'},
    ];
    
    final selectedPhoneCountry = phoneCountries.firstWhere(
      (country) => country['name'] == _selectedPhoneCountry,
      orElse: () => phoneCountries.first,
    );
    
    final pattern = selectedPhoneCountry['pattern'] as String;
    final regex = RegExp(pattern);
    
    // If phone number is entered, it must match the pattern
    // If empty, allow to proceed (user can skip)
    return regex.hasMatch(phoneNumber);
  }

  Widget _buildProfilePictureStep(Map<String, dynamic> step) {
    final hasImage = _onboardingData['avatar'] != null;
    final isLastStep = _currentStep == _steps.length - 1;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: GestureDetector(
              onTap: _showImagePickerProfile,
              child: Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(72),
                  border: Border.all(
                    color: const Color(0xFF4B63FF),
                    width: 2,
                  ),
                ),
                child: hasImage
                    ? _isUploadingProfilePhoto
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF00B894),
                              ),
                            ),
                          )
                        : FutureBuilder<bool>(
                            future: File(_onboardingData['avatar']).exists(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasData && snapshot.data == true) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(70),
                                  child: Image.file(
                                    File(_onboardingData['avatar']),
                                    width: 144,
                                    height: 144,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultAvatar();
                                    },
                                  ),
                                );
                              }
                              return _buildDefaultAvatar();
                            },
                          )
                    : _buildDefaultAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              hasImage ? 'Photo selected ✓' : 'No photo selected',
              style: TextStyle(
                fontSize: 14,
                color: hasImage ? const Color(0xFF00B894) : const Color(0xFF6C757D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B63FF), Color(0xFF3A54E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(72),
      ),
      child: const Icon(
        Icons.camera_alt,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCoverPhotoStep(Map<String, dynamic> step) {
    final hasImage = _onboardingData['cover_photo'] != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: _showImagePickerCover,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4B63FF),
                    width: 2,
                  ),
                ),
                child: hasImage
                    ? _isUploadingCoverPhoto
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF00B894),
                              ),
                            ),
                          )
                        : FutureBuilder<bool>(
                            future: File(_onboardingData['cover_photo']).exists(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasData && snapshot.data == true) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(_onboardingData['cover_photo']),
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultCoverPhoto();
                                    },
                                  ),
                                );
                              }
                              return _buildDefaultCoverPhoto();
                            },
                          )
                    : _buildDefaultCoverPhoto(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _showImagePickerCover,
              child: const Text(
                'Choose Cover Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B63FF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              hasImage ? 'Cover photo selected ✓' : 'No cover photo selected',
              style: TextStyle(
                fontSize: 14,
                color: hasImage ? const Color(0xFF00B894) : const Color(0xFF6C757D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCoverPhoto() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B63FF), Color(0xFF3A54E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library,
            size: 48,
            color: Colors.white,
          ),
          SizedBox(height: 12),
          Text(
            'Tap to add cover photo',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Recommended: 1200x400',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryStep(Map<String, dynamic> step) {
    final countries = [
      {'name': 'France', 'flag': '🇫🇷'},
      {'name': 'United States', 'flag': '🇺🇸'},
      {'name': 'United Kingdom', 'flag': '🇬🇧'},
      {'name': 'Germany', 'flag': '🇩🇪'},
      {'name': 'Spain', 'flag': '🇪🇸'},
      {'name': 'Italy', 'flag': '🇮🇹'},
      {'name': 'Canada', 'flag': '🇨🇦'},
      {'name': 'Australia', 'flag': '🇦🇺'},
      {'name': 'Japan', 'flag': '🇯🇵'},
      {'name': 'China', 'flag': '🇨🇳'},
      {'name': 'India', 'flag': '🇮🇳'},
      {'name': 'Brazil', 'flag': '🇧🇷'},
      {'name': 'Mexico', 'flag': '🇲🇽'},
      {'name': 'Argentina', 'flag': '🇦🇷'},
      {'name': 'South Korea', 'flag': '🇰🇷'},
      {'name': 'Netherlands', 'flag': '🇳🇱'},
      {'name': 'Belgium', 'flag': '🇧🇪'},
      {'name': 'Switzerland', 'flag': '🇨🇭'},
      {'name': 'Sweden', 'flag': '🇸🇪'},
      {'name': 'Norway', 'flag': '🇳🇴'},
      {'name': 'Denmark', 'flag': '🇩🇰'},
      {'name': 'Finland', 'flag': '🇫🇮'},
      {'name': 'Poland', 'flag': '🇵🇱'},
      {'name': 'Russia', 'flag': '🇷🇺'},
      {'name': 'Turkey', 'flag': '🇹🇷'},
      {'name': 'Egypt', 'flag': '🇪🇬'},
      {'name': 'South Africa', 'flag': '🇿🇦'},
      {'name': 'Morocco', 'flag': '🇲🇦'},
      {'name': 'Tunisia', 'flag': '🇹🇳'},
      {'name': 'Algeria', 'flag': '🇩🇿'},
      {'name': 'Saudi Arabia', 'flag': '🇸🇦'},
      {'name': 'UAE', 'flag': '🇦🇪'},
      {'name': 'Israel', 'flag': '🇮🇱'},
      {'name': 'Thailand', 'flag': '🇹🇭'},
      {'name': 'Singapore', 'flag': '🇸🇬'},
      {'name': 'Malaysia', 'flag': '🇲🇾'},
      {'name': 'Indonesia', 'flag': '🇮🇩'},
      {'name': 'Philippines', 'flag': '🇵🇭'},
      {'name': 'New Zealand', 'flag': '🇳🇿'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4B63FF)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            items: countries.map((country) {
              return DropdownMenuItem<String>(
                value: country['name'] as String,
                child: Row(
                  children: [
                    Text(
                      country['flag'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      country['name'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCountry = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageStep(Map<String, dynamic> step) {
    final languages = [
      {'name': 'English', 'flag': '🇬🇧', 'code': 'en'},
      {'name': 'Français', 'flag': '🇫🇷', 'code': 'fr'},
      {'name': 'Español', 'flag': '🇪🇸', 'code': 'es'},
      {'name': 'Deutsch', 'flag': '🇩🇪', 'code': 'de'},
      {'name': 'Italiano', 'flag': '🇮🇹', 'code': 'it'},
      {'name': 'Português', 'flag': '🇵🇹', 'code': 'pt'},
      {'name': '中文', 'flag': '🇨🇳', 'code': 'zh'},
      {'name': '日本語', 'flag': '🇯🇵', 'code': 'ja'},
      {'name': '한국어', 'flag': '🇰🇷', 'code': 'ko'},
      {'name': 'العربية', 'flag': '🇸🇦', 'code': 'ar'},
      {'name': 'Русский', 'flag': '🇷🇺', 'code': 'ru'},
      {'name': 'हिन्दी', 'flag': '🇮🇳', 'code': 'hi'},
      {'name': 'Nederlands', 'flag': '🇳🇱', 'code': 'nl'},
      {'name': 'Polski', 'flag': '🇵🇱', 'code': 'pl'},
      {'name': 'Türkçe', 'flag': '🇹🇷', 'code': 'tr'},
      {'name': 'Svenska', 'flag': '🇸🇪', 'code': 'sv'},
      {'name': 'Norsk', 'flag': '🇳🇴', 'code': 'no'},
      {'name': 'Dansk', 'flag': '🇩🇰', 'code': 'da'},
      {'name': 'Suomi', 'flag': '🇫🇮', 'code': 'fi'},
      {'name': 'Ελληνικά', 'flag': '🇬🇷', 'code': 'el'},
      {'name': 'Magyar', 'flag': '🇭🇺', 'code': 'hu'},
      {'name': 'Čeština', 'flag': '🇨🇿', 'code': 'cs'},
      {'name': 'Română', 'flag': '🇷🇴', 'code': 'ro'},
      {'name': 'Български', 'flag': '🇧🇬', 'code': 'bg'},
      {'name': 'Українська', 'flag': '🇺🇦', 'code': 'uk'},
      {'name': 'עברית', 'flag': '🇮🇱', 'code': 'he'},
      {'name': 'ไทย', 'flag': '🇹🇭', 'code': 'th'},
      {'name': 'Tiếng Việt', 'flag': '🇻🇳', 'code': 'vi'},
      {'name': 'Bahasa Indonesia', 'flag': '🇮🇩', 'code': 'id'},
      {'name': 'Bahasa Melayu', 'flag': '🇲🇾', 'code': 'ms'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: InputDecoration(
              labelText: 'Preferred Language',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4B63FF)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            items: languages.map((lang) {
              return DropdownMenuItem<String>(
                value: lang['name'] as String,
                child: Row(
                  children: [
                    Text(
                      lang['flag'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      lang['name'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedLanguage = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesStep(Map<String, dynamic> step) {
    final activities = [
      {'name': 'Adventure Sports', 'icon': Icons.sports_martial_arts},
      {'name': 'Cultural Tours', 'icon': Icons.museum},
      {'name': 'Food & Wine', 'icon': Icons.restaurant_menu},
      {'name': 'Historical Tours', 'icon': Icons.history},
      {'name': 'Nature & Wildlife', 'icon': Icons.nature_people},
      {'name': 'Photography Tours', 'icon': Icons.photo_camera},
      {'name': 'Shopping Tours', 'icon': Icons.shopping_cart},
      {'name': 'Water Sports', 'icon': Icons.waves},
      {'name': 'Mountain Activities', 'icon': Icons.terrain},
      {'name': 'City Tours', 'icon': Icons.location_city},
      {'name': 'Museum Tours', 'icon': Icons.account_balance},
      {'name': 'Nightlife', 'icon': Icons.night_shelter},
      {'name': 'Beach Activities', 'icon': Icons.beach_access},
      {'name': 'Hiking & Trekking', 'icon': Icons.hiking},
      {'name': 'Scuba Diving', 'icon': Icons.scuba_diving},
      {'name': 'Sailing', 'icon': Icons.sailing},
      {'name': 'Cycling Tours', 'icon': Icons.directions_bike},
      {'name': 'Cooking Classes', 'icon': Icons.cookie},
      {'name': 'Wine Tasting', 'icon': Icons.wine_bar},
      {'name': 'Art Workshops', 'icon': Icons.brush},
      {'name': 'Music Events', 'icon': Icons.music_note},
      {'name': 'Festivals', 'icon': Icons.celebration},
      {'name': 'Spa & Wellness', 'icon': Icons.spa},
      {'name': 'Yoga Retreats', 'icon': Icons.self_improvement},
      {'name': 'Bird Watching', 'icon': Icons.visibility},
      {'name': 'Fishing', 'icon': Icons.phishing},
      {'name': 'Golf', 'icon': Icons.golf_course},
      {'name': 'Skiing', 'icon': Icons.downhill_skiing},
      {'name': 'Snowboarding', 'icon': Icons.snowboarding},
      {'name': 'Camping', 'icon': Icons.cabin},
      {'name': 'Kayaking', 'icon': Icons.kayaking},
      {'name': 'Surfing', 'icon': Icons.surfing},
      {'name': 'Paragliding', 'icon': Icons.paragliding},
      {'name': 'Hot Air Balloon', 'icon': Icons.air},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((activity) {
              final isSelected = _selectedActivities.contains(activity['name'] as String);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activity['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : const Color(0xFF4B63FF),
                    ),
                    const SizedBox(width: 6),
                    Text(activity['name'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedActivities.add(activity['name'] as String);
                    } else {
                      _selectedActivities.remove(activity['name'] as String);
                    }
                  });
                },
                backgroundColor: isSelected ? const Color(0xFF4B63FF) : Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E225E),
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4B63FF) : const Color(0xFFE1E4E8),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLanguagesStep(Map<String, dynamic> step) {
    final languages = [
      {'name': 'English', 'flag': '🇬🇧'},
      {'name': 'Français', 'flag': '🇫🇷'},
      {'name': 'Español', 'flag': '🇪🇸'},
      {'name': 'Deutsch', 'flag': '🇩🇪'},
      {'name': 'Italiano', 'flag': '🇮🇹'},
      {'name': 'Português', 'flag': '🇵🇹'},
      {'name': '中文', 'flag': '🇨🇳'},
      {'name': '日本語', 'flag': '🇯🇵'},
      {'name': '한국어', 'flag': '🇰🇷'},
      {'name': 'العربية', 'flag': '🇸🇦'},
      {'name': 'Русский', 'flag': '🇷🇺'},
      {'name': 'हिन्दी', 'flag': '🇮🇳'},
      {'name': 'Nederlands', 'flag': '🇳🇱'},
      {'name': 'Polski', 'flag': '🇵🇱'},
      {'name': 'Türkçe', 'flag': '🇹🇷'},
      {'name': 'Svenska', 'flag': '🇸🇪'},
      {'name': 'Norsk', 'flag': '🇳🇴'},
      {'name': 'Dansk', 'flag': '🇩🇰'},
      {'name': 'Suomi', 'flag': '🇫🇮'},
      {'name': 'Ελληνικά', 'flag': '🇬🇷'},
      {'name': 'Magyar', 'flag': '🇭🇺'},
      {'name': 'Čeština', 'flag': '🇨🇿'},
      {'name': 'Română', 'flag': '🇷🇴'},
      {'name': 'Български', 'flag': '🇧🇬'},
      {'name': 'Українська', 'flag': '🇺🇦'},
      {'name': 'עברית', 'flag': '🇮🇱'},
      {'name': 'ไทย', 'flag': '🇹🇭'},
      {'name': 'Tiếng Việt', 'flag': '🇻🇳'},
      {'name': 'Bahasa Indonesia', 'flag': '🇮🇩'},
      {'name': 'Bahasa Melayu', 'flag': '🇲🇾'},
      {'name': 'Català', 'flag': '🇪🇸'},
      {'name': 'Euskara', 'flag': '🇪🇸'},
      {'name': 'Galego', 'flag': '🇪🇸'},
      {'name': 'Hrvatski', 'flag': '🇭🇷'},
      {'name': 'Slovenčina', 'flag': '🇸🇰'},
      {'name': 'Slovenščina', 'flag': '🇸🇮'},
      {'name': 'Eesti', 'flag': '🇪🇪'},
      {'name': 'Latviešu', 'flag': '🇱🇻'},
      {'name': 'Lietuvių', 'flag': '🇱🇹'},
      {'name': 'Македонски', 'flag': '🇲🇰'},
      {'name': 'Српски', 'flag': '🇷🇸'},
      {'name': 'Shqip', 'flag': '🇦🇱'},
      {'name': 'Íslenska', 'flag': '🇮🇸'},
      {'name': 'Malti', 'flag': '🇲🇹'},
      {'name': 'Cymraeg', 'flag': '🇬🇧'},
      {'name': 'Gaeilge', 'flag': '🇮🇪'},
      {'name': 'Gàidhlig', 'flag': '🇬🇧'},
      {'name': 'Беларуская', 'flag': '🇧🇾'},
      {'name': 'Հայերեն', 'flag': '🇦🇲'},
      {'name': 'ქართული', 'flag': '🇬🇪'},
      {'name': 'Azərbaycanca', 'flag': '🇦🇿'},
      {'name': 'Қазақша', 'flag': '🇰🇿'},
      {'name': 'Кыргызча', 'flag': '🇰🇬'},
      {'name': 'Oʻzbekcha', 'flag': '🇺🇿'},
      {'name': 'Тоҷикӣ', 'flag': '🇹🇯'},
      {'name': 'Монгол', 'flag': '🇲🇳'},
      {'name': 'नेपाली', 'flag': '🇳🇵'},
      {'name': 'বাংলা', 'flag': '🇧🇩'},
      {'name': 'සිංහල', 'flag': '🇱🇰'},
      {'name': 'മലയാളം', 'flag': '🇮🇳'},
      {'name': 'தமிழ்', 'flag': '🇮🇳'},
      {'name': 'తెలుగు', 'flag': '🇮🇳'},
      {'name': 'ಕನ್ನಡ', 'flag': '🇮🇳'},
      {'name': 'ગુજરાતી', 'flag': '🇮🇳'},
      {'name': 'ਪੰਜਾਬੀ', 'flag': '🇮🇳'},
      {'name': 'اردو', 'flag': '🇵🇰'},
      {'name': 'فارسی', 'flag': '🇮🇷'},
      {'name': 'پښتو', 'flag': '🇦🇫'},
      {'name': 'سنڌي', 'flag': '🇵🇰'},
      {'name': 'မြန်မာ', 'flag': '🇲🇲'},
      {'name': 'ខ្មែរ', 'flag': '🇰🇭'},
      {'name': 'ລາວ', 'flag': '🇱🇦'},
      {'name': 'ဗမာ', 'flag': '🇲🇲'},
      {'name': 'Bamanankan', 'flag': '🇲🇱'},
      {'name': 'Wolof', 'flag': '🇸🇳'},
      {'name': 'Kiswahili', 'flag': '🇰🇪'},
      {'name': 'Afrikaans', 'flag': '🇿🇦'},
      {'name': 'IsiZulu', 'flag': '🇿🇦'},
      {'name': 'IsiXhosa', 'flag': '🇿🇦'},
      {'name': 'አማርኛ', 'flag': '🇪🇹'},
      {'name': 'ትግርኛ', 'flag': '🇪🇹'},
      {'name': 'Akan', 'flag': '🇬🇭'},
      {'name': 'Yorùbá', 'flag': '🇳🇬'},
      {'name': 'Igbo', 'flag': '🇳🇬'},
      {'name': 'Hausa', 'flag': '🇳🇬'},
      {'name': 'Oromo', 'flag': '🇪🇹'},
      {'name': 'Somali', 'flag': '🇸🇴'},
      {'name': 'Tigrinya', 'flag': '🇪🇷'},
      {'name': 'Amharic', 'flag': '🇪🇹'},
      {'name': 'Malagasy', 'flag': '🇲🇬'},
      {'name': 'Chichewa', 'flag': '🇲🇼'},
      {'name': 'Shona', 'flag': '🇿🇼'},
      {'name': 'Kinyarwanda', 'flag': '🇷🇼'},
      {'name': 'Kirundi', 'flag': '🇧🇮'},
      {'name': 'Tshiluba', 'flag': '🇨🇩'},
      {'name': 'Lingala', 'flag': '🇨🇩'},
      {'name': 'Azerbaijani', 'flag': '🇦🇿'},
      {'name': 'Georgian', 'flag': '🇬🇪'},
      {'name': 'Armenian', 'flag': '🇦🇲'},
      {'name': 'Kazakh', 'flag': '🇰🇿'},
      {'name': 'Uzbek', 'flag': '🇺🇿'},
      {'name': 'Tajik', 'flag': '🇹🇯'},
      {'name': 'Kyrgyz', 'flag': '🇰🇬'},
      {'name': 'Turkmen', 'flag': '🇹🇲'},
      {'name': 'Mongolian', 'flag': '🇲🇳'},
      {'name': 'Nepali', 'flag': '🇳🇵'},
      {'name': 'Bengali', 'flag': '🇧🇩'},
      {'name': 'Sinhala', 'flag': '🇱🇰'},
      {'name': 'Tamil', 'flag': '🇮🇳'},
      {'name': 'Telugu', 'flag': '🇮🇳'},
      {'name': 'Marathi', 'flag': '🇮🇳'},
      {'name': 'Gujarati', 'flag': '🇮🇳'},
      {'name': 'Kannada', 'flag': '🇮🇳'},
      {'name': 'Punjabi', 'flag': '🇮🇳'},
      {'name': 'Urdu', 'flag': '🇵🇰'},
      {'name': 'Persian', 'flag': '🇮🇷'},
      {'name': 'Pashto', 'flag': '🇦🇫'},
      {'name': 'Sindhi', 'flag': '🇵🇰'},
      {'name': 'Burmese', 'flag': '🇲🇲'},
      {'name': 'Khmer', 'flag': '🇰🇭'},
      {'name': 'Lao', 'flag': '🇱🇦'},
      {'name': 'Thai', 'flag': '🇹🇭'},
      {'name': 'Vietnamese', 'flag': '🇻🇳'},
      {'name': 'Indonesian', 'flag': '🇮🇩'},
      {'name': 'Malay', 'flag': '🇲🇾'},
      {'name': 'Filipino', 'flag': '🇵🇭'},
      {'name': 'Javanese', 'flag': '🇮🇩'},
      {'name': 'Sundanese', 'flag': '🇮🇩'},
      {'name': 'Madurese', 'flag': '🇮🇩'},
      {'name': 'Minangkabau', 'flag': '🇮🇩'},
      {'name': 'Balinese', 'flag': '🇮🇩'},
      {'name': 'Buginese', 'flag': '🇮🇩'},
      {'name': 'Acehnese', 'flag': '🇮🇩'},
      {'name': 'Batak', 'flag': '🇮🇩'},
      {'name': 'Dayak', 'flag': '🇮🇩'},
      {'name': 'Sasak', 'flag': '🇮🇩'},
      {'name': 'Makassarese', 'flag': '🇮🇩'},
      {'name': 'Toba', 'flag': '🇮🇩'},
      {'name': 'Mandailing', 'flag': '🇮🇩'},
      {'name': 'Gorontalo', 'flag': '🇮🇩'},
      {'name': 'Mongondow', 'flag': '🇮🇩'},
      {'name': 'Muna', 'flag': '🇮🇩'},
      {'name': 'Buton', 'flag': '🇮🇩'},
      {'name': 'Kaili', 'flag': '🇮🇩'},
      {'name': 'Luwu', 'flag': '🇮🇩'},
      {'name': 'Mori', 'flag': '🇮🇩'},
      {'name': 'Wolio', 'flag': '🇮🇩'},
      {'name': 'Banggai', 'flag': '🇮🇩'},
      {'name': 'Karo', 'flag': '🇮🇩'},
      {'name': 'Singkil', 'flag': '🇮🇩'},
      {'name': 'Alas', 'flag': '🇮🇩'},
      {'name': 'Nias', 'flag': '🇮🇩'},
      {'name': 'Gayo', 'flag': '🇮🇩'},
      {'name': 'Tamiang', 'flag': '🇮🇩'},
      {'name': 'Kubu', 'flag': '🇮🇩'},
      {'name': 'Lembak', 'flag': '🇮🇩'},
      {'name': 'Lematang', 'flag': '🇮🇩'},
      {'name': 'Lintang', 'flag': '🇮🇩'},
      {'name': 'Pasemah', 'flag': '🇮🇩'},
      {'name': 'Semendo', 'flag': '🇮🇩'},
      {'name': 'Komering', 'flag': '🇮🇩'},
      {'name': 'Lampung', 'flag': '🇮🇩'},
      {'name': 'Melayu', 'flag': '🇮🇩'},
      {'name': 'Rejang', 'flag': '🇮🇩'},
      {'name': 'Simeulue', 'flag': '🇮🇩'},
      {'name': 'Sikule', 'flag': '🇮🇩'},
      {'name': 'Nias', 'flag': '🇮🇩'},
      {'name': 'Kaur', 'flag': '🇮🇩'},
      {'name': 'Krui', 'flag': '🇮🇩'},
      {'name': 'Lampong', 'flag': '🇮🇩'},
      {'name': 'Rawas', 'flag': '🇮🇩'},
      {'name': 'Serawai', 'flag': '🇮🇩'},
      {'name': 'Melayu', 'flag': '🇮🇩'},
      {'name': 'Bengkulu', 'flag': '🇮🇩'},
      {'name': 'Muko', 'flag': '🇮🇩'},
      {'name': 'Pekal', 'flag': '🇮🇩'},
      {'name': 'Lembak', 'flag': '🇮🇩'},
      {'name': 'Lintang', 'flag': '🇮🇩'},
      {'name': 'Pasemah', 'flag': '🇮🇩'},
      {'name': 'Semendo', 'flag': '🇮🇩'},
      {'name': 'Komering', 'flag': '🇮🇩'},
      {'name': 'Lampung', 'flag': '🇮🇩'},
      {'name': 'Melayu', 'flag': '🇮🇩'},
      {'name': 'Rejang', 'flag': '🇮🇩'},
      {'name': 'Simeulue', 'flag': '🇮🇩'},
      {'name': 'Sikule', 'flag': '🇮🇩'},
      {'name': 'Nias', 'flag': '🇮🇩'},
      {'name': 'Kaur', 'flag': '🇮🇩'},
      {'name': 'Krui', 'flag': '🇮🇩'},
      {'name': 'Lampong', 'flag': '🇮🇩'},
      {'name': 'Rawas', 'flag': '🇮🇩'},
      {'name': 'Serawai', 'flag': '🇮🇩'},
      {'name': 'Melayu', 'flag': '🇮🇩'},
      {'name': 'Bengkulu', 'flag': '🇮🇩'},
      {'name': 'Muko', 'flag': '🇮🇩'},
      {'name': 'Pekal', 'flag': '🇮🇩'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map((lang) {
              final isSelected = _selectedLanguages.contains(lang['name'] as String);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang['flag'] as String,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(lang['name'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLanguages.add(lang['name'] as String);
                    } else {
                      _selectedLanguages.remove(lang['name'] as String);
                    }
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF4B63FF),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E225E),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4B63FF) : const Color(0xFFE1E4E8),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Selected: ${_selectedLanguages.length}',
            style: const TextStyle(
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOrganizerBioStep(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE1E4E8),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _bioController,
              focusNode: _focusNode,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Share your experience, what makes you a great organizer, and why you want to join DJTrip...',
                hintStyle: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E225E),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTouristBioStep(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE1E4E8),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _bioController,
              focusNode: _focusNode,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Tell us about yourself and what you love about traveling...',
                hintStyle: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E225E),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReasonToJoinStep(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE1E4E8),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _reasonToJoinController,
              focusNode: _focusNode,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Share why you want to join DJTrip as an organizer... Tell us about your experience, what makes you passionate about tourism, and how you plan to create amazing experiences for travelers.',
                hintStyle: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E225E),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This information will help us understand your motivation and will be reviewed during the approval process.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDefaultStep(Map<String, dynamic> step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step['description'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Step content coming soon...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6C757D),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
