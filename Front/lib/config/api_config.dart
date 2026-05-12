import 'env_config.dart';

class ApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const List<String> devUrls = [
    'http://10.0.2.2:3000',
    'http://192.168.55.99:3000',
    'http://192.168.51.99:3000',
    'http://192.168.100.9:3000',
    'http://192.168.1.189:3000',
    'http://172.20.10.2:3000',
  ];

  static String _ensureScheme(String url) {
    final value = url.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'http://$value';
  }

  static String get serverBaseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _ensureScheme(_overrideBaseUrl);
    }

    if (EnvConfig.isProd || EnvConfig.isStaging) {
      return 'https://backdjtrip.onrender.com';
    }

    // Default local API target for Android emulator.
    return _ensureScheme('http://192.168.55.99:3000');
  }

  static String get baseUrl => '$serverBaseUrl/api/v1';

  // ── Endpoints ────────────────────────────────────────────────────────────
  static String get signUp => '$baseUrl/users/signup';
  static String get signIn => '$baseUrl/users/signin';
  static String get forgotPassword => '$baseUrl/users/forgot-password';
  static String get resetPassword => '$baseUrl/users/reset-password';
  static String get logout => '$baseUrl/users/logout';
  static String get refreshToken => '$baseUrl/users/refresh-token';
  static String get myInfo => '$baseUrl/users/me';
  static String get updateProfile => '$baseUrl/users/me';
  static String get updateAvatar => '$baseUrl/users/me/avatar';
  static String get deleteAvatar => '$baseUrl/users/me/avatar';
  static String get users => '$baseUrl/users';
  static String get touristes => '$baseUrl/touristes';
  static String get organisators => '$baseUrl/organisators';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
