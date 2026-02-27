import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/auth/new_signup_screen.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'screens/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Vérifier si l'utilisateur est déjà connecté
  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 3));

    final isLoggedIn = await StorageService.isLoggedIn();

    if (isLoggedIn) {
      // Utilisateur connecté - récupérer les infos et aller vers Welcome
      final result = await AuthService.getMyInfo();
      if (result['success']) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(user: result['user']),
          ),
        );
      } else {
        // Token invalide - aller vers l'inscription
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NewSignupScreen()),
        );
      }
    } else {
      // Pas connecté - aller vers l'inscription
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NewSignupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB84D), Color(0xFFFF6B1A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  "TRAVELO",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF6B1A),
                    letterSpacing: 3,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Your Journey Begins Here",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
