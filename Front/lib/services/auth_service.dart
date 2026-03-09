import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'storage_service.dart';

class AuthService {
  // Sign Up
  static Future<Map<String, dynamic>> signUp({
    required String fullname,
    required String email,
    required String password,
    required String userType, // "Touriste" or "Organisator"
  }) async {
    try {
      // Prepare the body
      final body = {
        'fullname': fullname,
        'email': email,
        'mot_de_passe': password,
        'userType': userType,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.signUp),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Succès - Sauvegarder les tokens
        await StorageService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        // Save user information
        final user = User.fromJson(data['user']);
        await StorageService.saveUserInfo(
          userId: user.id,
          email: user.email,
          userType: user.userType,
        );

        return {'success': true, 'message': data['message'], 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error during registration',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Sign In
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.signIn),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'mot_de_passe': password}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Succès - Sauvegarder les tokens
        await StorageService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error during login',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Get logged-in user information
  static Future<Map<String, dynamic>> getMyInfo() async {
    try {
      final accessToken = await StorageService.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http
          .get(
            Uri.parse(ApiConfig.myInfo),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error retrieving information',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Refresh token
  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();

      if (refreshToken == null) {
        return false;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.refreshToken),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await StorageService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: refreshToken,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final accessToken = await StorageService.getAccessToken();

      // Call backend to set status to inactive
      if (accessToken != null) {
        await http
            .post(
              Uri.parse(ApiConfig.logout),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
            )
            .timeout(ApiConfig.connectionTimeout);
      }
    } catch (e) {
      // Even if the call fails, continue with local logout
      print('Error during backend logout: $e');
    } finally {
      // Always clear local storage
      await StorageService.clearAll();
    }
  }

  // Google Sign In
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static Future<Map<String, dynamic>> signInWithGoogle({
    required String userType, // "Touriste" or "Organisator"
  }) async {
    try {
      // Disconnect any previous session
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return {'success': false, 'message': 'Google sign-in cancelled'};
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Prepare the body for backend
      final body = {
        'fullname': googleUser.displayName ?? googleUser.email.split('@')[0],
        'email': googleUser.email,
        'googleId': googleUser.id,
        'googleToken': googleAuth.idToken,
        'userType': userType,
        'authProvider': 'google',
      };

      // Send to backend
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/google-signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - Save tokens
        await StorageService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        // Save user information
        final user = User.fromJson(data['user']);
        await StorageService.saveUserInfo(
          userId: user.id,
          email: user.email,
          userType: user.userType,
        );

        return {'success': true, 'message': data['message'], 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error with Google sign-in',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error with Google sign-in: ${e.toString()}',
      };
    }
  }

  // Facebook Sign In
  static Future<Map<String, dynamic>> signInWithFacebook({
    required String userType, // "Touriste" or "Organisator"
  }) async {
    try {
      // Trigger the authentication flow
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        return {
          'success': false,
          'message': 'Facebook sign-in cancelled or failed',
        };
      }

      // Get user data
      final userData = await FacebookAuth.instance.getUserData();
      final accessToken = result.accessToken!.tokenString;

      // Prepare the body for backend
      final body = {
        'fullname':
            userData['name'] ?? userData['email']?.split('@')[0] ?? 'User',
        'email': userData['email'] ?? '',
        'facebookId': userData['id'],
        'facebookToken': accessToken,
        'userType': userType,
        'authProvider': 'facebook',
      };

      // Send to backend
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/facebook-signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - Save tokens
        await StorageService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );

        // Save user information
        final user = User.fromJson(data['user']);
        await StorageService.saveUserInfo(
          userId: user.id,
          email: user.email,
          userType: user.userType,
        );

        return {'success': true, 'message': data['message'], 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error with Facebook sign-in',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error with Facebook sign-in: ${e.toString()}',
      };
    }
  }

  // Verify Email with Code
  static Future<Map<String, dynamic>> verifyEmail({
    required String code,
  }) async {
    try {
      final accessToken = await StorageService.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/verify-email'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'code': code}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Resend Verification Code
  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/resend-verification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error sending code',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // ============= FORGOT PASSWORD & RESET =============

  /// Send password reset code to email
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.forgotPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send reset code',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Reset password with verification code
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.resetPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'code': code,
              'newPassword': newPassword,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
