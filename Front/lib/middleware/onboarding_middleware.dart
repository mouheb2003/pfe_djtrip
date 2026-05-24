import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';

class OnboardingMiddleware {
  // Check if user needs onboarding
  static Future<bool> needsOnboarding() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return false; // Not logged in, let auth middleware handle it
      }

      final needsOnboarding = await OnboardingService.needsOnboarding();
      return needsOnboarding;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return true; // Default to requiring onboarding on error
    }
  }

  // Check if user is approved (for organizers)
  static Future<bool> isApproved() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return false; // Not logged in, let auth middleware handle it
      }

      final isApproved = await OnboardingService.isApproved();
      return isApproved;
    } catch (e) {
      print('Error checking approval status: $e');
      return false; // Default to not approved on error
    }
  }

  // Get user onboarding status
  static Future<Map<String, dynamic>?> getOnboardingStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        return null; // Not logged in
      }

      final status = await OnboardingService.getOnboardingStatus();
      return status;
    } catch (e) {
      print('Error getting onboarding status: $e');
      return null;
    }
  }

  // Navigate to appropriate screen based on status
  static Future<void> navigateToAppropriateScreen(BuildContext context) async {
    try {
      final status = await OnboardingService.getOnboardingStatus();
      
      if (status == null) {
        // User not logged in, navigate to login
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final isOnboarded = status['is_onboarded'] ?? false;
      final isApproved = status['is_approved'] ?? true;
      final userType = status['userType'] ?? 'tourist';

      if (!isOnboarded) {
        // User needs onboarding
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else if ((userType.toLowerCase() == 'organisator' || userType.toLowerCase() == 'organizer') && !isApproved) {
        // Organizer needs approval
        Navigator.pushReplacementNamed(context, '/waiting_approval');
      } else {
        // User can access app
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error navigating to appropriate screen: $e');
      // Default to onboarding on error
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  // Check if user can access specific features
  static Future<bool> canAccessFeature(String feature) async {
    try {
      final status = await OnboardingService.getOnboardingStatus();
      
      if (status == null) {
        return false; // Not logged in
      }

      final isOnboarded = status['is_onboarded'] ?? false;
      final isApproved = status['is_approved'] ?? true;
      final userType = status['userType'] ?? 'tourist';

      switch (feature) {
        case 'create_activities':
          return isOnboarded && isApproved && (userType.toLowerCase() == 'organisator' || userType.toLowerCase() == 'organizer');
        case 'manage_bookings':
          return isOnboarded && isApproved && (userType.toLowerCase() == 'organisator' || userType.toLowerCase() == 'organizer');
        case 'view_analytics':
          return isOnboarded && isApproved && (userType.toLowerCase() == 'organisator' || userType.toLowerCase() == 'organizer');
        case 'book_activities':
          return isOnboarded && userType.toLowerCase() == 'touriste';
        case 'write_reviews':
          return isOnboarded && userType.toLowerCase() == 'touriste';
        case 'view_notifications':
          return isOnboarded;
        case 'edit_profile':
          return isOnboarded;
        default:
          return isOnboarded;
      }
    } catch (e) {
      print('Error checking feature access: $e');
      return false;
    }
  }

  // Get user type with fallback
  static Future<String> getUserType() async {
    try {
      final user = await AuthService.getUser();
      return user?['userType'] ?? 'tourist';
    } catch (e) {
      print('Error getting user type: $e');
      return 'tourist';
    }
  }

  // Check if user is tourist
  static Future<bool> isTourist() async {
    final userType = await getUserType();
    return userType == 'Touriste';
  }

  // Check if user is organizer
  static Future<bool> isOrganizer() async {
    final userType = await getUserType();
    return userType.toLowerCase() == 'organisator' || userType.toLowerCase() == 'organizer';
  }

  // Check if user is admin
  static Future<bool> isAdmin() async {
    final userType = await getUserType();
    return userType == 'Admin';
  }

  // Show appropriate error message
  static void showFeatureRestrictedMessage(BuildContext context, String feature) {
    String message;
    String action;

    switch (feature) {
      case 'create_activities':
        message = 'You need to complete onboarding and get approval to create activities.';
        action = 'Complete Onboarding';
        break;
      case 'manage_bookings':
        message = 'You need to complete onboarding and get approval to manage bookings.';
        action = 'Complete Onboarding';
        break;
      case 'book_activities':
        message = 'You need to complete onboarding to book activities.';
        action = 'Complete Onboarding';
        break;
      default:
        message = 'You need to complete onboarding to access this feature.';
        action = 'Complete Onboarding';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Restricted'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/onboarding');
              },
              child: Text(action),
            ),
          ],
        );
      },
    );
  }

  // Show approval waiting message for organizers
  static void showApprovalWaitingMessage(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account Under Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your organizer account is currently under review by our team.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'This process typically takes 1-3 business days. You will receive an email once a decision has been made.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'While you wait, you can still explore our platform as a tourist.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Switch to Tourist'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Wait'),
            ),
          ],
        );
      },
    );
  }
}
