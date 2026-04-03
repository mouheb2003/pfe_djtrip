import 'package:flutter/material.dart';
import 'dart:async';
import 'config/app_routes.dart';
import 'services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Start the animation
    _controller.forward();

    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Check if user is already logged in
  Future<void> _checkLoginStatus() async {
    // Wait 4 seconds to see the splash with animation
    await Future.delayed(Duration(seconds: 4));

    final isLoggedIn = await AuthService.isLoggedIn();

    if (isLoggedIn) {
      // User logged in - retrieve info and go to Main
      final user = await AuthService.getUser();
      if (user != null) {
        final String? userType = user['userType'];
        // Navigate to appropriate screen based on user type
        if (userType == 'Organisator' || userType == 'Organizer') {
          Navigator.pushReplacementNamed(context, AppRoutes.organizerMain);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.touristMain);
        }
      } else {
        // Invalid session - go to login
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } else {
      // Not logged in - go to login
      Navigator.pushReplacementNamed(context, AppRoutes.login);
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // DJTrip logo with animation
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logos/logo2.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 24),
                  // Text with animation
                  Text(
                    "Discover Djerba with us",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 32),
                  // Loading indicator
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
