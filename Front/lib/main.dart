import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart'; // 🔥 AJOUT IMPORTANT

import 'config/app_routes.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/navigation_service.dart';
import 'services/fcm_notification_service.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

// ✅ GLOBAL SNACKBAR KEY
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

  @override
  void initState() {
    super.initState();
    _disableDebugOverlays();
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