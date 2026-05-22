import 'dart:convert';
import 'api_client.dart';
import 'navigation_service.dart';

class OnboardingService {
  static const String _baseUrl = '/onboarding';

  // Get onboarding status
  static Future<Map<String, dynamic>> getOnboardingStatus() async {
    try {
      final response = await ApiClient.get('$_baseUrl/status');
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          ...body,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get onboarding status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Update onboarding step
  static Future<Map<String, dynamic>> updateOnboardingStep(
    Map<String, dynamic> stepData
  ) async {
    try {
      final response = await ApiClient.post(
        '$_baseUrl/step',
        stepData,
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          ...body,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update onboarding step',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Complete onboarding
  static Future<Map<String, dynamic>> completeOnboarding() async {
    try {
      final response = await ApiClient.post('$_baseUrl/complete', {});
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          ...body,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to complete onboarding',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Update user type (for Google signup users)
  static Future<Map<String, dynamic>> updateUserType(String userType) async {
    try {
      final response = await ApiClient.put('$_baseUrl/user-type', {
        'userType': userType,
      });
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          'user': body['user'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update user type',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Check if user needs onboarding
  static Future<bool> needsOnboarding() async {
    try {
      final response = await ApiClient.get('$_baseUrl/status');
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return !(body['is_onboarded'] ?? false);
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  // Check if user is approved (for organizers)
  static Future<bool> isApproved() async {
    try {
      final response = await ApiClient.get('$_baseUrl/status');
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['is_approved'] ?? true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get next onboarding step
  static Future<Map<String, dynamic>?> getNextStep() async {
    try {
      final response = await ApiClient.get('$_baseUrl/status');
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['next_step'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Navigate to appropriate screen based on onboarding status
  static Future<void> navigateToAppropriateScreen() async {
    try {
      final status = await getOnboardingStatus();
      
      final isOnboarded = status['is_onboarded'] ?? false;
      final isApproved = status['is_approved'] ?? true;
      final userType = status['userType'] ?? 'Touriste';

      if (!status['success']) {
        // Error getting status, go to onboarding
        NavigationService.navigateToOnboarding(userType: userType);
        return;
      }

      if (!isOnboarded) {
        // User needs onboarding
        NavigationService.navigateToOnboarding(userType: userType);
      } else if (userType == 'Organisator' && !isApproved) {
        // Organizer needs approval
        NavigationService.navigateToWaitingApproval();
      } else {
        // User can access app
        NavigationService.navigateToHome(userType: userType);
      }
    } catch (e) {
      // Error, default to onboarding
      NavigationService.navigateToOnboarding();
    }
  }

  // Get onboarding steps for user type
  static List<Map<String, dynamic>> getOnboardingSteps(String userType) {
    if (userType == 'Organisator') {
      return _organizerSteps;
    } else {
      return _touristSteps;
    }
  }

  // Tourist onboarding steps
  static const List<Map<String, dynamic>> _touristSteps = [
    {
      'id': 'profile_picture',
      'title': 'Profile Picture',
      'description': 'Add a profile picture to personalize your account',
      'required': false,
      'fields': ['avatar'],
    },
    {
      'id': 'cover_photo',
      'title': 'Cover Photo',
      'description': 'Add a cover photo to make your profile stand out',
      'required': false,
      'fields': ['cover_photo'],
    },
    {
      'id': 'country',
      'title': 'Country',
      'description': 'Tell us where you\'re from',
      'required': true,
      'fields': ['pays_origine'],
    },
    {
      'id': 'language',
      'title': 'Preferred Language',
      'description': 'Choose your preferred language',
      'required': true,
      'fields': ['langue_preferee'],
    },
    {
      'id': 'interests',
      'title': 'Your Interests',
      'description': 'Pick a few interests to personalize your recommendations',
      'required': true,
      'fields': ['centres_interet'],
    },
    {
      'id': 'tourist_bio',
      'title': 'Your Bio',
      'description': 'Tell us about yourself and what you love about traveling',
      'required': true,
      'fields': ['bio'],
    },
    {
      'id': 'phone',
      'title': 'Phone Number',
      'description': 'Add your phone number for better communication',
      'required': false,
      'fields': ['num_tel', 'pays_telephone'],
    },
  ];

  // Organizer onboarding steps
  static const List<Map<String, dynamic>> _organizerSteps = [
    {
      'id': 'profile_picture',
      'title': 'Profile Picture',
      'description': 'Add a profile picture to personalize your account',
      'required': true,
      'fields': ['avatar'],
    },
    {
      'id': 'cover_photo',
      'title': 'Cover Photo',
      'description': 'Add a cover photo to make your profile stand out',
      'required': false,
      'fields': ['cover_photo'],
    },
    {
      'id': 'country',
      'title': 'Country',
      'description': 'Tell us where you\'re from',
      'required': true,
      'fields': ['pays_origine'],
    },
    {
      'id': 'language',
      'title': 'Preferred Language',
      'description': 'Choose your preferred language',
      'required': true,
      'fields': ['langue_preferee'],
    },
    {
      'id': 'specialized_activities',
      'title': 'Specialized Activities',
      'description': 'What types of activities do you specialize in?',
      'required': true,
      'fields': ['specialites_activites'],
    },
    {
      'id': 'spoken_languages',
      'title': 'Languages You Speak',
      'description': 'What languages do you offer tours in?',
      'required': true,
      'fields': ['langues_proposees'],
    },
    {
      'id': 'organizer_bio',
      'title': 'Your Bio',
      'description': 'Tell us about yourself and your experience',
      'required': true,
      'fields': ['bio'],
    },
    {
      'id': 'reason_to_join',
      'title': 'Why Join DJTrip?',
      'description': 'Tell us why you want to become an organizer on DJTrip',
      'required': true,
      'fields': ['reasonToJoin'],
    },
    {
      'id': 'phone',
      'title': 'Phone Number',
      'description': 'Add your phone number for better communication',
      'required': false,
      'fields': ['num_tel', 'pays_telephone'],
    },
  ];
}
