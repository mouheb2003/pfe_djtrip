import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import 'edit_activity_specialties_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _interests = <String>[];
  String _country = 'FR'; // 🚀 Country code for phone number
  String _originCountry = 'FR'; // 🚀 FIX: Separate country of origin (completely independent)
  String _language = 'English'; // 🚀 FIX: Default language (not French)
  String? _avatarUrl;
  bool _isSaving = false;
  bool _isAvatarUploading = false;
  bool _isPhoneValid = false;
  String _userType = ''; // 🚀 NEW: Stocker le type d'utilisateur
  Map<String, dynamic>?
  _userData; // 🚀 NEW: Stocker les données utilisateur pour l'affichage
  String? _lastSavedPhone; // 🚀 NEW: Éviter les sauvegardes en double
  Timer? _phoneSaveTimer; // 🚀 NEW: Timer pour le debounce
  bool _hasNetworkError = false; // 🚀 NEW: Suivre les erreurs réseau

  String? _toAbsoluteUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final apiUri = Uri.parse(ApiClient.baseUrl);
    final origin =
        '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
    if (value.startsWith('/')) {
      return '$origin$value';
    }
    return '$origin/$value';
  }

  String _storedPhone(Map<String, dynamic>? user) {
    if (user == null) return '';
    return (user['num_tel'] ?? user['numTel'] ?? '').toString().trim();
  }

  // 🚀 NEW: Détecter si c'est un organisateur
  bool get _isOrganizer {
    return _userType == 'Organisator';
  }

  static const List<String> _countries = [
    'FR', // France
    'TN', // Tunisie
    'DZ', // Algérie
    'LY', // Libye
    'MA', // Maroc
    'IT', // Italie
    'DE', // Allemagne
    'GB', // Royaume-Uni
    'ES', // Espagne
    'BE', // Belgique
    'CH', // Suisse
    'CA', // Canada
    'EG', // Égypte
    'RU', // Russie
    'SA', // Arabie Saoudite
    'AE', // Émirats Arabes Unis
  ];
  static const List<String> _languages = [
    'French',
    'English',
    'العربية',
    'Deutsch',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkConnectivity(); // 🚀 NEW: Check connectivity on init
  }

  Future<void> _loadProfile() async {
    print('🔄 Loading profile...');
    final user = await UserService.getProfile();
    print('👤 User data received: ${user != null ? 'YES' : 'NULL'}');

    if (user != null) {
      print('📋 User keys: ${user.keys.toList()}');
      print('🖼️ Avatar: ${user['avatar']}');
      print('🌍 Country: ${user['pays_origine']}');
      print('🌍 Phone country: ${user['pays_telephone']}');
    }

    if (mounted && user != null) {
      setState(() {
        _userData = user; // 🚀 NEW: Stocker les données utilisateur
        _nameCtrl.text = user['fullname'] ?? '';

        // 🚀 NEW: Extract phone number without country code
        String phoneNumber = _storedPhone(user);
        if (phoneNumber.isNotEmpty) {
          // Remove country code if present
          final phoneCountry = _normalizeCountryKey(
            (user['pays_telephone'] ?? user['pays_origine'] ?? 'France')
                .toString(),
          );
          final countryCode = _getCountryCode(phoneCountry);
          if (phoneNumber.startsWith(countryCode)) {
            phoneNumber = phoneNumber.replaceFirst(countryCode, '').trim();
          }
        }
        _phoneCtrl.text = phoneNumber;
        _lastSavedPhone = phoneNumber; // 🚀 NEW: Initialize last saved phone

        _bioCtrl.text = user['bio'] ?? '';
        _avatarUrl =
            _toAbsoluteUrl(user['avatar']?.toString()) ??
            _toAbsoluteUrl(user['avatar_url']?.toString());
        _userType =
            user['userType'] ?? ''; // 🚀 NEW: Charger le type d'utilisateur

        // 🚀 FIX: Handle phone country separately from origin country
        final phoneCountryRaw =
            (user['pays_telephone'] ?? '').toString();
        if (phoneCountryRaw.trim().isNotEmpty) {
          final countryKey = _normalizeCountryKey(phoneCountryRaw);
          if (_countries.contains(countryKey)) {
            _country = countryKey;
          }
        }

        // 🚀 FIX: Handle origin country separately (completely independent)
        final originCountryRaw =
            (user['pays_origine'] ?? '').toString();
        if (originCountryRaw.trim().isNotEmpty) {
          final countryKey = _normalizeCountryKey(originCountryRaw);
          if (_countries.contains(countryKey)) {
            _originCountry = countryKey;
          }
        }

        // 🚀 FIX: Handle language with proper field names
        if (user['langue_preferee'] != null &&
            user['langue_preferee']!.trim().isNotEmpty) {
          final l = _normalizeLanguage(user['langue_preferee']!);
          if (_languages.contains(l)) {
            _language = l;
          }
        }

        final rawInterests =
            (user['centres_interet'] as List?) ??
            (user['centresInteret'] as List?) ??
            (user['interests'] as List?) ??
            const [];
        _interests
          ..clear()
          ..addAll(
            rawInterests
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty),
          );
      });

      print('✅ Profile loaded successfully');
    } else {
      print('❌ Failed to load profile');
    }
  }

  // 🚀 NEW: Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      _hasNetworkError = response.statusCode != 200;
      return !_hasNetworkError;
    } catch (e) {
      _hasNetworkError = true;
      print('❌ Network check failed: $e');
      return false;
    }
  }

  // 🚀 NEW: Auto-save phone number change
  Future<void> _savePhoneChange() async {
    // 🚀 NEW: Cancel previous timer
    _phoneSaveTimer?.cancel();

    // 🚀 NEW: Check if phone actually changed
    final currentPhone = _phoneCtrl.text.trim();
    if (currentPhone == _lastSavedPhone) {
      return; // No change, don't save
    }

    // 🚀 NEW: Set new timer with longer debounce
    _phoneSaveTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      try {
        // 🚀 NEW: Include country code in the saved phone number
        final fullPhoneNumber = currentPhone.isEmpty
            ? ''
            : '${_getCountryCode(_country)} $currentPhone';
        final result = await UserService.updateProfile({
          'num_tel': fullPhoneNumber,
          'numTel': fullPhoneNumber,
          'pays_telephone': _getCountryName(_country), // 🚀 FIX: Save only phone country
        });

        if (result['success'] == true) {
          print('✅ Phone number updated: $fullPhoneNumber');
          // 🚀 NEW: Update last saved phone
          _lastSavedPhone = currentPhone;
          // Update local data
          if (_userData != null) {
            _userData!['num_tel'] = fullPhoneNumber;
            _userData!['numTel'] = fullPhoneNumber;
          }
        }
      } catch (e) {
        print('❌ Error auto-saving phone: $e');
      }
    });
  }

  // 🚀 NEW: Normalize country name to country key
  String _normalizeCountryKey(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'france' || v == 'fr') return 'FR';
    if (v == 'tunisie' || v == 'tn') return 'TN';
    if (v == 'algérie' || v == 'algerie' || v == 'dz') return 'DZ';
    if (v == 'libye' || v == 'ly') return 'LY';
    if (v == 'maroc' || v == 'ma') return 'MA';
    if (v == 'italie' || v == 'it') return 'IT';
    if (v == 'allemagne' || v == 'de') return 'DE';
    if (v == 'royaume-uni' || v == 'united kingdom' || v == 'gb') return 'GB';
    if (v == 'espagne' || v == 'es') return 'ES';
    if (v == 'belgique' || v == 'be') return 'BE';
    if (v == 'suisse' || v == 'ch') return 'CH';
    if (v == 'canada' || v == 'ca') return 'CA';
    if (v == 'égypte' || v == 'egypte' || v == 'eg') return 'EG';
    if (v == 'russie' || v == 'ru') return 'RU';
    if (v == 'arabie saoudite' || v == 'sa') return 'SA';
    if (v == 'émirats arabes unis' || v == 'emirates' || v == 'ae') return 'AE';
    return 'FR'; // Default to France
  }

  String _normalizeLanguage(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'français' || v == 'francais' || v == 'french' || v == 'fr') {
      return 'French';
    }
    if (v == 'english' || v == 'en' || v == 'anglais') return 'English';
    if (v == 'arabic' || v == 'ar' || v == 'العربية') return 'العربية';
    if (v == 'german' || v == 'deutsch' || v == 'de' || v == 'allemand') {
      return 'Deutsch';
    }
    return raw;
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final phone = _phoneCtrl.text.trim();
    final fullPhoneNumber = phone.isEmpty
        ? ''
        : '${_getCountryCode(_country)} $phone';
    final data = {
      'fullname': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'num_tel': fullPhoneNumber,
      'numTel': fullPhoneNumber,
      'centres_interet': _interests,
      'pays_telephone': _getCountryName(_country), // 🚀 FIX: Phone country
      'pays_origine': _getCountryName(_originCountry), // 🚀 FIX: Origin country - SEPARATE
      'langue_preferee': _language, // 🚀 FIX: Correct field name
    };
    final result = await UserService.updateProfile(data);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Error saving profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚀 Phone validation methods
  String _getCountryCode(String countryKey) {
    const codes = {
      'FR': '+33',
      'TN': '+216',
      'DZ': '+213',
      'LY': '+218',
      'MA': '+212',
      'IT': '+39',
      'DE': '+49',
      'GB': '+44',
      'ES': '+34',
      'BE': '+32',
      'CH': '+41',
      'CA': '+1',
      'EG': '+20',
      'RU': '+7',
      'SA': '+966',
      'AE': '+971',
    };
    return codes[countryKey] ?? '+33';
  }

  // 🚀 NEW: Get country flag emoji
  String _getCountryFlag(String countryKey) {
    const flags = {
      'FR': '🇫🇷',
      'TN': '🇹🇳',
      'DZ': '🇩🇿',
      'LY': '🇱🇾',
      'MA': '🇲🇦',
      'IT': '🇮🇹',
      'DE': '🇩🇪',
      'GB': '🇬🇧',
      'ES': '🇪🇸',
      'BE': '🇧🇪',
      'CH': '🇨🇭',
      'CA': '🇨🇦',
      'EG': '🇪🇬',
      'RU': '🇷🇺',
      'SA': '🇸🇦',
      'AE': '🇦🇪',
    };
    return flags[countryKey] ?? '🇫🇷';
  }

  // 🚀 NEW: Get country name from key
  String _getCountryName(String countryKey) {
    const names = {
      'FR': 'France',
      'TN': 'Tunisie',
      'DZ': 'Algérie',
      'LY': 'Libye',
      'MA': 'Maroc',
      'IT': 'Italie',
      'DE': 'Allemagne',
      'GB': 'Royaume-Uni',
      'ES': 'Espagne',
      'BE': 'Belgique',
      'CH': 'Suisse',
      'CA': 'Canada',
      'EG': 'Égypte',
      'RU': 'Russie',
      'SA': 'Arabie Saoudite',
      'AE': 'Émirats Arabes Unis',
    };
    return names[countryKey] ?? 'France';
  }

  // 🚀 NEW: Get maximum digits allowed for each country
  int _getMaxDigits(String countryKey) {
    const maxDigits = {
      'FR': 9,
      'TN': 8,
      'DZ': 9,
      'LY': 8,
      'MA': 9,
      'IT': 10,
      'DE': 11,
      'GB': 10,
      'ES': 9,
      'BE': 9,
      'CH': 9,
      'CA': 10,
      'EG': 10,
      'RU': 11,
      'SA': 9,
      'AE': 9,
    };
    return maxDigits[countryKey] ?? 8;
  }

  String _getPhoneExample(String countryKey) {
    const examples = {
      'FR': '06 12 34 56 78',
      'TN': '98 765 432',
      'DZ': '55 123 4567',
      'LY': '21 234 567',
      'MA': '06 12 34 56 78',
      'IT': '312 3456789',
      'DE': '030 1234567',
      'GB': '020 1234 5678',
      'ES': '612 345 678',
      'BE': '485 12 34 56',
      'CH': '079 123 45 67',
      'CA': '416 123 4567',
      'EG': '010 1234 567',
      'RU': '916 123 45 67',
      'SA': '050 123 4567',
      'AE': '050 123 4567',
    };
    return examples[countryKey] ?? 'Enter phone number';
  }

  void _formatPhoneNumber() {
    // Auto-format will be applied as user types
    final text = _phoneCtrl.text;
    if (text.isEmpty) return;

    // Simple formatting: add spaces every 2-3 digits
    final digits = text.replaceAll(RegExp(r'\s'), '');
    String formatted = digits;

    switch (_country) {
      case 'FR': // France: XX XX XX XX XX
        if (digits.length > 2) {
          formatted =
              '${digits.substring(0, 2)} ${digits.substring(2, min(4, digits.length))}';
          if (digits.length > 4)
            formatted += ' ${digits.substring(4, min(6, digits.length))}';
          if (digits.length > 6)
            formatted += ' ${digits.substring(6, min(8, digits.length))}';
          if (digits.length > 8) formatted += ' ${digits.substring(8)}';
        }
        break;
      case 'TN': // Tunisia: XX XXX XXX
      case 'LY': // Libya: XX XXX XXX
        if (digits.length > 2) {
          formatted =
              '${digits.substring(0, 2)} ${digits.substring(2, min(5, digits.length))}';
          if (digits.length > 5) formatted += ' ${digits.substring(5)}';
        }
        break;
      default:
        // Generic formatting
        if (digits.length > 2) {
          formatted =
              '${digits.substring(0, 2)} ${digits.substring(2, min(5, digits.length))}';
          if (digits.length > 5)
            formatted += ' ${digits.substring(5, min(8, digits.length))}';
          if (digits.length > 8) formatted += ' ${digits.substring(8)}';
        }
    }

    // Only update if different to avoid cursor jumping
    if (formatted != text) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  int min(int a, int b) => a < b ? a : b;

  void _validatePhone() {
    final phone = _phoneCtrl.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // 🚀 NEW: Limit digits based on country maximum
    final maxDigits = _getMaxDigits(_country);
    if (digits.length > maxDigits) {
      // Truncate excess digits
      final truncatedDigits = digits.substring(0, maxDigits);
      _phoneCtrl.text = truncatedDigits;
      _formatPhoneNumber();
      return;
    }

    // 🚀 NEW: Get min digits for this country
    int minDigits = _getMinDigits(_country);

    // 🚀 FIX: Phone is valid only if:
    // - digits count is EXACTLY maxDigits (perfect) 
    // OR - digits count is within [minDigits, maxDigits] range
    // BUT prefer exact maxDigits for the green checkmark
    final isValid = digits.length >= minDigits && digits.length <= maxDigits;
    
    if (isValid != _isPhoneValid) {
      setState(() => _isPhoneValid = isValid);
    }
  }

  // 🚀 NEW: Get minimum digits for each country
  int _getMinDigits(String countryKey) {
    const minDigits = {
      'FR': 9,
      'TN': 8,
      'DZ': 9,
      'LY': 8,
      'MA': 9,
      'IT': 10,
      'DE': 11,
      'GB': 10,
      'ES': 9,
      'BE': 9,
      'CH': 9,
      'CA': 10,
      'EG': 10,
      'RU': 11,
      'SA': 9,
      'AE': 9,
    };
    return minDigits[countryKey] ?? 8;
  }

  Future<void> _pickAndUploadAvatar() async {
    // 🚀 Show modern bottom sheet with options
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                // Gallery option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo_library, color: AppColors.primary),
                  ),
                  title: const Text(
                    'From Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Choose from your photos',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const Divider(height: 1),
                // Camera option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Use your camera',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 10),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
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

    if (source == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;

    setState(() => _isAvatarUploading = true);
    final ok = await UserService.updateAvatar(File(file.path));
    if (!mounted) return;
    setState(() => _isAvatarUploading = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error changing profile photo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _loadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo updated.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _phoneSaveTimer?.cancel(); // 🚀 NEW: Cancel timer on dispose
    super.dispose();
  }

  void _addInterest() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Interest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your interest'),
          onSubmitted: (_) {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              setState(() => _interests.add(value));
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() => _interests.add(value));
              }
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚀 NEW: Network connectivity warning
            if (_hasNetworkError)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network issues detected. Some images may not load.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        setState(() => _hasNetworkError = false);
                        await _checkConnectivity();
                        if (mounted) setState(() {});
                      },
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),

            // Profile photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[200],
                      child:
                          _avatarUrl != null &&
                              _avatarUrl!.isNotEmpty &&
                              !_hasNetworkError
                          ? ClipOval(
                              child: Image.network(
                                _avatarUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('❌ Error loading avatar: $error');
                                  _hasNetworkError = true;
                                  return const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey,
                                      );
                                    },
                              ),
                            )
                          : Stack(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                if (_hasNetworkError &&
                                    _avatarUrl != null &&
                                    _avatarUrl!.isNotEmpty)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () async {
                                        setState(
                                          () => _hasNetworkError = false,
                                        );
                                        await _checkConnectivity();
                                        if (mounted) setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.refresh,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isAvatarUploading ? null : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: _isAvatarUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            const Text(
              'Full Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Phone number field with country selector and auto-validation
            const Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),

            // 🚀 NEW: Modern phone field design
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 NEW: Current phone display with clear button
                  if (_storedPhone(_userData).isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_android,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: ${_storedPhone(_userData)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _phoneCtrl.clear();
                                _lastSavedPhone = '';
                                // Clear from local data
                                if (_userData != null) {
                                  _userData!['num_tel'] = '';
                                  _userData!['numTel'] = '';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.clear,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Country selector and input
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        // Country selector
                        Container(
                          width: 104,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              right: BorderSide(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _country,
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              items: _countries.map((String countryKey) {
                                return DropdownMenuItem<String>(
                                  value: countryKey,
                                  child: Row(
                                    children: [
                                      Text(
                                        _getCountryFlag(countryKey),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getCountryCode(countryKey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _country = v!;
                                  // Clear phone field when country changes to reformat for new country
                                  _phoneCtrl.clear();
                                  _isPhoneValid = false;
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
                              _formatPhoneNumber();
                              _validatePhone();
                              _savePhoneChange();
                            },
                            decoration: InputDecoration(
                              prefixText: '${_getCountryCode(_country)} ',
                              prefixStyle: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Enter new phone number',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              suffixIcon: _isPhoneValid
                                  ? Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🚀 NEW: Modern validation status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPhoneValid
                    ? Colors.green.withOpacity(0.08)
                    : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPhoneValid
                      ? Colors.green.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isPhoneValid ? Colors.green : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPhoneValid ? Icons.check : Icons.info_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPhoneValid
                              ? 'Valid Phone Number'
                              : 'Phone Format Required',
                          style: TextStyle(
                            color: _isPhoneValid ? Colors.green : Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isPhoneValid
                              ? 'Number is correctly formatted for ${_getCountryName(_country)}'
                              : 'Example: ${_getPhoneExample(_country)} (${_getMaxDigits(_country)} digits max)',
                          style: TextStyle(
                            color: _isPhoneValid
                                ? Colors.green.shade600
                                : Colors.blue.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Country dropdown
            const Text(
              'Country',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _originCountry, // 🚀 FIX: Use _originCountry, NOT _country
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  items: _countries
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _originCountry = v!), // 🚀 FIX: Update _originCountry only
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Language dropdown
            const Text(
              'Preferred Language',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _language,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  items: _languages
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setState(() => _language = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bio field
            const Text(
              'Bio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            if (!_isOrganizer) ...[
              const Text(
                'INTERESTS',
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: _interests.isEmpty
                    ? const Text(
                        'No interests yet. Add one below.',
                        style: TextStyle(color: AppColors.textGrey),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((interest) {
                          return Chip(
                            label: Text(interest),
                            onDeleted: () {
                              setState(() => _interests.remove(interest));
                            },
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _addInterest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add Interest',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 🚀 NEW: Edit Activity Specialties button (pour organisateurs)
            if (_isOrganizer) ...[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const EditActivitySpecialtiesScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Activity Specialties',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Save Profile',
                        style: TextStyle(
                          color: Colors.white,
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
  }
}
