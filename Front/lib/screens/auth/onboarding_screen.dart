import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../tourist/tourist_main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Country data
// ─────────────────────────────────────────────────────────────────────────────
class _Country {
  final String flag;
  final String name;
  const _Country(this.flag, this.name);
}

const _kCountries = [
  _Country('🇩🇿', 'Algeria'),
  _Country('🇺🇸', 'United States'),
  _Country('🇬🇧', 'United Kingdom'),
  _Country('🇫🇷', 'France'),
  _Country('🇩🇪', 'Germany'),
  _Country('🇪🇸', 'Spain'),
  _Country('🇨🇦', 'Canada'),
  _Country('🇦🇺', 'Australia'),
  _Country('🇯🇵', 'Japan'),
  _Country('🇲🇦', 'Morocco'),
  _Country('🇹🇳', 'Tunisia'),
  _Country('🇪🇬', 'Egypt'),
  _Country('🇸🇦', 'Saudi Arabia'),
  _Country('🇦🇪', 'United Arab Emirates'),
  _Country('🇮🇹', 'Italy'),
  _Country('🇳🇱', 'Netherlands'),
  _Country('🇧🇪', 'Belgium'),
  _Country('🇨🇭', 'Switzerland'),
  _Country('🇸🇪', 'Sweden'),
  _Country('🇵🇹', 'Portugal'),
  _Country('🇹🇷', 'Turkey'),
  _Country('🇧🇷', 'Brazil'),
  _Country('🇲🇽', 'Mexico'),
  _Country('🇮🇳', 'India'),
  _Country('🇨🇳', 'China'),
  _Country('🇰🇷', 'South Korea'),
  _Country('🇷🇺', 'Russia'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Language data
// ─────────────────────────────────────────────────────────────────────────────
const _kLanguages = ['French', 'English', 'Arabic'];

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final String userType; // 'Touriste' | 'Organisator'

  const OnboardingScreen({super.key, required this.userType});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Step 1: Phone
  final _phoneCtrl = TextEditingController();

  // Step 2: Country
  String? _selectedCountry;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Step 3: Language
  String _selectedLanguage = 'French';

  // Step 3
  final _bioCtrl = TextEditingController();

  // Step 4 (Tourist Only)
  final List<String> _selectedInterests = [];

  // Step 4 (Organizer Only)
  final List<String> _selectedSpokenLanguages = ['French'];

  // Step 5 (Organizer Only)
  final List<String> _selectedSpecialties = [];

  // Step 6 (Final)
  File? _profilePhoto;
  bool _isUploading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _page++);
  }

  void _prevPage() {
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _page--);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (image != null) setState(() => _profilePhoto = File(image.path));
  }

  Future<void> _finish({bool skip = false}) async {
    final Map<String, dynamic> updateData = {
      'num_tel': _phoneCtrl.text.trim(),
      'pays_origine': _selectedCountry,
      'langue_preferee': _selectedLanguage,
      'bio': _bioCtrl.text.trim(),
    };

    if (widget.userType == 'Touriste') {
      updateData['centres_interet'] = _selectedInterests;
    } else {
      updateData['langues_proposees'] = _selectedSpokenLanguages;
      updateData['specialites_activites'] = _selectedSpecialties;
      updateData['is_approved'] = false; // 🚀 Set to false for new organizers
    }

    setState(() => _isUploading = true);

    try {
      // Update profile info
      await UserService.updateProfile(updateData);

      // Update avatar if provided
      if (!skip && _profilePhoto != null) {
        await UserService.updateAvatar(_profilePhoto!);
      }

      // Mark as onboarded
      final result = await OnboardingService.completeOnboarding();
      if (!result['success']) {
        throw Exception(result['message'] ?? 'Failed to complete onboarding');
      }

      // 🚀 Refresh user data from backend to get updated is_onboarded flag
      final userRes = await ApiClient.get('/users/me');
      if (userRes.statusCode == 200) {
        final body = jsonDecode(userRes.body);
        if (body['user'] is Map<String, dynamic>) {
          await AuthService.saveUser(body['user'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      print('Error completing onboarding: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    if (widget.userType == 'Organisator' || widget.userType == 'Organizer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaitingApprovalLegacyScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TouristMainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTourist = widget.userType == 'Touriste';
    final int totalSteps = isTourist ? 6 : 7;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Decorative Blobs
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: AppColors.primary.withOpacity(0.04),
            ),
          ),
          SafeArea(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepPhone(
                  controller: _phoneCtrl,
                  totalSteps: totalSteps,
                  onNext: _nextPage,
                  onBack: () => Navigator.pop(context),
                ),
                _Step1(
                  selectedCountry: _selectedCountry,
                  searchCtrl: _searchCtrl,
                  searchQuery: _searchQuery,
                  totalSteps: totalSteps,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onCountrySelected: (c) => setState(() => _selectedCountry = c),
                  onNext: _nextPage,
                  onBack: _prevPage,
                ),
                _Step2(
                  selectedLanguage: _selectedLanguage,
                  totalSteps: totalSteps,
                  onLanguageSelected: (l) => setState(() => _selectedLanguage = l),
                  onNext: _nextPage,
                  onBack: _prevPage,
                ),
                _StepBio(
                  controller: _bioCtrl,
                  totalSteps: totalSteps,
                  onNext: _nextPage,
                  onBack: _prevPage,
                ),
                if (isTourist)
                  _StepInterests(
                    selectedInterests: _selectedInterests,
                    totalSteps: totalSteps,
                    onToggleInterest: (interest) {
                      setState(() {
                        if (_selectedInterests.contains(interest)) {
                          _selectedInterests.remove(interest);
                        } else {
                          _selectedInterests.add(interest);
                        }
                      });
                    },
                    onNext: _nextPage,
                    onBack: _prevPage,
                  )
                else ...[
                  _StepSpokenLanguages(
                    selectedLanguages: _selectedSpokenLanguages,
                    totalSteps: totalSteps,
                    onToggleLanguage: (lang) {
                      setState(() {
                        if (_selectedSpokenLanguages.contains(lang)) {
                          if (_selectedSpokenLanguages.length > 1) {
                            _selectedSpokenLanguages.remove(lang);
                          }
                        } else {
                          _selectedSpokenLanguages.add(lang);
                        }
                      });
                    },
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _StepSpecialties(
                    selectedSpecialties: _selectedSpecialties,
                    totalSteps: totalSteps,
                    onToggleSpecialty: (spec) {
                      setState(() {
                        if (_selectedSpecialties.contains(spec)) {
                          _selectedSpecialties.remove(spec);
                        } else {
                          _selectedSpecialties.add(spec);
                        }
                      });
                    },
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                ],
                _StepPhoto(
                  profilePhoto: _profilePhoto,
                  isUploading: _isUploading,
                  totalSteps: totalSteps,
                  onPickPhoto: _pickPhoto,
                  onUpload: () => _finish(skip: false),
                  onSkip: () => _finish(skip: true),
                  onBack: _prevPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Components
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumStepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;

  const _PremiumStepHeader({
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: onBack,
            ),
            _StepCounter(current: currentStep, total: totalSteps),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StepCounter extends StatelessWidget {
  final int current;
  final int total;
  const _StepCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Step $current of $total',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot indicator
// ─────────────────────────────────────────────────────────────────────────────
class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Phone Number
// ─────────────────────────────────────────────────────────────────────────────
class _StepPhone extends StatelessWidget {
  final TextEditingController controller;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepPhone({
    required this.controller,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Phone Number',
            subtitle: 'Enter your phone number for account verification.',
            currentStep: 1,
            totalSteps: totalSteps,
            onBack: onBack,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+216 XX XXX XXX',
                prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                border: InputBorder.none,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _NextButton(onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Where are you from?
// ─────────────────────────────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final String? selectedCountry;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final int totalSteps;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCountrySelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step1({
    required this.selectedCountry,
    required this.searchCtrl,
    required this.searchQuery,
    required this.totalSteps,
    required this.onSearchChanged,
    required this.onCountrySelected,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _kCountries
        .where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Where are you from?',
            subtitle: 'Select your country to personalize your experience and discover nearby places.',
            currentStep: 2,
            totalSteps: totalSteps,
            onBack: onBack,
          ),
          const SizedBox(height: 30),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search for a country...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                hintStyle: const TextStyle(color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Country list
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, i) {
                final country = filtered[i];
                final isSelected = selectedCountry == country.name;
                return _CountryTile(
                  country: country,
                  isSelected: isSelected,
                  onTap: () => onCountrySelected(country.name),
                );
              },
            ),
          ),

          // Next button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selectedCountry != null
                    ? [AppColors.accent, AppColors.accentSoft]
                    : [Colors.grey.shade300, Colors.grey.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: selectedCountry != null ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ] : [],
              ),
              child: ElevatedButton(
                onPressed: selectedCountry != null ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  final _Country country;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                country.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 24)
            else
              Icon(Icons.circle_outlined, color: AppColors.textLight.withOpacity(0.5), size: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Preferred Language
// ─────────────────────────────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final String selectedLanguage;
  final int totalSteps;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    required this.selectedLanguage,
    required this.totalSteps,
    required this.onLanguageSelected,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Preferred language?',
            subtitle: 'Choose your language to navigate DJTrip comfortably.',
            currentStep: 3,
            totalSteps: totalSteps,
            onBack: onBack,
          ),
          const SizedBox(height: 40),

          // Language options
          ..._kLanguages.map(
            (lang) => _LanguageTile(
              language: lang,
              isSelected: selectedLanguage == lang,
              onTap: () => onLanguageSelected(lang),
            ),
          ),

          const Spacer(),

          // Next button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentSoft],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                language,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 24)
            else
              Icon(Icons.circle_outlined, color: AppColors.textLight.withOpacity(0.5), size: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Add Profile Photo
// ─────────────────────────────────────────────────────────────────────────────
class _StepPhoto extends StatelessWidget {
  final File? profilePhoto;
  final bool isUploading;
  final int totalSteps;
  final VoidCallback onPickPhoto;
  final VoidCallback onUpload;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _StepPhoto({
    required this.profilePhoto,
    required this.isUploading,
    required this.totalSteps,
    required this.onPickPhoto,
    required this.onUpload,
    required this.onSkip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Profile Picture',
            subtitle: 'Add a photo to be recognized by other community members.',
            currentStep: totalSteps,
            totalSteps: totalSteps,
            onBack: onBack,
          ),
          const SizedBox(height: 40),

          // Photo Picker Section
          Center(
            child: GestureDetector(
              onTap: onPickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 4),
                      image: profilePhoto != null
                          ? DecorationImage(image: FileImage(profilePhoto!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: profilePhoto == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary.withOpacity(0.5)),
                              const SizedBox(height: 8),
                              const Text('Add', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          const Text(
            'Tip: A clear, bright photo builds more trust with travelers!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),

          const Spacer(),

          // Buttons
          Column(
            children: [
              Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentSoft],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (isUploading || profilePhoto == null) ? null : onUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: isUploading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Finish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Later',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Bio
// ─────────────────────────────────────────────────────────────────────────────
class _StepBio extends StatelessWidget {
  final TextEditingController controller;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepBio({
    required this.controller,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Tell us about yourself',
            subtitle: 'Write a short bio to introduce yourself to the community.',
            currentStep: 4,
            totalSteps: totalSteps,
            onBack: onBack,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'I love traveling and discovering new cultures...',
                border: InputBorder.none,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _NextButton(onPressed: onNext),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Interests (Tourist Only)
// ─────────────────────────────────────────────────────────────────────────────
class _StepInterests extends StatefulWidget {
  final List<String> selectedInterests;
  final int totalSteps;
  final Function(String) onToggleInterest;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepInterests({
    required this.selectedInterests,
    required this.totalSteps,
    required this.onToggleInterest,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_StepInterests> createState() => _StepInterestsState();
}

class _StepInterestsState extends State<_StepInterests> {
  final List<String> _baseInterests = [
    'Beach', 'Adventure', 'Culture', 'Food', 'History',
    'Shopping', 'Nightlife', 'Nature', 'Photography', 'Sports'
  ];

  void _showAddCustomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Interest'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter your interest...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                widget.onToggleInterest(val);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Your interests',
            subtitle: 'Select topics you are interested in to see personalized content.',
            currentStep: 5,
            totalSteps: widget.totalSteps,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...widget.selectedInterests
                      .where((i) => !_baseInterests.contains(i))
                      .map((interest) => _ChoiceChip(
                            label: interest,
                            isSelected: true,
                            onTap: () => widget.onToggleInterest(interest),
                          )),
                  ..._baseInterests.map((interest) {
                    final isSelected = widget.selectedInterests.contains(interest);
                    return _ChoiceChip(
                      label: interest,
                      isSelected: isSelected,
                      onTap: () => widget.onToggleInterest(interest),
                    );
                  }),
                  _ChoiceChip(
                    label: '+ Other',
                    isSelected: false,
                    onTap: _showAddCustomDialog,
                    isOutline: true,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _NextButton(onPressed: widget.onNext),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Spoken Languages (Organizer Only)
// ─────────────────────────────────────────────────────────────────────────────
class _StepSpokenLanguages extends StatefulWidget {
  final List<String> selectedLanguages;
  final int totalSteps;
  final Function(String) onToggleLanguage;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepSpokenLanguages({
    required this.selectedLanguages,
    required this.totalSteps,
    required this.onToggleLanguage,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_StepSpokenLanguages> createState() => _StepSpokenLanguagesState();
}

class _StepSpokenLanguagesState extends State<_StepSpokenLanguages> {
  final List<String> _baseLanguages = ['French', 'English', 'Arabic', 'German', 'Italian', 'Spanish'];

  void _showAddCustomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Spoken Language'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter language...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                widget.onToggleLanguage(val);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Languages you speak',
            subtitle: 'List the languages you can use to interact with tourists.',
            currentStep: 5,
            totalSteps: widget.totalSteps,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...widget.selectedLanguages
                      .where((l) => !_baseLanguages.contains(l))
                      .map((lang) => _ChoiceChip(
                            label: lang,
                            isSelected: true,
                            onTap: () => widget.onToggleLanguage(lang),
                          )),
                  ..._baseLanguages.map((lang) {
                    final isSelected = widget.selectedLanguages.contains(lang);
                    return _ChoiceChip(
                      label: lang,
                      isSelected: isSelected,
                      onTap: () => widget.onToggleLanguage(lang),
                    );
                  }),
                  _ChoiceChip(
                    label: '+ Other',
                    isSelected: false,
                    onTap: _showAddCustomDialog,
                    isOutline: true,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _NextButton(onPressed: widget.onNext),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Specialties (Organizer Only)
// ─────────────────────────────────────────────────────────────────────────────
class _StepSpecialties extends StatefulWidget {
  final List<String> selectedSpecialties;
  final int totalSteps;
  final Function(String) onToggleSpecialty;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _StepSpecialties({
    required this.selectedSpecialties,
    required this.totalSteps,
    required this.onToggleSpecialty,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_StepSpecialties> createState() => _StepSpecialtiesState();
}

class _StepSpecialtiesState extends State<_StepSpecialties> {
  final List<String> _baseSpecialties = [
    'Excursions', 'Gastronomy', 'Diving', 'Photography', 'History',
    'Traditional Arts', 'Local Crafts', 'Sports', 'Wellness'
  ];

  void _showAddCustomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Specialty'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter specialty...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                widget.onToggleSpecialty(val);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _PremiumStepHeader(
            title: 'Your specialties',
            subtitle: 'Select the types of activities you specialize in.',
            currentStep: 6,
            totalSteps: widget.totalSteps,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...widget.selectedSpecialties
                      .where((s) => !_baseSpecialties.contains(s))
                      .map((spec) => _ChoiceChip(
                            label: spec,
                            isSelected: true,
                            onTap: () => widget.onToggleSpecialty(spec),
                          )),
                  ..._baseSpecialties.map((spec) {
                    final isSelected = widget.selectedSpecialties.contains(spec);
                    return _ChoiceChip(
                      label: spec,
                      isSelected: isSelected,
                      onTap: () => widget.onToggleSpecialty(spec),
                    );
                  }),
                  _ChoiceChip(
                    label: '+ Other',
                    isSelected: false,
                    onTap: _showAddCustomDialog,
                    isOutline: true,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _NextButton(onPressed: widget.onNext),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isOutline;

  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isOutline ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(isOutline ? 0.6 : 0.2),
            width: isOutline ? 1.5 : 1,
            style: isOutline ? BorderStyle.solid : BorderStyle.solid,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isOutline ? AppColors.primary : AppColors.textPrimary),
            fontWeight: isSelected || isOutline ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting Approval Screen
// ─────────────────────────────────────────────────────────────────────────────
class WaitingApprovalLegacyScreen extends StatelessWidget {
  const WaitingApprovalLegacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E225E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verification Status',
          style: TextStyle(color: Color(0xFF1E225E), fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Top Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B63FF).withOpacity(0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 80,
                      color: Color(0xFF4B63FF),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'FINAL STEP',
                        style: TextStyle(
                          color: Color(0xFF4B63FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Under Review',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6C757D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING APPROVAL',
                    style: TextStyle(
                      color: Color(0xFF4B63FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your application is\nbeing ',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E225E),
                        ),
                      ),
                      TextSpan(
                        text: 'reviewed',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B63FF),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Our team is currently verifying your organizer profile to ensure the highest quality of events on DJTrip. This process typically takes 24-48 hours. We\'ll notify you via email once your account is ready.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6C757D),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              
              // Status Items
              _StatusItem(
                icon: Icons.check_circle_outline,
                title: 'Profile Submitted',
                subtitle: 'Your documents and portfolio have been received.',
                isDone: true,
              ),
              const SizedBox(height: 16),
              _StatusItem(
                icon: Icons.verified_user_outlined,
                title: 'Manual Verification',
                subtitle: 'An admin is currently cross-referencing your event credentials.',
                isDone: false,
              ),

              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: 140,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    AuthService.logout();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B63FF).withOpacity(0.7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;

  const _StatusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FF).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDone ? Colors.white : const Color(0xFF4B63FF),
              shape: BoxShape.circle,
              boxShadow: isDone ? [] : [
                BoxShadow(
                  color: const Color(0xFF4B63FF).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isDone ? const Color(0xFF4B63FF) : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E225E),
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6C757D),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _NextButton({this.onPressed, this.label = 'Continue'});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onPressed != null
              ? [AppColors.accent, AppColors.accentSoft]
              : [Colors.grey.shade300, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5;
    const dashSpace = 5;
    double startAngle = 0;

    while (startAngle < 2 * 3.14159) {
      canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), startAngle, dashWidth / (size.width / 2), false, paint);
      startAngle += (dashWidth + dashSpace) / (size.width / 2);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
