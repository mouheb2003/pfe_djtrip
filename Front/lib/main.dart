import 'dart:ui';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'config/app_routes.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/navigation_service.dart';
import 'services/fcm_notification_service.dart';
import 'services/auth_service.dart';
import 'services/heartbeat_service.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

// GLOBAL SNACKBAR KEY
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void _showGlobalError(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 Show status bar and navigation bar (edge to edge mode)
  // Status bar and navigation bar will always be visible
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  try {
    // 🔥 1. INITIALISER FIREBASE (OBLIGATOIRE)
    await Firebase.initializeApp();

    // 🌍 Locales
    await initializeDateFormatting();

    // 🎨 Theme
    await ThemeService.init();

    // 🌐 API
    await ApiService.instance.initialize();
    await ApiService.instance.warmUp();

    // 🔔 FCM (APRÈS Firebase)
    await FcmNotificationService().initialize();
    
    // 💓 Initialize heartbeat service (will start when user is authenticated)
    developer.log('💓 [HEARTBEAT] Service initialized', name: 'Main');
  } catch (e) {
    debugPrint("❌ Init error: $e");
  }

  // 🔧 Disable debug overlays
  assert(() {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugPaintPointersEnabled = false;
    debugRepaintRainbowEnabled = false;
    return true;
  }());

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void _disableDebugOverlays() {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    debugPaintLayerBordersEnabled = false;
    debugPaintPointersEnabled = false;
    debugRepaintRainbowEnabled = false;
  }

  void _setupNotificationTapHandler() {
    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });

    // Handle notification taps when app is in foreground
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message);
    });

    // Set up local notification tap handler
    FcmNotificationService().setOnNotificationTapped((payload) {
      if (payload != null) {
        _handleLocalNotificationTap(payload);
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint(' Notification tapped: ${message.notification?.title}');
    final data = message.data;
    final type = data['type'] as String? ?? 'system';
    _navigateToScreen(type, data);
  }

  void _handleLocalNotificationTap(String? payload) {
    debugPrint(' Local notification tapped: $payload');
    if (payload == null) return;
    try {
      // Parse the payload (it's a JSON string)
      final data = <String, dynamic>{};
      final parts = payload.split(',');
      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          data[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      final type = data['type'] as String? ?? 'system';
      _navigateToScreen(type, data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  void _navigateToScreen(String type, Map<String, dynamic> data) async {
    final user = await AuthService.getUser();
    if (user == null) {
      debugPrint('User not logged in, navigating to login');
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    final userType = user['userType'] as String? ?? 'Touriste';
    debugPrint(' Current user type: $userType');
    final isOrganizer = userType.toLowerCase() == 'organisateur' || userType.toLowerCase() == 'organizer';
    debugPrint(' Is organizer: $isOrganizer');

    int initialIndex = 0;
    String targetRoute = isOrganizer ? AppRoutes.organizerMain : AppRoutes.touristMain;

    // Determine target tab based on notification type
    switch (type) {
      case 'new_message':
        initialIndex = isOrganizer ? 3 : 5; // Messages tab
        break;
      case 'booking':
      case 'booking_approved':
      case 'booking_rejected':
      case 'booking_cancelled':
      case 'booking_reminder':
      case 'booking_checkin':
        initialIndex = isOrganizer ? 0 : 2; // Activities/Bookings tab
        break;
      case 'new_review':
      case 'review_reminder':
        initialIndex = isOrganizer ? 0 : 2; // Activities tab
        break;
      case 'new_comment':
      case 'comment_reply':
        initialIndex = isOrganizer ? 2 : 3; // Network tab
        break;
      case 'new_follower':
      case 'follow_accepted':
        initialIndex = isOrganizer ? 2 : 3; // Network tab
        break;
      default:
        initialIndex = 0; // Default to first tab
    }

    debugPrint(' Navigating to $targetRoute with initialIndex: $initialIndex');
    NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      targetRoute,
      (route) => false,
      arguments: {'initialIndex': initialIndex},
    );
  }

  @override
  void initState() {
    super.initState();
    _disableDebugOverlays();
    _setupNotificationTapHandler();
  }

  @override
  Widget build(BuildContext context) {
    _disableDebugOverlays();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (_, mode, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(
            create: (_) => UserProvider()..loadUser(),
          ),
        ],
        child: MaterialApp(
          title: 'DJTrip',
          navigatorKey: NavigationService.navigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,

          builder: (context, child) {
            _disableDebugOverlays();
            return DefaultTextStyle.merge(
              style: const TextStyle(
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
                decorationThickness: 0,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },

          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,

          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}