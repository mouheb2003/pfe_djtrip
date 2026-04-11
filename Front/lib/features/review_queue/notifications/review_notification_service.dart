import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/booking_review_model.dart';
import '../services/review_queue_service.dart';

/// Service de gestion des notifications push pour les reviews
/// Utilise Firebase Cloud Messaging (FCM)
class ReviewNotificationService {
  final ReviewQueueService _queueService;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _notifications;

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  // Configuration des rappels
  static const List<Duration> _reminderDelays = [
    Duration(days: 2),  // 1er rappel
    Duration(days: 5),  // 2ème rappel
    Duration(days: 7),  // 3ème rappel
  ];

  ReviewNotificationService({
    required ReviewQueueService queueService,
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin notifications,
  })  : _queueService = queueService,
        _messaging = messaging,
        _notifications = notifications {
    _initialize();
  }

  /// Initialise le service de notifications
  Future<void> _initialize() async {
    try {
      // Demander la permission pour les notifications
      await _requestPermission();

      // Configurer les notifications locales
      await _setupLocalNotifications();

      // Écouter les messages FCM
      _setupMessageListeners();

      // Écouter les changements de token
      _setupTokenListener();

      debugPrint('ReviewNotificationService initialized');
    } catch (e) {
      debugPrint('Error initializing ReviewNotificationService: $e');
    }
  }

  /// Demande la permission pour les notifications
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Configure les notifications locales
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Configure les écouteurs de messages FCM
  void _setupMessageListeners() {
    // Message reçu quand l'app est en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Message reçu quand l'app est en background mais ouverte
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Message reçu quand l'app est terminée
    _messageSubscription = _messaging.onMessage.listen((message) {
      _handleForegroundMessage(message);
    });
  }

  /// Écoute les changements de token FCM
  void _setupTokenListener() {
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM token refreshed: $token');
      // Envoyer le token au backend
      _sendTokenToBackend(token);
    });
  }

  /// Gère les messages reçus en foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.notification?.title}');

    // Afficher une notification locale
    await _showLocalNotification(
      title: message.notification?.title ?? 'Review Reminder',
      body: message.notification?.body ?? 'You have pending reviews',
      payload: message.data['bookingId'],
    );
  }

  /// Gère les messages reçus en background
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Received background message: ${message.notification?.title}');

    // Naviguer vers l'écran de review approprié
    final bookingId = message.data['bookingId'];
    if (bookingId != null) {
      _navigateToReviewScreen(bookingId);
    }
  }

  /// Gère le tap sur une notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    final bookingId = response.payload;
    if (bookingId != null) {
      _navigateToReviewScreen(bookingId);
    }
  }

  /// Affiche une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'review_reminders',
      'Review Reminders',
      channelDescription: 'Notifications for pending reviews',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Planifie des rappels automatiques pour un booking
  Future<void> scheduleReminders(BookingReviewModel booking) async {
    for (final delay in _reminderDelays) {
      final reminderTime = booking.endDate.add(delay);
      
      // Envoyer une notification programmée via le backend
      await _scheduleBackendReminder(
        bookingId: booking.id,
        activityTitle: booking.activityTitle,
        reminderTime: reminderTime,
      );
    }
  }

  /// Planifie un rappel via le backend
  Future<void> _scheduleBackendReminder({
    required String bookingId,
    required String activityTitle,
    required DateTime reminderTime,
  }) async {
    // Cette méthode devrait communiquer avec votre backend
    // pour planifier l'envoi d'une notification FCM à l'heure spécifiée
    
    try {
      // Exemple d'implémentation (à adapter selon votre API)
      /*
      await http.post(
        Uri.parse('$baseUrl/notifications/schedule'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'bookingId': bookingId,
          'activityTitle': activityTitle,
          'reminderTime': reminderTime.toIso8601String(),
          'type': 'review_reminder',
        }),
      );
      */
      
      debugPrint('Scheduled reminder for $activityTitle at $reminderTime');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Annule les rappels pour un booking
  Future<void> cancelReminders(String bookingId) async {
    // Annuler les rappels côté backend
    try {
      /*
      await http.delete(
        Uri.parse('$baseUrl/notifications/schedule/$bookingId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      */
      
      debugPrint('Cancelled reminders for booking $bookingId');
    } catch (e) {
      debugPrint('Error cancelling reminders: $e');
    }
  }

  /// Envoie le token FCM au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      /*
      await http.post(
        Uri.parse('$baseUrl/user/fcm-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcmToken': token}),
      );
      */
      
      debugPrint('FCM token sent to backend');
    } catch (e) {
      debugPrint('Error sending FCM token: $e');
    }
  }

  /// Navigue vers l'écran de review
  void _navigateToReviewScreen(String bookingId) {
    // Cette méthode devrait être implémentée selon votre navigation
    // Par exemple, en utilisant Navigator ou un router comme GoRouter
    
    debugPrint('Navigate to review screen for booking: $bookingId');
    
    /*
    navigatorKey.currentState?.pushNamed(
      '/review',
      arguments: {'bookingId': bookingId},
    );
    */
  }

  /// Vérifie et déclenche les rappels pour la queue actuelle
  Future<void> checkAndTriggerReminders() async {
    final queue = _queueService.queue;
    
    for (final item in queue) {
      if (!item.booking.isReviewed) {
        await scheduleReminders(item.booking);
      }
    }
  }

  /// Dispose le service
  void dispose() {
    _messageSubscription?.cancel();
    _tokenSubscription?.cancel();
  }
}
