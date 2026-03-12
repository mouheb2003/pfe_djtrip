import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import 'profile_picture_screen.dart';
import '../country_selection_screen.dart';
import '../language_selection_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final User user;
  final List<String>? preferences;

  const ProfileCompletionScreen({
    super.key,
    required this.user,
    this.preferences,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String? _selectedCountry;
  String? _selectedLanguage;
  int _currentStep = 0;
  final bool _canSkip = true;
  bool _isAgeValid = true;
  String? _ageErrorMessage;

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
    {'flag': '🇨🇭', 'name': 'Switzerland', 'dial': '+41', 'format': '76 123 45 67'},
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
    {'flag': '🇳🇱', 'name': 'Netherlands', 'dial': '+31', 'format': '6 12345678'},
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
    // Add listener for real-time age validation
    _ageController.addListener(_validateAge);
  }

  void _validateAge() {
    final text = _ageController.text;
    if (text.isEmpty) {
      setState(() {
        _isAgeValid = true;
        _ageErrorMessage = null;
      });
      return;
    }

    final age = int.tryParse(text);
    if (age == null) {
      setState(() {
        _isAgeValid = false;
        _ageErrorMessage = 'Please enter a valid number';
      });
    } else if (age < 15) {
      setState(() {
        _isAgeValid = false;
        _ageErrorMessage = 'Age must be at least 15';
      });
    } else if (age > 120) {
      setState(() {
        _isAgeValid = false;
        _ageErrorMessage = 'Age must be less than 120';
      });
    } else {
      setState(() {
        _isAgeValid = true;
        _ageErrorMessage = null;
      });
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

  @override
  void dispose() {
    _ageController.removeListener(_validateAge);
    _ageController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _continueToPermissions();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _continueToPermissions() {
    // Create an object with the collected data
    final profileData = {
      'age': _ageController.text.isNotEmpty
          ? int.tryParse(_ageController.text)
          : null,
      'num_tel': _phoneController.text.isNotEmpty
          ? '${_selectedDialCode != null ? '${_selectedDialCode!} ' : ''}${_phoneController.text.trim()}'
          : null,
      'bio': _bioController.text.isNotEmpty ? _bioController.text.trim() : null,
      'pays_origine': _selectedCountry,
      if (widget.user.userType == 'Touriste' && _selectedLanguage != null)
        'langue_preferee': _selectedLanguage,
      if (widget.preferences != null && widget.preferences!.isNotEmpty)
        'preferences': widget.preferences,
    };

    // Navigate to profile picture screen (new step in onboarding)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfilePictureScreen(user: widget.user, profileData: profileData),
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
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B1A)),
                onPressed: _previousStep,
              )
            : null,
        actions: [
          if (_canSkip)
            TextButton(
              onPressed: _continueToPermissions,
              child: Text(
                'Skip',
                style: TextStyle(color: Color(0xFFFF6B1A), fontSize: 16),
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
                        color: index <= _currentStep + 1
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
                child: Form(key: _formKey, child: _buildStepContent()),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentStep < 2 ? 'Next' : 'Finish',
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildContactStep();
      case 2:
        return _buildBioStep();
      default:
        return Container();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B1A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 64,
              color: Color(0xFFFF6B1A),
            ),
          ),
        ),
        SizedBox(height: 32),

        // Title
        Text(
          'Complete your profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Tell us a bit about yourself',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        SizedBox(height: 32),

        // Age
        Text(
          'Age',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: 'Enter your age (15-120)',
            prefixIcon: Icon(
              Icons.cake_outlined,
              color: !_isAgeValid ? Colors.red : Color(0xFFFF6B1A),
            ),
            filled: true,
            fillColor: !_isAgeValid ? Colors.red[50] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: !_isAgeValid ? Colors.red : Colors.grey[200]!,
                width: !_isAgeValid ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: !_isAgeValid ? Colors.red : Color(0xFFFF6B1A),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            errorText: _ageErrorMessage,
            errorStyle: TextStyle(fontSize: 12, color: Colors.red[700]),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final age = int.tryParse(value);
              if (age == null || age < 15 || age > 120) {
                return 'Please enter a valid age (15-120)';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B1A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_outlined,
              size: 64,
              color: Color(0xFFFF6B1A),
            ),
          ),
        ),
        SizedBox(height: 32),

        // Title
        Text(
          'Contact information',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'How can we contact you?',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        SizedBox(height: 32),

        // Phone number
        Text(
          'Phone number',
          style: TextStyle(
            fontSize: 16,
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
              // Country code button
              GestureDetector(
                onTap: _showCountryCodePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey[200]!)),
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
              // Phone number input
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
        SizedBox(height: 24),

        // Country of origin - Selector
        Text(
          'Country of origin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CountrySelectionScreen(selectedCountry: _selectedCountry),
              ),
            );
            if (result != null) {
              setState(() {
                _selectedCountry = result;
              });
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.public_outlined, color: Color(0xFFFF6B1A)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountry ?? 'Select a country',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedCountry != null
                          ? Colors.black87
                          : Colors.grey[500],
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
        SizedBox(height: 24),

        // Preferred language - If Tourist
        if (widget.user.userType == 'Touriste') ...[
          Text(
            'Preferred language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          InkWell(
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
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.language_outlined, color: Color(0xFFFF6B1A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLanguage ?? 'Select a language',
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedLanguage != null
                            ? Colors.black87
                            : Colors.grey[500],
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
      ],
    );
  }

  Widget _buildBioStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B1A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 64,
              color: Color(0xFFFF6B1A),
            ),
          ),
        ),
        SizedBox(height: 32),

        // Title
        Text(
          'Tell us about yourself',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Share your passions and interests',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        SizedBox(height: 32),

        // Bio
        Text(
          'Biography',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText:
                'Describe your passions, favorite destinations, travel experiences...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFFFF6B1A), width: 2),
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'A good bio helps other travelers get to know you better',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
