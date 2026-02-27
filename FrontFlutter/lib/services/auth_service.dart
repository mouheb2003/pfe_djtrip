import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import 'storage_service.dart';

class AuthService {
  // Inscription (Sign Up)
  static Future<Map<String, dynamic>> signUp({
    required String fullname,
    required String email,
    required String password,
    required String userType, // "Touriste" ou "Organisator"
    String? nomEntreprise, // Requis si userType == "Organisator"
  }) async {
    try {
      // Préparer le body
      final body = {
        'fullname': fullname,
        'email': email,
        'mot_de_passe': password,
        'userType': userType,
      };

      // Si c'est un organisateur, ajouter le nom de l'entreprise
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

        // Sauvegarder les informations utilisateur
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
          'message': data['message'] ?? 'Erreur lors de l\'inscription',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Connexion (Sign In)
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
          'message': data['message'] ?? 'Erreur lors de la connexion',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Récupérer les informations de l'utilisateur connecté
  static Future<Map<String, dynamic>> getMyInfo() async {
    try {
      final accessToken = await StorageService.getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'Non connecté'};
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
          'message':
              data['message'] ??
              'Erreur lors de la récupération des informations',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: ${e.toString()}',
      };
    }
  }

  // Rafraîchir le token
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

  // Déconnexion
  static Future<void> logout() async {
    await StorageService.clearAll();
  }
}
