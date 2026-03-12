import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'auth_service.dart';

/// HTTP Client avec gestion automatique du refresh token
/// Détecte les erreurs 401 et refresh automatiquement le token sans déconnecter l'utilisateur
class HttpClient {
  static bool _isRefreshing = false;
  static List<Function> _pendingRequests = [];

  /// GET request avec auto-refresh
  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _makeRequest(
      () => http.get(Uri.parse(url), headers: headers),
      timeout: timeout,
    );
  }

  /// POST request avec auto-refresh
  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeRequest(
      () => http.post(Uri.parse(url), headers: headers, body: body),
      timeout: timeout,
    );
  }

  /// PUT request avec auto-refresh
  static Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeRequest(
      () => http.put(Uri.parse(url), headers: headers, body: body),
      timeout: timeout,
    );
  }

  /// DELETE request avec auto-refresh
  static Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _makeRequest(
      () => http.delete(Uri.parse(url), headers: headers),
      timeout: timeout,
    );
  }

  /// Logique commune pour toutes les requêtes
  static Future<http.Response> _makeRequest(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    try {
      // Exécuter la requête avec timeout
      final response = await (timeout != null
          ? request().timeout(timeout)
          : request());

      // Si le token a expiré (401), essayer de le rafraîchir
      if (response.statusCode == 401) {
        final body = jsonDecode(response.body);

        // Vérifier si c'est bien une erreur de token expiré
        if (body['message']?.toString().toLowerCase().contains('token') ??
            false) {
          // Si un refresh est déjà en cours, attendre
          if (_isRefreshing) {
            await _waitForRefresh();
            // Réessayer la requête avec le nouveau token
            return _makeRequest(request, timeout: timeout);
          }

          // Essayer de rafraîchir le token
          _isRefreshing = true;
          final refreshSuccess = await AuthService.refreshAccessToken();
          _isRefreshing = false;

          // Notifier toutes les requêtes en attente
          _notifyPendingRequests();

          if (refreshSuccess) {
            // Token rafraîchi avec succès, réessayer la requête originale
            return _makeRequest(request, timeout: timeout);
          } else {
            // Impossible de rafraîchir, l'utilisateur doit se reconnecter
            // Nettoyer le storage
            await StorageService.clearAll();
            throw TokenExpiredException(
              'Session expired. Please log in again.',
            );
          }
        }
      }

      return response;
    } catch (e) {
      if (e is TokenExpiredException) {
        rethrow;
      }
      rethrow;
    }
  }

  /// Attendre que le refresh en cours se termine
  static Future<void> _waitForRefresh() async {
    if (!_isRefreshing) return;

    final completer = Future.delayed(Duration(milliseconds: 100));
    _pendingRequests.add(() => completer);
    await completer;

    if (_isRefreshing) {
      // Si le refresh n'est pas encore terminé, attendre à nouveau
      await _waitForRefresh();
    }
  }

  /// Notifier toutes les requêtes en attente
  static void _notifyPendingRequests() {
    for (var callback in _pendingRequests) {
      callback();
    }
    _pendingRequests.clear();
  }

  /// Créer des headers avec le token d'authentification
  static Future<Map<String, String>> getAuthHeaders() async {
    final accessToken = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }
}

/// Exception personnalisée pour les tokens expirés
class TokenExpiredException implements Exception {
  final String message;

  TokenExpiredException(this.message);

  @override
  String toString() => message;
}
