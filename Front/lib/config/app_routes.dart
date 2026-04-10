import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/organizer/waiting_approval_screen.dart';
import '../screens/organizer/organizer_main_screen.dart';
import '../screens/shared/not_found_screen.dart';
import '../screens/shared/public_organizer_profile_screen.dart';
import '../screens/shared/public_tourist_profile_screen.dart';
import '../screens/tourist/tourist_main_screen.dart';
import '../screens/welcome_screen.dart';
import '../splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String waitingApproval = '/waiting_approval';
  static const String home = '/home';
  static const String touristMain = '/tourist/main';
  static const String organizerMain = '/organizer/main';
  static const String profilePrefix = '/profile/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case home:
        // Use splash as a router-like entry point.
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case signup:
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );
      case waitingApproval:
        return MaterialPageRoute(
          builder: (_) => const WaitingApprovalScreen(),
          settings: settings,
        );
      case touristMain:
        return MaterialPageRoute(
          builder: (_) => const TouristMainScreen(),
          settings: settings,
        );
      case organizerMain:
        return MaterialPageRoute(
          builder: (_) => const OrganizerMainScreen(),
          settings: settings,
        );
      default:
        final name = settings.name ?? '';
        if (name.startsWith(profilePrefix)) {
          final uri = Uri.tryParse(name);
          final id = name.substring(profilePrefix.length).split('?').first;
          final type = uri?.queryParameters['type'] ?? 'tourist';
          if (id.isNotEmpty) {
            if (type == 'organizer') {
              return MaterialPageRoute(
                builder: (_) =>
                    PublicOrganizerProfileScreen(organizerId: id),
                settings: settings,
              );
            }
            return MaterialPageRoute(
              builder: (_) => PublicUserProfileScreen(userId: id),
              settings: settings,
            );
          }
        }
        return MaterialPageRoute(
          builder: (_) => NotFoundScreen(routeName: settings.name),
          settings: settings,
        );
    }
  }
}
