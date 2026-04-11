import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';

class PhoneValidationScreen extends StatefulWidget {
  const PhoneValidationScreen({super.key});

  @override
  State<PhoneValidationScreen> createState() => _PhoneValidationScreenState();
}

class _PhoneValidationScreenState extends State<PhoneValidationScreen> {
  final _phoneCtrl = TextEditingController();
  String _selectedCountry = 'France';
  bool _isValidating = false;

  // 🚀 Country phone formats - Top 15 countries visiting Tunisia
  static const Map<String, String> _countryCodes = {
    'France': '+33',
    'Tunisie': '+216',
    'Algérie': '+213',
    'Libye': '+218',
    'Maroc': '+212',
    'Italie': '+39',
    'Allemagne': '+49',
    'Royaume-Uni': '+44',
    'Espagne': '+34',
    'Belgique': '+32',
    'Suisse': '+41',
    'Canada': '+1',
    'Égypte': '+20',
    'Russie': '+7',
    'Arabie Saoudite': '+966',
    'Émirats Arabes Unis': '+971',
  };

  static const Map<String, String> _countryExamples = {
    'France': '06 12 34 56 78',
    'Tunisie': '98 765 432',
    'Algérie': '55 123 4567',
    'Libye': '21 234 567',
    'Maroc': '06 12 34 56 78',
    'Italie': '312 3456789',
    'Allemagne': '030 1234567',
    'Royaume-Uni': '020 1234 5678',
    'Espagne': '612 345 678',
    'Belgique': '485 12 34 56',
    'Suisse': '079 123 45 67',
    'Canada': '416 123 4567',
    'Égypte': '010 1234 567',
    'Russie': '916 123 45 67',
    'Arabie Saoudite': '050 123 4567',
    'Émirats Arabes Unis': '050 123 4567',
  };

  static const List<String> _countries = [
    'France',
    'Tunisie',
    'Algérie',
    'Libye', 
    'Maroc',
    'Italie',
    'Allemagne',
    'Royaume-Uni',
    'Espagne',
    'Belgique',
    'Suisse',
    'Canada',
    'Égypte',
    'Russie',
    'Arabie Saoudite',
    'Émirats Arabes Unis',
  ];

  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhone();
  }

  Future<void> _loadCurrentPhone() async {
    final user = await UserService.getProfile();
    if (mounted && user != null && user['numTel'] != null) {
      setState(() {
        _phoneCtrl.text = user['numTel']!;
        // Detect country from phone number
        for (final country in _countries) {
          final code = _countryCodes[country]!;
          if (user['numTel']!.startsWith(code)) {
            _selectedCountry = country;
            break;
          }
        }
        _checkValidity();
      });
    }
  }

  void _checkValidity() {
    final phone = _phoneCtrl.text.trim();
    final code = _countryCodes[_selectedCountry]!;
    final cleanValue = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check minimum length based on country
    int minLength = 8;
    switch (_selectedCountry) {
      case 'France': minLength = 9; break;
      case 'Tunisie': minLength = 8; break;
      case 'Algérie': minLength = 9; break;
      case 'Libye': minLength = 8; break;
      case 'Maroc': minLength = 9; break;
      default: minLength = 8;
    }
    
    final digitsOnly = cleanValue.replaceAll(RegExp(r'\D'), '');
    final isValid = digitsOnly.length >= minLength;
    
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
      if (isValid) {
        _autoSavePhone();
      }
    }
  }

  Future<void> _autoSavePhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    try {
      final result = await UserService.updateProfile({
        'num_tel': phone,
        'pays_telephone': _selectedCountry,
        'pays_origine': _selectedCountry,
      });

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Phone number saved automatically'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Silent fail for auto-save
      print('Auto-save failed: $e');
    }
  }

  String _formatPhoneNumber(String value) {
    if (value.isEmpty) return value;
    
    final code = _countryCodes[_selectedCountry]!;
    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove country code if present
    String digits = cleanValue;
    if (digits.startsWith(code.replaceAll('+', ''))) {
      digits = digits.substring(code.length - 1);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // Format based on country
    switch (_selectedCountry) {
      case 'France':
        if (digits.length <= 1) return '$code $digits';
        if (digits.length <= 3) return '$code ${digits.substring(0, 1)} ${digits.substring(1)}';
        if (digits.length <= 5) return '$code ${digits.substring(0, 1)} ${digits.substring(1, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 1)} ${digits.substring(1, 3)} ${digits.substring(3, 5)} ${digits.substring(5, 7)} ${digits.substring(7)}';
      
      case 'Tunisie':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 5) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
      
      case 'Algérie':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 5) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
      
      case 'Libye':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 5) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
      
      case 'Maroc':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 5) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
      
      case 'Italie':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Allemagne':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Royaume-Uni':
        if (digits.length <= 4) return '$code $digits';
        if (digits.length <= 7) return '$code ${digits.substring(0, 4)} ${digits.substring(4)}';
        return '$code ${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
      
      case 'Espagne':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Belgique':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 4) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        if (digits.length <= 6) return '$code ${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6)}';
      
      case 'Suisse':
        if (digits.length <= 2) return '$code $digits';
        if (digits.length <= 5) return '$code ${digits.substring(0, 2)} ${digits.substring(2)}';
        return '$code ${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
      
      case 'Canada':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Égypte':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Russie':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Arabie Saoudite':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      case 'Émirats Arabes Unis':
        if (digits.length <= 3) return '$code $digits';
        if (digits.length <= 6) return '$code ${digits.substring(0, 3)} ${digits.substring(3)}';
        return '$code ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
      
      default:
        return '$code $digits';
    }
  }

  Future<void> _savePhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showError('Phone number is required');
      return;
    }

    setState(() => _isValidating = true);

    try {
      final result = await UserService.updateProfile({
        'num_tel': phone,
        'pays_telephone': _selectedCountry, // 🚀 NEW: Save phone country separately
        'pays_origine': _selectedCountry, // Also update origin country
      });

      if (!mounted) return;
      setState(() => _isValidating = false);

      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError(result['message'] as String? ?? 'Error updating phone number');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phone Number'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚀 NEW: Single combined phone field with country selector
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  // Country selector dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        underline: const SizedBox(),
                        items: _countries
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    _countryCodes[c]!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedCountry = v!;
                            _phoneCtrl.text = _formatPhoneNumber(_phoneCtrl.text);
                          });
                        },
                      ),
                    ),
                  ),
                  // Phone input field
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        final formatted = _formatPhoneNumber(value);
                        if (formatted != value) {
                          _phoneCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                        _checkValidity();
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter phone number',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        suffixIcon: _isValid
                            ? Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Format info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, 
                               size: 16, 
                               color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Format for $_selectedCountry:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _countryExamples[_selectedCountry]!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Status indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isValid ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isValid ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isValid ? Icons.check_circle : Icons.info_outline,
                    color: _isValid ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isValid
                          ? 'Phone number is valid and saved automatically'
                          : 'Enter a valid phone number for $_selectedCountry',
                      style: TextStyle(
                        color: _isValid ? Colors.green : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }
}
