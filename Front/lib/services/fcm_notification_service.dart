import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Service de gestion des notifications Firebase Cloud Messaging
/// Production-ready avec gestion foreground/background
class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._internal();
  factory FcmNotificationService() => _instance;
  FcmNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  bool _initialized = false;
  String? _currentToken;
  String? _deviceId;

  // Getters
  String? get currentToken => _currentToken;
  bool get isInitialized => _initialized;
  String? get deviceId => _deviceId;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Generate unique deviceId
      await _generateDeviceId();

      // 2. Demander la permission pour iOS
      await _requestPermission();

      // 3. Configurer les notifications locales
      await _setupLocalNotifications();

      // 4. Récupérer le token FCM initial (avec gestion d'erreur)
      await _getInitialToken();

      // 5. Configurer les écouteurs de messages
      _setupMessageListeners();

      // 6. Configurer l'écouteur de token refresh
      _setupTokenListener();

      _initialized = true;
      debugPrint('✅ FCM Notification Service initialized with deviceId: $_deviceId');
    } catch (e) {
      debugPrint('❌ Error initializing FCM service: $e');
      debugPrint('⚠️ App will continue without FCM push notifications');
      // Marquer comme initialisé même si FCM échoue pour éviter les blocages
      _initialized = true;
    }
  }

  /// Generate unique deviceId for this device
  Future<void> _generateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_id');

      if (_deviceId == null || _deviceId!.isEmpty) {
        // Generate new deviceId if not exists
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await _deviceInfo.androidInfo;
          _deviceId = 'android_${androidInfo.id}_${DateTime.now().millisecondsSinceEpoch}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          _deviceId = 'ios_${iosInfo.identifierForVendor}_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          _deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        }

        await prefs.setString('device_id', _deviceId!);
        debugPrint('🆔 Generated new deviceId: $_deviceId');
      } else {
        debugPrint('🆔 Using existing deviceId: $_deviceId');
      }
    } catch (e) {
      debugPrint('❌ Error generating deviceId: $e');
      // Fallback to timestamp-based deviceId
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Demande la permission pour les notifications (iOS)
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('⚠️ Notification permission not granted');
    }
  }

  /// Configure les notifications locales pour Android/iOS
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'djtrip_notifications',
      'DJTrip Notifications',
      description: 'Notifications pour DJTrip',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Récupère le token FCM initial
  Future<void> _getInitialToken() async {
    try {
      _currentToken = await _messaging.getToken();
      
      if (_currentToken != null) {
        debugPrint('FCM Token: $_currentToken');
        await _saveTokenLocally(_currentToken!);
        await _sendTokenToBackend(_currentToken!);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Sauvegarde le token localement
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      debugPrint('Error saving FCM token locally: $e');
    }
  }

  /// Récupère le token depuis le stockage local
  Future<String?> getSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      debugPrint('Error getting saved FCM token: $e');
      return null;
    }
  }

  /// Envoie le token au backend avec deviceId
  Future<void> _sendTokenToBackend(String token) async {
    try {
      if (_deviceId == null || _deviceId!.isEmpty) {
        debugPrint('⚠️ No deviceId available, generating...');
        await _generateDeviceId();
      }

      // Check if user is authenticated before sending token
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ User not authenticated, skipping FCM token send');
        return;
      }

      final response = await ApiClient.post(
        '/users/me/fcm-token',
        {
          'token': token,
          'deviceId': _deviceId,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token sent to backend successfully with deviceId: $_deviceId');
      } else if (response.statusCode == 401) {
        debugPrint('⚠️ User not authenticated, will retry after login');
      } else {
        debugPrint('⚠️ Failed to send FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token to backend: $e');
    }
  }

  /// Configure les écouteurs de messages FCM
  void _setupMessageListeners() {
    // Message reçu quand l'app est en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Message reçu quand l'app est en background mais ouverte
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  /// Configure l'écouteur de token refresh
  void _setupTokenListener() {
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM Token refreshed: $token');
      _currentToken = token;
      _saveTokenLocally(token);
      _sendTokenToBackend(token);
    });
  }

  /// Send FCM token to backend (call this after user login)
  Future<void> sendTokenToBackend() async {
    if (_currentToken == null) {
      debugPrint('⚠️ No FCM token available, fetching...');
      await _getInitialToken();
    }
    if (_currentToken != null) {
      await _sendTokenToBackend(_currentToken!);
    }
  }

  /// Gère les messages reçus en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Received foreground message: ${message.notification?.title}');
    debugPrint('📱 Message ID: ${DateTime.now().millisecondsSinceEpoch}');

    // Afficher une notification locale
    await _showLocalNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );

    // Callback personnalisable
    _onForegroundMessage?.call(message);
  }

  /// Gère les messages reçus en background
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Received background message: ${message.notification?.title}');

    // Callback personnalisable
    _onBackgroundMessage?.call(message);
  }

  /// Gère le tap sur une notification locale
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _onNotificationTappedCallback?.call(response.payload);
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'djtrip_notifications',
      'DJTrip Notifications',
      channelDescription: 'Notifications pour DJTrip',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Callbacks personnalisables
  Function(RemoteMessage)? _onForegroundMessage;
  Function(RemoteMessage)? _onBackgroundMessage;
  Function(String?)? _onNotificationTappedCallback;

  /// Définit le callback pour les messages en foreground
  void setOnForegroundMessage(Function(RemoteMessage) callback) {
    _onForegroundMessage = callback;
  }

  /// Définit le callback pour les messages en background
  void setOnBackgroundMessage(Function(RemoteMessage) callback) {
    _onBackgroundMessage = callback;
  }

  /// Définit le callback pour le tap sur notification
  void setOnNotificationTapped(Function(String?) callback) {
    _onNotificationTappedCallback = callback;
  }

  /// Nettoie les ressources
  void dispose() {
    _messageSubscription?.cancel();
    _tokenSubscription?.cancel();
  }

  /// Supprime le token FCM (logout)
  Future<void> deleteToken() async {
    try {
      // Remove token from backend first
      if (_deviceId != null && _deviceId!.isNotEmpty) {
        await _removeTokenFromBackend();
      }

      // Then delete local token
      await _messaging.deleteToken();
      _currentToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      debugPrint('✅ FCM token deleted for deviceId: $_deviceId');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Remove token from backend
  Future<void> _removeTokenFromBackend() async {
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ User not authenticated, skipping token removal');
        return;
      }

      final response = await ApiClient.delete('/users/me/fcm-token/$_deviceId');

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token removed from backend successfully');
      } else {
        debugPrint('⚠️ Failed to remove FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error removing FCM token from backend: $e');
    }
  }
}
