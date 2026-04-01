import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 IMPORTANT
import 'config/app_routes.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Initialisation des locales (corrige ton erreur)
  await initializeDateFormatting();

  // 👇 Ton service de thème
  await ThemeService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'DJTrip',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}