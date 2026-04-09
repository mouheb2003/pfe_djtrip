import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';

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
  String? _selectedCountry;
  String? _selectedLanguage;
  List<String> _selectedActivities = [];
  List<String> _selectedLanguages = [];

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

  Future<void> _pickImage() async {
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
        setState(() {
          _onboardingData['avatar'] = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _nextStep() async {
    HapticFeedback.lightImpact();
    
    // Validate current step
    if (!_validateCurrentStep()) {
      return;
    }
    
    // Save step data
    await _saveCurrentStep();
    
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  bool _validateCurrentStep() {
    final step = _steps[_currentStep];
    final requiredFields = step['fields'] as List<String>;
    
    for (final field in requiredFields) {
      if (!_onboardingData.containsKey(field) || 
          _onboardingData[field] == null || 
          _onboardingData[field].toString().trim().isEmpty) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: const Color(0xFFFFA502),
          ),
        );
        return false;
      }
    }
    
    return true;
  }

  Future<void> _saveCurrentStep() async {
    final step = _steps[_currentStep];
    final stepId = step['id'] as String;
    
    // Prepare step data based on step type
    Map<String, dynamic> stepData = {};
    
    switch (stepId) {
      case 'phone':
        stepData = {
          'num_tel': _phoneController.text.trim(),
          'pays_telephone': _selectedCountry ?? 'France',
        };
        break;
      case 'profile_picture':
        stepData = {
          'avatar': _onboardingData['avatar'],
        };
        break;
      case 'country':
        stepData = {
          'pays_origine': _selectedCountry,
        };
        break;
      case 'language':
        stepData = {
          'langue_preferee': _selectedLanguage ?? 'English',
        };
        break;
      case 'specialized_activities':
        stepData = {
          'specialites_activites': _selectedActivities,
        };
        break;
      case 'spoken_languages':
        stepData = {
          'langues_proposees': _selectedLanguages,
        };
        break;
    }
    
    // Update onboarding data
    setState(() {
      _onboardingData.addAll(stepData);
    });
    
    // Send to backend
    final result = await OnboardingService.updateOnboardingStep(stepData);
    
    if (!result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to save step'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isCompleting = true);
    
    try {
      final result = await OnboardingService.completeOnboarding();
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Onboarding completed successfully!'),
            backgroundColor: const Color(0xFF00B894),
          ),
        );
        
        // Navigate to appropriate screen
        if (result['requires_approval'] == true) {
          Navigator.pushReplacementNamed(context, '/waiting_approval');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to complete onboarding'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } finally {
      setState(() => _isCompleting = false);
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E225E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: (_currentStep + 1) / _steps.length,
                        backgroundColor: const Color(0xFFE1E4E8),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of ${_steps.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                      Text(
                        _steps[_currentStep]['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E225E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStepPage(_steps[index]);
                },
              ),
            ),
            
            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _previousStep,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4B63FF),
                                side: const BorderSide(color: Color(0xFF4B63FF)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Previous',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isCompleting ? null : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B63FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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
                                      Text('Completing...'),
                                    ],
                                  )
                                : Text(
                                    _currentStep == _steps.length - 1 ? 'Complete' : 'Next',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
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
      case 'country':
        return _buildCountryStep(step);
      case 'language':
        return _buildLanguageStep(step);
      case 'specialized_activities':
        return _buildActivitiesStep(step);
      case 'spoken_languages':
        return _buildLanguagesStep(step);
      default:
        return _buildDefaultStep(step);
    }
  }

  Widget _buildPhoneStep(Map<String, dynamic> step) {
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
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1 234 567 8900',
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
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureStep(Map<String, dynamic> step) {
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
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(75),
                  border: Border.all(
                    color: const Color(0xFF4B63FF),
                    width: 3,
                  ),
                ),
                child: _onboardingData['avatar'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(72),
                        child: Image.asset(
                          _onboardingData['avatar'],
                          width: 144,
                          height: 144,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _pickImage,
              child: const Text(
                'Choose Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B63FF),
                ),
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

  Widget _buildCountryStep(Map<String, dynamic> step) {
    final countries = ['France', 'United States', 'United Kingdom', 'Germany', 'Spain', 'Italy', 'Canada', 'Australia'];
    
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
                value: country,
                child: Text(country),
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
    final languages = ['English', 'French', 'Spanish', 'German', 'Italian', 'Portuguese', 'Chinese', 'Japanese'];
    
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
            items: languages.map((language) {
              return DropdownMenuItem<String>(
                value: language,
                child: Text(language),
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
      'Adventure Sports', 'Cultural Tours', 'Food & Wine', 'Historical Tours',
      'Nature & Wildlife', 'Photography Tours', 'Shopping Tours', 'Water Sports',
      'Mountain Activities', 'City Tours', 'Museum Tours', 'Nightlife'
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
              final isSelected = _selectedActivities.contains(activity);
              return FilterChip(
                label: Text(activity),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedActivities.add(activity);
                    } else {
                      _selectedActivities.remove(activity);
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
        ],
      ),
    );
  }

  Widget _buildLanguagesStep(Map<String, dynamic> step) {
    final languages = [
      'English', 'French', 'Spanish', 'German', 'Italian', 'Portuguese',
      'Chinese', 'Japanese', 'Korean', 'Arabic', 'Russian', 'Hindi'
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
            children: languages.map((language) {
              final isSelected = _selectedLanguages.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLanguages.add(language);
                    } else {
                      _selectedLanguages.remove(language);
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
