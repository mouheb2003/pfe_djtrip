import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../config/oauth_config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  /// GoogleSignIn with serverClientId for proper idToken generation
  /// serverClientId is the Google Web Client ID from Google Cloud Console
  /// This is REQUIRED to get ID tokens for backend authentication
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: OAuthConfig.googleServerClientId.isNotEmpty
        ? OAuthConfig.googleServerClientId
        : null,
    scopes: ['email', 'profile'],
  );

  static const _keyAccess = 'djtrip_access_token';
  static const _keyRefresh = 'djtrip_refresh_token';
  static const _keyUser = 'djtrip_user_data';

  // ── In-memory cache ──────────────────────────────────────────
  static Map<String, dynamic>? _cachedUser;

  // ── Token accessors ──────────────────────────────────────────
  static Future<String?> getAccessToken() => _storage.read(key: _keyAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  static Future<void> _saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await Future.wait([
      _storage.write(key: _keyAccess, value: accessToken),
      _storage.write(key: _keyRefresh, value: refreshToken),
    ]);
  }

  // ── User cache ───────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    _cachedUser = user;
    await _storage.write(key: _keyUser, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final raw = await _storage.read(key: _keyUser);
    if (raw != null) _cachedUser = jsonDecode(raw);
    return _cachedUser;
  }

  static Map<String, dynamic>? get currentUser => _cachedUser;

  // ── Convenience ──────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getUserType() async {
    final user = await getUser();
    return user?['userType'] as String?;
  }

  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?['_id'] as String?;
  }

  // ── Auth API ─────────────────────────────────────────────────

  /// Returns `{success: true, user: {...}}` or `{success: false, message: '…'}`
  static Future<Map<String, dynamic>> signIn(
    String email,
    String password,
  ) async {
    try {
      final res = await ApiClient.post('/users/signin', {
        'email': email,
        'mot_de_passe': password,
      }, auth: false);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      if (res.statusCode == 200) {
        final accessToken = body['accessToken'] as String?;
        final refreshToken = body['refreshToken'] as String?;

        if (accessToken == null || refreshToken == null) {
          return {
            'success': false,
            'message': 'Invalid server response (missing tokens).',
          };
        }

        await _saveTokens(accessToken, refreshToken);

        Map<String, dynamic>? user;
        if (body['user'] is Map<String, dynamic>) {
          user = body['user'] as Map<String, dynamic>;
        } else {
          final meRes = await ApiClient.get('/users/me');
          if (meRes.statusCode == 200) {
            final meBody = jsonDecode(meRes.body) as Map<String, dynamic>;
            if (meBody['user'] is Map<String, dynamic>) {
              user = meBody['user'] as Map<String, dynamic>;
            }
          }
        }

        if (user == null) {
          return {
            'success': false,
            'message':
                'Sign-in successful, but unable to retrieve user profile.',
          };
        }

        await saveUser(user);
        return {'success': true, 'user': user};
      }

      if (res.statusCode == 423) {
        return {
          'success': false,
          'locked': true,
          'message': body['message'] ?? 'Account temporarily locked.',
          'remainingSeconds': body['remainingSeconds'] ?? 60,
        };
      }

      return {'success': false, 'message': body['message'] ?? 'Sign-in error'};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Cannot connect to the server. Please check your network connection.',
      };
    }
  }

  /// Returns `{success: true, user: {...}}` or `{success: false, message: '…'}`
  static Future<Map<String, dynamic>> signUp({
    required String fullname,
    required String email,
    required String password,
    required String userType, // 'Touriste' | 'Organisator'
  }) async {
    try {
      final res = await ApiClient.post('/users/signup', {
        'fullname': fullname,
        'email': email,
        'mot_de_passe': password,
        'userType': userType,
      }, auth: false);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      if (res.statusCode == 201) {
        final accessToken = body['accessToken'] as String?;
        final refreshToken = body['refreshToken'] as String?;
        final user = body['user'] as Map<String, dynamic>?;

        if (accessToken == null || refreshToken == null || user == null) {
          return {
            'success': false,
            'message': 'Invalid server response during sign-up.',
          };
        }

        await _saveTokens(accessToken, refreshToken);
        await saveUser(user);
        return {'success': true, 'user': user};
      }

      return {'success': false, 'message': body['message'] ?? 'Sign-up error'};
    } catch (_) {
      return {
        'success': false,
        'message':
            'Cannot connect to the server. Please check your network connection.',
      };
    }
  }

  /// Sends `/forgot-password` with the user's email.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await ApiClient.post('/users/forgot-password', {
      'email': email,
    }, auth: false);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'success': res.statusCode == 200, 'message': body['message'] ?? ''};
  }

  /// Tries to refresh the access token. Returns true on success.
  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;
      final res = await ApiClient.post('/users/refresh-token', {
        'refreshToken': refreshToken,
      }, auth: false);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        await _storage.write(key: _keyAccess, value: body['accessToken']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify email with 6-digit code (requires valid access token).
  static Future<Map<String, dynamic>> verifyEmail(String code) async {
    final res = await ApiClient.post('/auth/verify-email', {'code': code});
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'success': res.statusCode == 200, 'message': body['message'] ?? ''};
  }

  /// Resend the email verification code to [email].
  static Future<Map<String, dynamic>> resendVerification(String email) async {
    final res = await ApiClient.post('/auth/resend-verification', {
      'email': email,
    }, auth: false);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'success': res.statusCode == 200, 'message': body['message'] ?? ''};
  }

  /// Resets password via forgot-password code (no auth required).
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await ApiClient.post('/users/reset-password', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    }, auth: false);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'success': res.statusCode == 200, 'message': body['message'] ?? ''};
  }

  /// Changes the current user's password.
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await ApiClient.put('/users/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'success': res.statusCode == 200, 'message': body['message'] ?? ''};
  }

  /// Logs out the user: calls the API, clears local storage.
  static Future<void> logout() async {
    try {
      await ApiClient.post('/users/logout', {});
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    _cachedUser = null;
    await _storage.deleteAll();
  }

  /// Sign in with Google, then authenticate against backend.
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return {'success': false, 'message': 'Google sign-in was cancelled.'};
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'Google did not return an ID token.',
        };
      }

      final res = await ApiClient.post('/users/auth/google', {
        'idToken': idToken,
      }, auth: false);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      if (res.statusCode != 200) {
        return {
          'success': false,
          'message': body['message'] ?? 'Google authentication failed',
        };
      }

      final accessToken = body['accessToken'] as String?;
      final refreshToken = body['refreshToken'] as String?;
      final user = body['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || user == null) {
        return {
          'success': false,
          'message': 'Invalid server response during Google authentication.',
        };
      }

      await _saveTokens(accessToken, refreshToken);
      await saveUser(user);
      return {'success': true, 'user': user};
    } on PlatformException catch (e) {
      final details = (e.message ?? e.details?.toString() ?? '').toLowerCase();
      final code = e.code.toLowerCase();

      // Most common Android OAuth misconfiguration signal.
      if (details.contains('10') ||
          details.contains('developer_error') ||
          code.contains('sign_in_failed') ||
          code.contains('api_exception')) {
        return {
          'success': false,
          'message':
              'Google login misconfigured (OAuth). Verify package name + SHA-1 in Google Cloud and google-services.json.',
        };
      }

      if (code.contains('network_error') || details.contains('network')) {
        return {
          'success': false,
          'message':
              'Network error during Google sign-in. Check internet and try again.',
        };
      }

      return {
        'success': false,
        'message': 'Google sign-in error: ${e.message ?? e.code}',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Google authentication failed. Please try again.',
      };
    }
  }

  /// Sign in with Facebook, then authenticate against backend.
  static Future<Map<String, dynamic>> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.cancelled) {
        return {'success': false, 'message': 'Facebook sign-in was cancelled.'};
      }

      if (result.status != LoginStatus.success || result.accessToken == null) {
        return {
          'success': false,
          'message': result.message ?? 'Facebook sign-in failed.',
        };
      }

      final res = await ApiClient.post('/users/auth/facebook', {
        'accessToken': result.accessToken!.tokenString,
      }, auth: false);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      if (res.statusCode != 200) {
        return {
          'success': false,
          'message': body['message'] ?? 'Facebook authentication failed',
        };
      }

      final accessToken = body['accessToken'] as String?;
      final refreshToken = body['refreshToken'] as String?;
      final user = body['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || user == null) {
        return {
          'success': false,
          'message': 'Invalid server response during Facebook authentication.',
        };
      }

      await _saveTokens(accessToken, refreshToken);
      await saveUser(user);
      return {'success': true, 'user': user};
    } catch (_) {
      return {
        'success': false,
        'message': 'Facebook authentication failed. Please try again.',
      };
    }
  }
}
