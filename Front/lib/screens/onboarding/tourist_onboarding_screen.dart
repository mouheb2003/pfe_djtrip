import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/onboarding_service.dart';

class TouristOnboardingScreen extends StatefulWidget {
  const TouristOnboardingScreen({super.key});

  @override
  State<TouristOnboardingScreen> createState() => _TouristOnboardingScreenState();
}

class _TouristOnboardingScreenState extends State<TouristOnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  int _currentPage = 0;
  bool _isLoading = false;
  
  // Form data
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  String? _selectedPhoneCountry;
  String? _selectedLanguage;
  String? _avatarUrl;
  
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Phone Number',
      subtitle: 'Add your phone number for better communication',
      description: 'We\'ll use this to send you important updates about your bookings',
      icon: Icons.phone,
      color: const Color(0xFF4B63FF),
      stepId: 'phone',
    ),
    OnboardingPage(
      title: 'Profile Picture',
      subtitle: 'Add a profile picture to personalize your account',
      description: 'A photo helps organizers and other tourists recognize you',
      icon: Icons.camera_alt,
      color: const Color(0xFF00B894),
      stepId: 'profile_picture',
    ),
    OnboardingPage(
      title: 'Country',
      subtitle: 'Tell us where you\'re from',
      description: 'This helps us show you activities relevant to your location',
      icon: Icons.public,
      color: const Color(0xFF9B59B6),
      stepId: 'country',
    ),
    OnboardingPage(
      title: 'Preferred Language',
      subtitle: 'Choose your preferred language',
      description: 'We\'ll use this to communicate with you in your language',
      icon: Icons.language,
      color: const Color(0xFFFFA502),
      stepId: 'language',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _progressController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    
    // Update progress animation
    _progressController.reset();
    _progressController.forward();
  }

  Future<void> _onNext() async {
    HapticFeedback.lightImpact();
    
    // Validate and save current step
    if (!_validateCurrentStep()) {
      return;
    }
    
    await _saveCurrentStep();
    
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  void _onSkip() {
    HapticFeedback.lightImpact();
    _completeOnboarding();
  }

  void _onBackPressed() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    final stepId = _pages[_currentPage].stepId;
    
    switch (stepId) {
      case 'phone':
        if (_phoneController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your phone number')),
          );
          return false;
        }
        break;
      case 'country':
        if (_countryController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your country')),
          );
          return false;
        }
        break;
      case 'language':
        if (_selectedLanguage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select your preferred language')),
          );
          return false;
        }
        break;
    }
    return true;
  }

  Future<void> _saveCurrentStep() async {
    final stepId = _pages[_currentPage].stepId;
    Map<String, dynamic> stepData = {};
    
    switch (stepId) {
      case 'phone':
        stepData = {
          'num_tel': _phoneController.text,
          'pays_telephone': _selectedPhoneCountry ?? 'France',
        };
        break;
      case 'profile_picture':
        stepData = {
          'avatar': _avatarUrl,
        };
        break;
      case 'country':
        stepData = {
          'pays_origine': _countryController.text,
        };
        break;
      case 'language':
        stepData = {
          'langue_preferee': _selectedLanguage ?? 'English',
        };
        break;
    }
    
    try {
      await OnboardingService.updateOnboardingStep(stepData);
    } catch (e) {
      print('Error saving step: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    
    try {
      await OnboardingService.completeOnboarding();
      
      if (!mounted) return;
      
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/tourist_home',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing onboarding: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      // TODO: Upload image to server and get URL
      setState(() {
        _avatarUrl = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (only show after first page)
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _onBackPressed,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1E225E),
                        size: 24,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  
                  // Skip Button
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: const Color(0xFF4B63FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Progress Bar
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1E4E8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_currentPage + 1) / _pages.length,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _pages[_currentPage].color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage].color
                              : const Color(0xFFE1E4E8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Page Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _OnboardingPageWidget(
                          page: _pages[index],
                          isLastPage: index == _pages.length - 1,
                          onNext: _onNext,
                          phoneController: _phoneController,
                          countryController: _countryController,
                          selectedPhoneCountry: _selectedPhoneCountry,
                          onPhoneCountryChanged: (value) => setState(() => _selectedPhoneCountry = value),
                          selectedLanguage: _selectedLanguage,
                          onLanguageChanged: (value) => setState(() => _selectedLanguage = value),
                          avatarUrl: _avatarUrl,
                          onPickImage: _pickImage,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageWidget extends StatefulWidget {
  final OnboardingPage page;
  final bool isLastPage;
  final VoidCallback onNext;
  final TextEditingController phoneController;
  final TextEditingController countryController;
  final String? selectedPhoneCountry;
  final Function(String?) onPhoneCountryChanged;
  final String? selectedLanguage;
  final Function(String?) onLanguageChanged;
  final String? avatarUrl;
  final VoidCallback onPickImage;

  const _OnboardingPageWidget({
    required this.page,
    required this.isLastPage,
    required this.onNext,
    required this.phoneController,
    required this.countryController,
    required this.selectedPhoneCountry,
    required this.onPhoneCountryChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.avatarUrl,
    required this.onPickImage,
  });

  @override
  State<_OnboardingPageWidget> createState() => _OnboardingPageWidgetState();
}

class _OnboardingPageWidgetState extends State<_OnboardingPageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.page.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.page.icon,
                    size: 64,
                    color: widget.page.color,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                widget.page.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E225E),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                widget.page.subtitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.page.color,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                widget.page.description,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF6C757D),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Form fields based on step
              _buildFormFields(),
              
              const SizedBox(height: 32),
              
              // Next Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.page.color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.isLastPage ? 'Complete' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.isLastPage) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 20),
                      ] else ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    switch (widget.page.stepId) {
      case 'phone':
        return Column(
          children: [
            // Phone Country Dropdown
            DropdownButtonFormField<String>(
              value: widget.selectedPhoneCountry,
              decoration: InputDecoration(
                labelText: 'Phone Country',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'France', child: Text('France (+33)')),
                DropdownMenuItem(value: 'Tunisia', child: Text('Tunisia (+216)')),
                DropdownMenuItem(value: 'USA', child: Text('USA (+1)')),
                DropdownMenuItem(value: 'UK', child: Text('UK (+44)')),
                DropdownMenuItem(value: 'Germany', child: Text('Germany (+49)')),
                DropdownMenuItem(value: 'Italy', child: Text('Italy (+39)')),
                DropdownMenuItem(value: 'Spain', child: Text('Spain (+34)')),
              ],
              onChanged: widget.onPhoneCountryChanged,
            ),
            const SizedBox(height: 16),
            // Phone Number Input
            TextField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
          ],
        );
      
      case 'profile_picture':
        return Column(
          children: [
            GestureDetector(
              onTap: widget.onPickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: widget.page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.page.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: widget.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          widget.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 48,
                              color: widget.page.color.withOpacity(0.5),
                            );
                          },
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: widget.page.color.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to upload',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.page.color.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Optional - You can add this later',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF6C757D),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      
      case 'country':
        return TextField(
          controller: widget.countryController,
          decoration: InputDecoration(
            labelText: 'Country',
            hintText: 'Enter your country',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.public),
          ),
        );
      
      case 'language':
        return DropdownButtonFormField<String>(
          value: widget.selectedLanguage,
          decoration: InputDecoration(
            labelText: 'Preferred Language',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.language),
          ),
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English')),
            DropdownMenuItem(value: 'French', child: Text('Français')),
            DropdownMenuItem(value: 'Arabic', child: Text('العربية')),
            DropdownMenuItem(value: 'Spanish', child: Text('Español')),
            DropdownMenuItem(value: 'German', child: Text('Deutsch')),
            DropdownMenuItem(value: 'Italian', child: Text('Italiano')),
          ],
          onChanged: widget.onLanguageChanged,
        );
      
      default:
        return const SizedBox.shrink();
    }
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String stepId;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.stepId,
  });
}
