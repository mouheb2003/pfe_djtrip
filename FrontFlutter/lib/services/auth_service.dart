import 'dart:convert';
import 'package:http/http.dart' as http;
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
    String? nomEntreprise, // Required if userType == "Organisator"
  }) async {
    try {
      // Prepare the body
      final body = {
        'fullname': fullname,
        'email': email,
        'mot_de_passe': password,
        'userType': userType,
      };

      // If it's an organizer, add the company name
      if (userType == 'Organisator' && nomEntreprise != null) {
        body['nom_entreprise'] = nomEntreprise;
      }

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
}
