import 'api_config.dart';

class AppConfig {
  // API Configuration
  static String get apiBaseUrl => ApiConfig.serverBaseUrl;
  static const String apiVersion = 'v1';
  static const String apiPath = '/api/$apiVersion';

  // AI Chat Configuration
  static const String aiChatUrl = 'http://localhost:3001';
  static const String aiChatEndpoint = '$aiChatUrl/api/chat';
  static const String aiSearchEndpoint = '$aiChatUrl/api/search';

  // App Configuration
  static const String appName = 'DJTrip';
  static const String appVersion = '1.0.0';
  static const bool debugMode = true;

  // Cache Configuration
  static const int cacheTtl = 300; // 5 minutes
  static const int maxCacheSize = 100; // MB

  // Timeout Configuration
  static const int connectionTimeout = 30; // seconds
  static const int receiveTimeout = 30; // seconds

  // Pagination Configuration
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // Image Configuration
  static const String defaultImagePlaceholder =
      'https://picsum.photos/seed/djerba/400/300.jpg';
  static const int maxImageSize = 5; // MB

  // Map Configuration
  static const double defaultLatitude = 33.8145; // Djerba
  static const double defaultLongitude = 10.8645; // Djerba
  static const double defaultZoom = 12.0;

  // Chat Configuration
  static const int maxMessageLength = 1000;
  static const int maxChatHistory = 50;

  // Notification Configuration
  static const bool enableNotifications = true;
  static const bool enableSound = true;
  static const bool enableVibration = true;

  // Security Configuration
  static const bool enableBiometric = false;
  static const int sessionTimeout = 24; // hours

  // Feature Flags
  static const bool enableAIChat = true;
  static const bool enableVideoCall = true;
  static const bool enableVoiceCall = true;
  static const bool enableLocationSharing = true;
  static const bool enableOfflineMode = false;
}
