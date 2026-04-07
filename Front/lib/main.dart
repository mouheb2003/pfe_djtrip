import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 IMPORTANT
import 'config/app_routes.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/navigation_service.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

// ✅ ADDED
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ✅ ADDED
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

  // 👇 Initialisation des locales (corrige ton erreur)
  await initializeDateFormatting();

  // 👇 Ton service de thème
  await ThemeService.init();

  // ✅ ADDED
  await ApiService.instance.initialize();
  await ApiService.instance.warmUp();

  // Ensure debug paint overlays stay off (prevents yellow baseline lines).
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
