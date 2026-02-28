class ApiConfig {
  // URL de base de l'API - Changez cette valeur selon votre environnement

  // ========================================
  // CHOISISSEZ LA CONFIGURATION ADAPTÉE :
  // ========================================

  // 1. Pour ÉMULATEUR ANDROID (Android Studio AVD)
  static const String baseUrl = 'http://192.168.3.12:3000/api';

  // 2. Pour APPAREIL PHYSIQUE (Android/iOS)
  // Trouvez votre IP avec : ipconfig (Windows) ou ifconfig (Mac/Linux)
  // Remplacez 192.168.1.X par VOTRE IP
  // static const String baseUrl = 'http://192.168.1.X:3000/api';

  // 3. Pour iOS SIMULATOR
  // static const String baseUrl = 'http://localhost:3000/api';

  // 4. Pour PRODUCTION
  // static const String baseUrl = 'https://api.travelo.com/api';

  // ========================================
  // Endpoints
  static const String signUp = '$baseUrl/users/signup';
  static const String signIn = '$baseUrl/users/signin';
  static const String logout = '$baseUrl/users/logout';
  static const String refreshToken = '$baseUrl/users/refresh-token';
  static const String myInfo = '$baseUrl/users/me';
  static const String updateProfile = '$baseUrl/users/me';
  static const String updateAvatar = '$baseUrl/users/me/avatar';
  static const String users = '$baseUrl/users';
  static const String touristes = '$baseUrl/touristes';
  static const String organisators = '$baseUrl/organisators';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
