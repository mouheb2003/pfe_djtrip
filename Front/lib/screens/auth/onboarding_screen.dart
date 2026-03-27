import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import '../tourist/tourist_main_screen.dart';
import '../organizer/organizer_main_screen.dart';

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

  // Step 1
  String? _selectedCountry;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Step 2
  String _selectedLanguage = 'French';

  // Step 3
  File? _profilePhoto;
  bool _isUploading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
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
    if (!skip && _profilePhoto != null) {
      setState(() => _isUploading = true);
      await UserService.updateAvatar(_profilePhoto!);
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
    final dest = widget.userType == 'Organisator'
        ? const OrganizerMainScreen()
        : const TouristMainScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  @override
  Widget build(BuildContext context) {
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
                _Step1(
                  selectedCountry: _selectedCountry,
                  searchCtrl: _searchCtrl,
                  searchQuery: _searchQuery,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onCountrySelected: (c) => setState(() => _selectedCountry = c),
                  onNext: _nextPage,
                  onBack: () => Navigator.pop(context),
                ),
                _Step2(
                  selectedLanguage: _selectedLanguage,
                  onLanguageSelected: (l) => setState(() => _selectedLanguage = l),
                  onNext: _nextPage,
                  onBack: _prevPage,
                ),
                _Step3(
                  profilePhoto: _profilePhoto,
                  isUploading: _isUploading,
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
// Step 1: Where are you from?
// ─────────────────────────────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final String? selectedCountry;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCountrySelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step1({
    required this.selectedCountry,
    required this.searchCtrl,
    required this.searchQuery,
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
            currentStep: 1,
            totalSteps: 3,
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
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    required this.selectedLanguage,
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
            title: 'What language do you prefer?',
            subtitle: 'Choose your language to navigate DJTrip comfortably.',
            currentStep: 2,
            totalSteps: 3,
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
class _Step3 extends StatelessWidget {
  final File? profilePhoto;
  final bool isUploading;
  final VoidCallback onPickPhoto;
  final VoidCallback onUpload;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _Step3({
    required this.profilePhoto,
    required this.isUploading,
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
            currentStep: 3,
            totalSteps: 3,
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
