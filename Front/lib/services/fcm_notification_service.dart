import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des notifications Firebase Cloud Messaging
/// Production-ready avec gestion foreground/background
class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._internal();
  factory FcmNotificationService() => _instance;
  FcmNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;
  
  bool _initialized = false;
  String? _currentToken;

  // Getters
  String? get currentToken => _currentToken;
  bool get isInitialized => _initialized;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Demander la permission pour iOS
      await _requestPermission();

      // 2. Configurer les notifications locales
      await _setupLocalNotifications();

      // 3. Récupérer le token FCM initial
      await _getInitialToken();

      // 4. Configurer les écouteurs de messages
      _setupMessageListeners();

      // 5. Configurer l'écouteur de token refresh
      _setupTokenListener();

      _initialized = true;
      debugPrint('✅ FCM Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FCM service: $e');
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

  /// Envoie le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    // TODO: Implémenter l'envoi du token au backend
    // Exemple:
    // await ApiClient.post('/user/fcm-token', {'fcmToken': token});
    debugPrint('Sending FCM token to backend: $token');
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

  /// Gère les messages reçus en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.notification?.title}');

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
      await _messaging.deleteToken();
      _currentToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
