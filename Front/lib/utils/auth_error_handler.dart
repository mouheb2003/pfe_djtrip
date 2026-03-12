import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../screens/auth/new_login_screen.dart';

/// Helper pour gérer les erreurs d'authentification dans l'UI
class AuthErrorHandler {
  /// Vérifie si une réponse nécessite une reconnexion
  static bool requiresLogin(Map<String, dynamic> response) {
    return response['requiresLogin'] == true;
  }

  /// Affiche un message et redirige vers la page de connexion si nécessaire
  static void handleAuthError(
    BuildContext context,
    Map<String, dynamic> response, {
    VoidCallback? onSessionExpired,
  }) {
    if (requiresLogin(response)) {
      // Session expirée, rediriger vers login
      _showSessionExpiredDialog(context, onSessionExpired);
    } else if (!response['success']) {
      // Autre erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'An error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Affiche un dialogue pour informer que la session a expiré
  static void _showSessionExpiredDialog(
    BuildContext context,
    VoidCallback? onSessionExpired,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Session Expired'),
          ],
        ),
        content: Text(
          'Your session has expired. Please log in again to continue.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialogue
              _navigateToLogin(context);
              onSessionExpired?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B1A),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Log In Again',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigue vers l'écran de connexion
  static void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => NewLoginScreen()),
      (route) => false, // Supprimer toutes les routes précédentes
    );
  }

  /// Vérifie si l'utilisateur est connecté avant d'exécuter une action
  static Future<T?> withAuth<T>(
    BuildContext context,
    Future<T> Function() action, {
    VoidCallback? onSessionExpired,
  }) async {
    final isLoggedIn = await StorageService.isLoggedIn();

    if (!isLoggedIn) {
      _showSessionExpiredDialog(context, onSessionExpired);
      return null;
    }

    try {
      return await action();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
}

/// Widget qui wrap une action nécessitant l'authentification
class AuthRequiredWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSessionExpired;

  const AuthRequiredWidget({
    super.key,
    required this.child,
    this.onSessionExpired,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: StorageService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data != true) {
          // Pas connecté, rediriger
          Future.microtask(() {
            AuthErrorHandler._navigateToLogin(context);
            onSessionExpired?.call();
          });
          return Center(child: CircularProgressIndicator());
        }

        return child;
      },
    );
  }
}

/// Exemple d'utilisation dans un écran
/*
class MyProfileScreen extends StatefulWidget {
  @override
  _MyProfileScreenState createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  Future<void> _updateProfile() async {
    // Utiliser HttpClient qui gère automatiquement le refresh
    final result = await UserService.updateProfile({
      'fullname': 'New Name',
    });

    // Gérer l'erreur si la session a expiré
    if (mounted) {
      AuthErrorHandler.handleAuthError(context, result);
      
      if (result['success']) {
        // Succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil mis à jour')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthRequiredWidget(
      onSessionExpired: () {
        print('Session expirée, utilisateur redirigé');
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Mon Profil')),
        body: Center(
          child: ElevatedButton(
            onPressed: _updateProfile,
            child: Text('Mettre à jour le profil'),
          ),
        ),
      ),
    );
  }
}
*/
