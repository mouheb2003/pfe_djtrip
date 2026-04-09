import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _customInterestCtrl = TextEditingController();
  final _customSpecialtyCtrl = TextEditingController();
  final _customLanguageCtrl = TextEditingController();
  String _country = 'FR'; // 🚀 Country code for phone number
  String _originCountry =
      'FR'; // 🚀 FIX: Separate country of origin (completely independent)
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
  final List<String> _spokenLanguages = [];
  final List<String> _specialties = []; // 🚀 NEW: Organizer specialties
  final List<String> _interests = []; // Tourist interests

  static const List<String> _availableInterests = [
    'Adventure',
    'Beach',
    'Culture',
    'Food',
    'History',
    'Music',
    'Nature',
    'Photography',
    'Sports',
    'Wellness',
  ];

  static const int _maxInterests = 8;

  // 🚀 Spécialités d'activités avec emojis
  static const List<Map<String, String>> _availableSpecialties = [
    {'emoji': '🏃‍♂️', 'name': 'Sports & Aventure'},
    {'emoji': '🎵', 'name': 'Musique & Concerts'},
    {'emoji': '🎨', 'name': 'Art & Culture'},
    {'emoji': '🍽️', 'name': 'Gastronomie & Cuisine'},
    {'emoji': '🏖️', 'name': 'Plage & Mer'},
    {'emoji': '🏔️', 'name': 'Montagne & Randonnée'},
    {'emoji': '🏛️', 'name': 'Histoire & Patrimoine'},
    {'emoji': '🎮', 'name': 'Jeux & Divertissement'},
    {'emoji': '🧘', 'name': 'Bien-être & Spa'},
    {'emoji': '📸', 'name': 'Photographie & Tour'},
    {'emoji': '🚗', 'name': 'Transport & Excursion'},
    {'emoji': '🏕️', 'name': 'Camping & Nature'},
    {'emoji': '🎪', 'name': 'Festivals & Événements'},
  ];

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
    final role = _userType.trim().toLowerCase();
    return role == 'organisator' ||
        role == 'organisateur' ||
        role == 'organizer';
  }

  bool get _isTourist {
    final role = _userType.trim().toLowerCase();
    return role == 'touriste' || role == 'tourist';
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
    'US', // Etats-Unis
    'BR', // Bresil
    'PT', // Portugal
    'NL', // Pays-Bas
    'SE', // Suede
    'TR', // Turquie
    'JP', // Japon
    'IN', // Inde
    'AU', // Australie
    'MX', // Mexique
    'CN', // Chine
  ];
  static const List<String> _languages = [
    'French',
    'English',
    'العربية',
    'Deutsch',
    'Español',
    'Português',
    'Italiano',
    'Nederlands',
    'Türkçe',
    'Русский',
    '日本語',
    'हिन्दी',
    '中文',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkConnectivity(); // 🚀 NEW: Check connectivity on init
  }

  Future<void> _loadProfile() async {
    final user = await UserService.getProfile();

    if (mounted && user != null) {
      setState(() {
        _userData = user;
        _nameCtrl.text = user['fullname'] ?? '';

        // Extract phone number without country code
        String phoneNumber = _storedPhone(user);
        if (phoneNumber.isNotEmpty) {
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
        _lastSavedPhone = phoneNumber;

        _bioCtrl.text = user['bio'] ?? '';
        _avatarUrl =
            _toAbsoluteUrl(user['avatar']?.toString()) ??
            _toAbsoluteUrl(user['avatar_url']?.toString());
        _userType = user['userType'] ?? '';

        // Handle phone country separately from origin country
        final phoneCountryRaw = (user['pays_telephone'] ?? '').toString();
        if (phoneCountryRaw.trim().isNotEmpty) {
          final countryKey = _normalizeCountryKey(phoneCountryRaw);
          if (_countries.contains(countryKey)) {
            _country = countryKey;
          }
        }

        // Handle origin country separately
        final originCountryRaw = (user['pays_origine'] ?? '').toString();
        if (originCountryRaw.trim().isNotEmpty) {
          final countryKey = _normalizeCountryKey(originCountryRaw);
          if (_countries.contains(countryKey)) {
            _originCountry = countryKey;
          }
        }

        // Handle language
        if (user['langue_preferee'] != null &&
            user['langue_preferee']!.trim().isNotEmpty) {
          final l = _normalizeLanguage(user['langue_preferee']!);
          if (_languages.contains(l)) {
            _language = l;
          }
        }

        // Organizer-specific fields
        if (_isOrganizer) {
          final rawLangs = (user['langues_proposees'] as List?) ?? const [];
          _spokenLanguages
            ..clear()
            ..addAll(
              rawLangs
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty),
            );

          final rawSpecs = (user['specialites_activites'] as List?) ?? const [];
          _specialties
            ..clear()
            ..addAll(
              rawSpecs
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty),
            );
        }

        if (_isTourist) {
          final rawInterests =
              (user['centres_interet'] as List?) ??
              (user['interests'] as List?) ??
              const [];
          _interests
            ..clear()
            ..addAll(
              rawInterests
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty),
            );
        }
      });
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
        // Keep the raw national number and let the backend normalize it.
        final phoneToSave = currentPhone;
        final result = await UserService.updateProfile({
          'num_tel': phoneToSave,
          'numTel': phoneToSave,
          'pays_telephone': _getCountryName(
            _country,
          ), // 🚀 FIX: Save only phone country
        });

        if (result['success'] == true) {
          print('✅ Phone number updated: $phoneToSave');
          // 🚀 NEW: Update last saved phone
          _lastSavedPhone = currentPhone;
          // Update local data
          if (_userData != null) {
            _userData!['num_tel'] = phoneToSave;
            _userData!['numTel'] = phoneToSave;
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
    if (v == 'etats-unis' || v == 'états-unis' || v == 'usa' || v == 'us') {
      return 'US';
    }
    if (v == 'bresil' || v == 'brésil' || v == 'br') return 'BR';
    if (v == 'portugal' || v == 'pt') return 'PT';
    if (v == 'pays-bas' || v == 'netherlands' || v == 'nl') return 'NL';
    if (v == 'suede' || v == 'suède' || v == 'sweden' || v == 'se') {
      return 'SE';
    }
    if (v == 'turquie' || v == 'turkey' || v == 'tr') return 'TR';
    if (v == 'japon' || v == 'japan' || v == 'jp') return 'JP';
    if (v == 'inde' || v == 'india' || v == 'in') return 'IN';
    if (v == 'australie' || v == 'australia' || v == 'au') return 'AU';
    if (v == 'mexique' || v == 'mexico' || v == 'mx') return 'MX';
    if (v == 'chine' || v == 'china' || v == 'cn') return 'CN';
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
    if (v == 'spanish' || v == 'español' || v == 'es') return 'Español';
    if (v == 'portuguese' || v == 'português' || v == 'pt') {
      return 'Português';
    }
    if (v == 'italian' || v == 'italiano' || v == 'it') return 'Italiano';
    if (v == 'dutch' || v == 'nederlands' || v == 'nl') return 'Nederlands';
    if (v == 'turkish' || v == 'türkçe' || v == 'tr') return 'Türkçe';
    if (v == 'russian' || v == 'русский' || v == 'ru') return 'Русский';
    if (v == 'japanese' || v == '日本語' || v == 'ja') return '日本語';
    if (v == 'hindi' || v == 'हिन्दी' || v == 'hi') return 'हिन्दी';
    if (v == 'chinese' || v == '中文' || v == 'zh') return '中文';
    return raw;
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final phone = _phoneCtrl.text.trim();

    // 🚀 FIX: Ensure phone number has correct country code for the selected phone country
    final phoneCountryCode = _getCountryCode(_country);
    String formattedPhone = phone;

    // Remove any existing country codes and clean the number
    String cleanPhone = formattedPhone;

    // Remove common country codes if they exist
    final countryCodes = [
      '+213',
      '+39',
      '+33',
      '+216',
      '+212',
      '+218',
      '+44',
      '+49',
      '+34',
      '+32',
      '+41',
      '+1',
      '+20',
      '+55',
      '+351',
      '+31',
      '+46',
      '+90',
      '+81',
      '+91',
      '+61',
      '+52',
      '+86',
    ];
    for (final code in countryCodes) {
      if (cleanPhone.startsWith(code)) {
        cleanPhone = cleanPhone.substring(code.length).trim();
        break; // Only remove the first matching country code
      }
    }

    // Add the correct country code for the selected country
    formattedPhone = '$phoneCountryCode $cleanPhone';

    final data = <String, dynamic>{
      'fullname': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'num_tel': formattedPhone,
      'numTel': formattedPhone,
      'pays_telephone': _getCountryName(_country),
      'pays_origine': _getCountryName(_originCountry),
      'langue_preferee': _language,
    };

    // Add organizer-specific fields
    if (_isOrganizer) {
      data['langues_proposees'] = _spokenLanguages;
      data['specialites_activites'] = _specialties;
    }

    if (_isTourist) {
      data['centres_interet'] = _interests;
    }

    final result = await UserService.updateProfile(data);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      Navigator.pop(context);
    } else {
      // 🚀 FIX: Use post-frame callback to avoid build phase error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] as String? ?? 'Error saving profile',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
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
      'US': '+1',
      'BR': '+55',
      'PT': '+351',
      'NL': '+31',
      'SE': '+46',
      'TR': '+90',
      'JP': '+81',
      'IN': '+91',
      'AU': '+61',
      'MX': '+52',
      'CN': '+86',
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
      'US': '🇺🇸',
      'BR': '🇧🇷',
      'PT': '🇵🇹',
      'NL': '🇳🇱',
      'SE': '🇸🇪',
      'TR': '🇹🇷',
      'JP': '🇯🇵',
      'IN': '🇮🇳',
      'AU': '🇦🇺',
      'MX': '🇲🇽',
      'CN': '🇨🇳',
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
      'US': 'États-Unis',
      'BR': 'Brésil',
      'PT': 'Portugal',
      'NL': 'Pays-Bas',
      'SE': 'Suède',
      'TR': 'Turquie',
      'JP': 'Japon',
      'IN': 'Inde',
      'AU': 'Australie',
      'MX': 'Mexique',
      'CN': 'Chine',
    };
    return names[countryKey] ?? 'France';
  }

  String _getLanguageFlag(String language) {
    const flags = {
      'French': '🇫🇷',
      'English': '🇬🇧',
      'العربية': '🇸🇦',
      'Deutsch': '🇩🇪',
      'Español': '🇪🇸',
      'Português': '🇵🇹',
      'Italiano': '🇮🇹',
      'Nederlands': '🇳🇱',
      'Türkçe': '🇹🇷',
      'Русский': '🇷🇺',
      '日本語': '🇯🇵',
      'हिन्दी': '🇮🇳',
      '中文': '🇨🇳',
    };
    return flags[language] ?? '🌐';
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
      'US': 10,
      'BR': 11,
      'PT': 9,
      'NL': 9,
      'SE': 9,
      'TR': 10,
      'JP': 10,
      'IN': 10,
      'AU': 9,
      'MX': 10,
      'CN': 11,
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
      'US': '202 555 0143',
      'BR': '11 98765 4321',
      'PT': '912 345 678',
      'NL': '06 12345678',
      'SE': '070 123 45 67',
      'TR': '532 123 4567',
      'JP': '090 1234 5678',
      'IN': '98765 43210',
      'AU': '0412 345 678',
      'MX': '55 1234 5678',
      'CN': '138 1234 5678',
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
      'US': 10,
      'BR': 10,
      'PT': 9,
      'NL': 9,
      'SE': 9,
      'TR': 10,
      'JP': 10,
      'IN': 10,
      'AU': 9,
      'MX': 10,
      'CN': 11,
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
    _customInterestCtrl.dispose();
    _customSpecialtyCtrl.dispose();
    _customLanguageCtrl.dispose();
    _phoneSaveTimer?.cancel();
    super.dispose();
  }

  static const List<String> _availableSpokenLanguages = [
    'العربية',
    'Français',
    'English',
    'Deutsch',
    'Italiano',
    'Español',
    'Türkçe',
    'Русский',
  ];

  void _toggleSpokenLanguage(String lang) {
    setState(() {
      if (_spokenLanguages.contains(lang)) {
        _spokenLanguages.remove(lang);
      } else {
        _spokenLanguages.add(lang);
      }
    });
  }

  void _toggleSpecialty(String specialty) {
    setState(() {
      if (_specialties.contains(specialty)) {
        _specialties.remove(specialty);
      } else {
        _specialties.add(specialty);
      }
    });
  }

  void _addCustomSpecialty() {
    final custom = _customSpecialtyCtrl.text.trim();
    if (custom.isNotEmpty && !_specialties.contains(custom)) {
      setState(() {
        _specialties.add(custom);
        _customSpecialtyCtrl.clear();
      });
    }
  }

  void _addCustomSpokenLanguage() {
    final custom = _customLanguageCtrl.text.trim();
    if (custom.isEmpty) return;
    if (_spokenLanguages.any((l) => l.toLowerCase() == custom.toLowerCase())) {
      _customLanguageCtrl.clear();
      return;
    }
    setState(() {
      _spokenLanguages.add(custom);
      _customLanguageCtrl.clear();
    });
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_interests.contains(interest)) {
        _interests.remove(interest);
      } else {
        if (_interests.length >= _maxInterests) {
          _showInterestsLimitMessage();
          return;
        }
        _interests.add(interest);
      }
    });
  }

  void _addCustomInterest() {
    final custom = _customInterestCtrl.text.trim();
    if (custom.isNotEmpty && !_interests.contains(custom)) {
      if (_interests.length >= _maxInterests) {
        _showInterestsLimitMessage();
        return;
      }
      setState(() {
        _interests.add(custom);
        _customInterestCtrl.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _interests.remove(interest);
    });
  }

  void _showInterestsLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You can select up to 8 interests.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _touristSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A91B8),
        ),
      ),
    );
  }

  InputDecoration _touristInputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA3A8C3), fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF5A7BFF), width: 1.5),
      ),
    );
  }

  Widget _buildTouristScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF4C4F86),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF6C8BFF)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF335BFF).withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'SAVE PROFILE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFFE4E8FF),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              (_avatarUrl != null &&
                                  _avatarUrl!.isNotEmpty &&
                                  !_hasNetworkError)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child:
                              (_avatarUrl == null ||
                                  _avatarUrl!.isEmpty ||
                                  _hasNetworkError)
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xFFA5ACC8),
                                  size: 40,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: _isAvatarUploading
                              ? null
                              : _pickAndUploadAvatar,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _isAvatarUploading
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isAvatarUploading ? null : _pickAndUploadAvatar,
                    child: const Text(
                      'CHANGE AVATAR',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _touristSectionLabel('FULL NAME'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _touristInputDecoration(hint: 'Your full name'),
            ),
            const SizedBox(height: 14),
            _touristSectionLabel('PHONE NUMBER'),
            if (_storedPhone(_userData).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFFD1D5E8)),
                    const SizedBox(width: 6),
                    Text(
                      'Current: ${_storedPhone(_userData)}',
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 71,
                  child: DropdownButtonFormField<String>(
                    value: _country,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    decoration: _touristInputDecoration(),
                    items: _countries
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                                _getCountryFlag(c),
                                style: const TextStyle(fontSize: 10),
                              ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _country = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) {
                      _formatPhoneNumber();
                      _validatePhone();
                      _savePhoneChange();
                    },
                    decoration: _touristInputDecoration(
                      hint: _getPhoneExample(_country),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _touristSectionLabel('COUNTRY'),
            DropdownButtonFormField<String>(
              value: _originCountry,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              decoration: _touristInputDecoration(),
              items: _countries
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Text(
                            _getCountryFlag(c),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getCountryName(c),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _originCountry = v);
              },
            ),
            const SizedBox(height: 14),
            _touristSectionLabel('PREFERRED LANGUAGE'),
            DropdownButtonFormField<String>(
              value: _language,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              decoration: _touristInputDecoration(),
              items: _languages
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Row(
                        children: [
                          Text(
                            _getLanguageFlag(l),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(l, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _language = v);
              },
            ),
            const SizedBox(height: 14),
            _touristSectionLabel('BIO'),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: _touristInputDecoration(
                hint: 'Tell us about your travel style...',
              ),
            ),
            const SizedBox(height: 14),
            if (_isTourist) ...[
              Row(
                children: [
                  _touristSectionLabel('INTERESTS & HOBBIES'),
                  const Spacer(),
                  Text(
                    '${_interests.length} SELECTED',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableInterests.map((interest) {
                    final selected = _interests.contains(interest);
                    return InkWell(
                      onTap: () => _toggleInterest(interest),
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2B63EA)
                              : const Color(0xFFE9ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF5B6190),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_interests.any((i) => !_availableInterests.contains(i))) ...[
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests
                        .where((i) => !_availableInterests.contains(i))
                        .map(
                          (interest) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF4B63FF).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFF4B63FF),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    interest,
                                    style: const TextStyle(
                                      color: Color(0xFF4B63FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeInterest(interest),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF4B63FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customInterestCtrl,
                      enabled: _interests.length < _maxInterests,
                      decoration: _touristInputDecoration(
                        hint: 'Add custom interest',
                      ),
                      onSubmitted: (_) => _addCustomInterest(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _interests.length >= _maxInterests
                          ? null
                          : _addCustomInterest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCFD5FF),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
            if (_isOrganizer) ...[
              Row(
                children: [
                  _touristSectionLabel('SPECIALIZED ACTIVITIES'),
                  const Spacer(),
                  Text(
                    '${_specialties.length} SELECTED',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSpecialties.map((item) {
                    final name = item['name']!;
                    final selected = _specialties.contains(name);
                    return InkWell(
                      onTap: () => _toggleSpecialty(name),
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2B63EA)
                              : const Color(0xFFE9ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item['emoji']} $name',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF5B6190),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customSpecialtyCtrl,
                      decoration: _touristInputDecoration(
                        hint: 'Add custom specialties',
                      ),
                      onSubmitted: (_) => _addCustomSpecialty(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addCustomSpecialty,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCFD5FF),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _touristSectionLabel('SPOKEN LANGUAGES'),
                  const Spacer(),
                  Text(
                    '${_spokenLanguages.length} SELECTED',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSpokenLanguages.map((lang) {
                    final selected = _spokenLanguages.contains(lang);
                    return InkWell(
                      onTap: () => _toggleSpokenLanguage(lang),
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2B63EA)
                              : const Color(0xFFE9ECFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF5B6190),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customLanguageCtrl,
                      decoration: _touristInputDecoration(
                        hint: 'Add custom languages',
                      ),
                      onSubmitted: (_) => _addCustomSpokenLanguage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addCustomSpokenLanguage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCFD5FF),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTouristScaffold();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isOrganizer ? 'Edit Organizer' : 'Edit Profile',
          style: const TextStyle(
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
              child: TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  hintText: 'Enter your full name',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
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
                                  // 🚀 FIX: Preserve current phone number when country changes
                                  final currentPhone = _phoneCtrl.text.trim();
                                  _country = v!;

                                  // Only clear if there's no current phone number
                                  if (currentPhone.isEmpty) {
                                    _phoneCtrl.clear();
                                    _isPhoneValid = false;
                                  }
                                  // Phone number will be automatically reformatted when saved
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
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Phone number',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _originCountry,
                  isExpanded: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ),
                  items: _countries
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.public_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(c, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _originCountry = v!),
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _language,
                  isExpanded: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ),
                  items: _languages
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.translate_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(l, style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      )
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
              child: TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tell us a bit about yourself...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isTourist) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFF3B82F6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Interests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2458),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_interests.length}/$_maxInterests',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose interests to personalize your profile',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7AA0)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableInterests.map((interest) {
                        final isSelected = _interests.contains(interest);
                        final isAtLimit =
                            _interests.length >= _maxInterests && !isSelected;
                        return GestureDetector(
                          onTap: isAtLimit
                              ? _showInterestsLimitMessage
                              : () => _toggleInterest(interest),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : (isAtLimit
                                        ? const Color(0xFFF3F4F6)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (isAtLimit
                                          ? const Color(0xFFE5E7EB)
                                          : const Color(0xFFBFDBFE)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                Text(
                                  interest,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isAtLimit
                                              ? const Color(0xFF9CA3AF)
                                              : const Color(0xFF1E3A8A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_interests.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Selected interests',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7AA0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests
                            .map(
                              (interest) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCE8FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFA5B4FC),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        interest,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeInterest(interest),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customInterestCtrl,
                            decoration: InputDecoration(
                              hintText: _interests.length >= _maxInterests
                                  ? 'Maximum reached (8 interests)'
                                  : 'Add custom interest...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFBFDBFE),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFBFDBFE),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            enabled: _interests.length < _maxInterests,
                            onSubmitted: (_) => _addCustomInterest(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _interests.length >= _maxInterests
                              ? null
                              : _addCustomInterest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── ORGANIZER: Extra Fields Section ──────────────────────
            if (_isOrganizer) ...[
              // Spoken Languages
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF059669).withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.translate_rounded,
                            color: Color(0xFF059669),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Spoken Languages',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2458),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🎯 ORGANIZER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select languages you can guide activities in',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7AA0)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSpokenLanguages.map((lang) {
                        final isSelected = _spokenLanguages.contains(lang);
                        return GestureDetector(
                          onTap: () => _toggleSpokenLanguage(lang),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF059669)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    lang,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Activity Specialties selection
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Activity Specialties',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2458),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose the types of activities you offer',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7AA0)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSpecialties.map((spec) {
                        final name = spec['name']!;
                        final emoji = spec['emoji']!;
                        final isSelected = _specialties.contains(name);
                        return GestureDetector(
                          onTap: () => _toggleSpecialty(name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD97706)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFFED7AA),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    '$emoji $name',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF9A3412),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // 🚀 NEW: Custom specialty input
              if (_isOrganizer)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
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
                      const Text(
                        'Add Custom Specialty',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Don\'t see your specialty? Add it here!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7AA0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customSpecialtyCtrl,
                              decoration: InputDecoration(
                                hintText: 'Enter custom specialty...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _addCustomSpecialty(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addCustomSpecialty,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 🚀 NEW: Show custom specialties that were added
                      if (_specialties.any(
                        (s) => !_availableSpecialties.any(
                          (spec) => spec['name'] == s,
                        ),
                      ))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            const Text(
                              'Custom Specialties Added:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7AA0),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _specialties
                                  .where(
                                    (s) => !_availableSpecialties.any(
                                      (spec) => spec['name'] == s,
                                    ),
                                  )
                                  .map((custom) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF4B63FF).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 12,
                                            color: Color(0xFF4B63FF),
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              custom,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF4B63FF),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          GestureDetector(
                                            onTap: () =>
                                                _toggleSpecialty(custom),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Color(0xFF4B63FF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ],
                        ),
                    ],
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
                    : Text(
                        _isOrganizer
                            ? 'Save Organizer Profile'
                            : 'Save Profile',
                        style: const TextStyle(
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
