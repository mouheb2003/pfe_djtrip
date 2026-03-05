import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travelo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFFFF6B1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFFF6B1A),
          primary: Color(0xFFFF6B1A),
          secondary: Color(0xFFFFB84D),
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(), // On démarre avec le splash screen
    );
  }
}
