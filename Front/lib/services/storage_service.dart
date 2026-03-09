import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userTypeKey = 'user_type';

  // Remember Me - Secure Storage Keys
  static const String _rememberMeEnabledKey = 'remember_me_enabled';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';

  // Secure storage instance
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Sauvegarder les tokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Récupérer l'access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Récupérer le refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Sauvegarder les informations utilisateur
  static Future<void> saveUserInfo({
    required String userId,
    required String email,
    required String userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userTypeKey, userType);
  }

  // Récupérer les informations utilisateur
  static Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userIdKey),
      'email': prefs.getString(_userEmailKey),
      'userType': prefs.getString(_userTypeKey),
    };
  }

  // Vérifier si l'utilisateur est connecté
  static Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Effacer toutes les données (logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userTypeKey);
  }

  // ============= REMEMBER ME FUNCTIONALITY =============

  /// Save credentials securely when "Remember Me" is enabled
  static Future<void> saveRememberMeCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeEnabledKey, true);
    await _secureStorage.write(key: _savedEmailKey, value: email);
    await _secureStorage.write(key: _savedPasswordKey, value: password);
  }

  /// Get saved credentials if "Remember Me" was enabled
  static Future<Map<String, String?>> getRememberMeCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMeEnabled = prefs.getBool(_rememberMeEnabledKey) ?? false;

    if (!rememberMeEnabled) {
      return {'email': null, 'password': null};
    }

    final email = await _secureStorage.read(key: _savedEmailKey);
    final password = await _secureStorage.read(key: _savedPasswordKey);

    return {'email': email, 'password': password};
  }

  /// Check if "Remember Me" is enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeEnabledKey) ?? false;
  }

  /// Clear saved credentials (when user unchecks "Remember Me" or logs out)
  static Future<void> clearRememberMeCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeEnabledKey, false);
    await _secureStorage.delete(key: _savedEmailKey);
    await _secureStorage.delete(key: _savedPasswordKey);
  }

  /// Clear all data including Remember Me credentials
  static Future<void> clearAllData() async {
    await clearAll();
    await clearRememberMeCredentials();
  }
}
