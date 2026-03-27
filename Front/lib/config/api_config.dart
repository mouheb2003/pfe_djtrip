class ApiConfig {
  // Base URL for the API.
  // Set at build/run time with: --dart-define=API_URL=http://your-server:3000/api/v1
  //
  // Common values:
  //   Android emulator  → http://10.0.2.2:3000/api/v1
  //   Physical device   → http://<your-local-ip>:3000/api/v1
  //   iOS simulator     → http://localhost:3000/api/v1
  //   Production        → https://api.djtrip.com/api/v1
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  // Backward compatible normalization:
  // if someone passes .../api, we automatically append /v1.
  static String get baseUrl {
    if (_rawBaseUrl.endsWith('/api')) return '${_rawBaseUrl}/v1';
    if (_rawBaseUrl.endsWith('/api/')) return '${_rawBaseUrl}v1';
    return _rawBaseUrl;
  }

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
