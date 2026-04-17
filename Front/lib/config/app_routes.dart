import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/onboarding/user_type_selection_screen.dart';
import '../screens/organizer/waiting_approval_screen.dart';
import '../screens/organizer/organizer_main_screen.dart';
import '../screens/shared/not_found_screen.dart';
import '../screens/shared/public_organizer_profile_screen.dart';
import '../screens/shared/public_profile_screen.dart';
import '../screens/shared/public_tourist_profile_screen.dart';
import '../screens/tourist/tourist_main_screen.dart';
import '../screens/welcome_screen.dart';
import '../splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String userTypeSelection = '/user_type_selection';
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
      case userTypeSelection:
        return MaterialPageRoute(
          builder: (_) => const UserTypeSelectionScreen(),
          settings: settings,
        );
      case waitingApproval:
        return MaterialPageRoute(
          builder: (_) => const WaitingApprovalScreen(),
          settings: settings,
        );
      case touristMain:
        final initialIndex = settings.arguments is Map
            ? (settings.arguments as Map)['initialIndex'] as int? ?? 0
            : 0;
        return MaterialPageRoute(
          builder: (_) => TouristMainScreen(initialIndex: initialIndex),
          settings: settings,
        );
      case organizerMain:
        final initialIndex = settings.arguments is Map
            ? (settings.arguments as Map)['initialIndex'] as int? ?? 0
            : 0;
        return MaterialPageRoute(
          builder: (_) => OrganizerMainScreen(initialIndex: initialIndex),
          settings: settings,
        );
      default:
        final name = settings.name ?? '';
        if (name.startsWith(profilePrefix)) {
          final id = name.substring(profilePrefix.length).split('?').first;
          if (id.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => PublicProfileScreen(userId: id),
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
