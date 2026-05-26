import 'package:flutter/material.dart';
import 'dart:async';
import 'config/app_routes.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/onboarding/user_type_selection_screen.dart';
import 'screens/onboarding/dynamic_onboarding_screen.dart';
import 'services/onboarding_service.dart';
import 'screens/organizer/waiting_approval_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<int> _characterCountAnimation;
  final String _logoText = 'DJTrip';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    // Fade and Scale for the entire Logo Container
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    // Typing effect for the letters
    _characterCountAnimation = IntTween(begin: 0, end: _logoText.length)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.6, curve: Curves.linear),
          ),
        );

    // Subtitle fade in
    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for animation to finish + small pause
    await Future.delayed(const Duration(milliseconds: 4500));
    if (!mounted) return;

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      await AuthService.ensureAccountGuardSocket();
      // User logged in - retrieve info and go to Main
      final user = await AuthService.getUser();
      if (user != null) {
        final String userType = user['userType'] as String? ?? 'Touriste';
        final bool emailVerified = user['emailVerified'] ?? true;
        final bool isOnboarded = user['is_onboarded'] ?? false;

        // 🚀 NEW: Handle email verification flow
        if (!emailVerified) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: user['email'] ?? '',
                userType: userType,
              ),
            ),
            (route) => false,
          );
          return;
        }

        // 🚀 NEW: Handle onboarding flow
        if (!isOnboarded) {
          final actualUserType = user['userType'] as String?;
          if (actualUserType != null && actualUserType.trim().isNotEmpty) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicOnboardingScreen(),
              ),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const UserTypeSelectionScreen(),
              ),
              (route) => false,
            );
          }
          return;
        }

        // ✅ Organizer gating: if onboarding is complete but approval pending, always show waiting screen
        if (userType == 'Organisator' || userType == 'Organizer') {
          try {
            final status = await OnboardingService.getOnboardingStatus();
            final isApproved = status['is_approved'] ?? true;
            if (status['success'] == true && isApproved == false) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const WaitingApprovalScreen(),
                ),
                (route) => false,
              );
              return;
            }
          } catch (_) {
            // If status check fails, be safe: keep organizer blocked.
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
              (route) => false,
            );
            return;
          }
        }

        final route = (userType == 'Organisator' || userType == 'Organizer')
            ? AppRoutes.organizerMain
            : AppRoutes.touristMain;
        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.welcome,
          (route) => false,
        );
      }
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.welcome,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered Animated Logo
            FadeTransition(
              opacity: _logoFadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary, // Blue square
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _characterCountAnimation,
                  builder: (context, child) {
                    final textToShow = _logoText.substring(
                      0,
                      _characterCountAnimation.value,
                    );
                    return Text(
                      textToShow,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Fading Subtitle
            FadeTransition(
              opacity: _subtitleFadeAnimation,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Discover Djerba with us\nYour guide to unforgettable journeys!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B2458),
                    letterSpacing: 0.4,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
