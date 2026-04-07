import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';
import 'api_service.dart';
import 'navigation_service.dart';
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
  static io.Socket? _guardSocket;
  static bool _handlingRestriction = false;

  // ── In-memory cache ──────────────────────────────────────────
  static Map<String, dynamic>? _cachedUser;

  // ✅ ADDED
  static Map<String, dynamic> _safeObject(String body) {
    return ApiService.safeDecodeObject(body);
  }

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

    _startAccountGuardSocket(accessToken);
  }

  static void _stopAccountGuardSocket() {
    _guardSocket?.off('connect');
    _guardSocket?.off('disconnect');
    _guardSocket?.off('connect_error');
    _guardSocket?.off('account_restricted');
    _guardSocket?.disconnect();
    _guardSocket?.dispose();
    _guardSocket = null;
  }

  static Future<void> _handleAccountRestriction(dynamic data) async {
    if (_handlingRestriction) return;
    _handlingRestriction = true;

    String message = 'Your account is restricted. Please sign in again.';
    final restriction = <String, dynamic>{};
    if (data is Map) {
      final type = data['type']?.toString().trim() ?? '';
      final fromMessage = data['message']?.toString().trim() ?? '';
      final fromReason = data['reason']?.toString().trim() ?? '';
      final suspendedUntil = data['suspendedUntil'];
      final remainingSeconds = data['remainingSeconds'];

      if (type.isNotEmpty) restriction['type'] = type;
      if (fromReason.isNotEmpty) restriction['reason'] = fromReason;
      if (suspendedUntil != null) {
        restriction['suspendedUntil'] = suspendedUntil.toString();
      }
      if (remainingSeconds != null) {
        restriction['remainingSeconds'] = remainingSeconds;
      }

      if (fromMessage.isNotEmpty) {
        message = fromMessage;
      } else if (fromReason.isNotEmpty) {
        message = fromReason;
      }

      if (message.isNotEmpty) restriction['message'] = message;
    }

    await clearLocalSession();
    await NavigationService.forceLogoutToLogin(
      message: message,
      restriction: restriction.isEmpty ? null : restriction,
    );

    _handlingRestriction = false;
  }

  static void _startAccountGuardSocket(String accessToken) {
    if (accessToken.isEmpty) return;

    _stopAccountGuardSocket();

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?\$'),
      '',
    );

    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .build(),
    );

    socket.on('connect', (_) {});
    socket.on('disconnect', (_) {});

    socket.on('account_restricted', (data) async {
      await _handleAccountRestriction(data);
    });

    socket.on('connect_error', (error) async {
      final msg = error?.toString() ?? '';
      final msgLower = msg.toLowerCase();

      final payload = <String, dynamic>{};
      if (error is Map) {
        final data = error['data'];
        if (data is Map) {
          payload.addAll(Map<String, dynamic>.from(data));
        }
        final mapMessage = error['message']?.toString().trim() ?? '';
        if (mapMessage.isNotEmpty) {
          payload['message'] = mapMessage;
        }
      } else {
        try {
          final data = (error as dynamic).data;
          if (data is Map) {
            payload.addAll(Map<String, dynamic>.from(data));
          }
        } catch (_) {}
      }

      if ((payload['message'] ?? '').toString().trim().isEmpty &&
          msg.trim().isNotEmpty) {
        payload['message'] = msg;
      }

      final probe = '${payload['message'] ?? ''} ${payload['type'] ?? ''}'
          .toString()
          .toLowerCase();
      final isRestriction =
          probe.contains('restricted') ||
          probe.contains('suspended') ||
          probe.contains('banned') ||
          msgLower.contains('account restricted');
      final isSessionExpired =
          probe.contains('session expired') ||
          msgLower.contains('session expired');

      if (isRestriction || isSessionExpired) {
        if (payload.isEmpty) {
          payload['message'] =
              'Your session was interrupted: account suspended or banned.';
        }
        await _handleAccountRestriction(payload);
      }
    });

    socket.connect();
    _guardSocket = socket;
  }

  static Future<void> ensureAccountGuardSocket() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      _stopAccountGuardSocket();
      return;
    }

    if (_guardSocket?.connected == true) return;
    _startAccountGuardSocket(token);
  }

  // ── User cache ───────────────────────────────────────────────
  static Future<void> saveUser(Map<String, dynamic> user) async {
    _cachedUser = user;
    await _storage.write(key: _keyUser, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final raw = await _storage.read(key: _keyUser);
    if (raw != null) {
      try {
        _cachedUser = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _cachedUser = null;
      }
    }
    return _cachedUser;
  }

  static Map<String, dynamic>? get currentUser => _cachedUser;

  // ── Convenience ──────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final loggedIn = token != null && token.isNotEmpty;
    if (loggedIn) {
      await ensureAccountGuardSocket();
    }
    return loggedIn;
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

      if (res.statusCode == 403) {
        final restriction = <String, dynamic>{};
        final type = body['type']?.toString().trim() ?? '';
        final fromMessage = body['message']?.toString().trim() ?? '';
        final fromReason = body['reason']?.toString().trim() ?? '';
        final suspendedUntil = body['suspendedUntil'];
        final remainingSeconds = body['remainingSeconds'];

        if (type.isNotEmpty) restriction['type'] = type;
        if (fromReason.isNotEmpty) restriction['reason'] = fromReason;
        if (suspendedUntil != null) {
          restriction['suspendedUntil'] = suspendedUntil.toString();
        }
        if (remainingSeconds != null) {
          restriction['remainingSeconds'] = remainingSeconds;
        }

        final popupMessage = fromMessage.isNotEmpty
            ? fromMessage
            : (fromReason.isNotEmpty
                  ? fromReason
                  : 'Your account is restricted.');
        restriction['message'] = popupMessage;

        await NavigationService.forceLogoutToLogin(
          message: popupMessage,
          restriction: restriction,
        );

        return {'success': false, 'handledRestriction': true, 'message': null};
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
    try {
      final res = await ApiClient.post('/users/forgot-password', {
        'email': email,
      }, auth: false);
      final body = _safeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to send reset code',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to send reset code right now.',
      };
    }
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
        final body = _safeObject(res.body);
        final nextAccessToken = (body['accessToken'] ?? '').toString();
        await _storage.write(key: _keyAccess, value: nextAccessToken);
        _startAccountGuardSocket(nextAccessToken);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify email with 6-digit code (requires valid access token).
  static Future<Map<String, dynamic>> verifyEmail(String code) async {
    try {
      final res = await ApiClient.post('/auth/verify-email', {'code': code});
      final body = _safeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to verify email',
      };
    } catch (_) {
      return {'success': false, 'message': 'Unable to verify email right now.'};
    }
  }

  /// Resend the email verification code to [email].
  static Future<Map<String, dynamic>> resendVerification(String email) async {
    try {
      final res = await ApiClient.post('/auth/resend-verification', {
        'email': email,
      }, auth: false);
      final body = _safeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to resend verification code',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to resend verification code right now.',
      };
    }
  }

  /// Resets password via forgot-password code (no auth required).
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.post('/users/reset-password', {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }, auth: false);
      final body = _safeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to reset password',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to reset password right now.',
      };
    }
  }

  /// Changes the current user's password.
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.put('/users/me/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      final body = _safeObject(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body['message'] ?? 'Unable to change password',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to change password right now.',
      };
    }
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
    await clearLocalSession();
  }

  /// Clears local auth/session state without calling backend.
  static Future<void> clearLocalSession() async {
    _stopAccountGuardSocket();
    _cachedUser = null;
    await _storage.deleteAll();
  }

  /// Sign in with Google, then authenticate against backend.
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (!OAuthConfig.isGoogleConfigured) {
        return {
          'success': false,
          'message':
              'Google sign-in is not configured. Set GOOGLE_SERVER_CLIENT_ID before running the app.',
        };
      }

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
    } on PlatformException catch (error) {
      final details = (error.message ?? error.details?.toString() ?? error.code)
          .toLowerCase();
      final code = error.code.toLowerCase();

      if (details.contains('10') ||
          details.contains('developer_error') ||
          details.contains('apiexception: 10') ||
          code.contains('sign_in_failed') ||
          code.contains('api_exception')) {
        return {
          'success': false,
          'message':
              'Google sign-in is misconfigured on Android. Check the SHA-1/SHA-256 fingerprints and the OAuth web client ID.',
        };
      }

      if (code.contains('network_error') ||
          details.contains('network') ||
          details.contains('socket')) {
        return {
          'success': false,
          'message':
              'Google sign-in needs an active internet connection. Please try again.',
        };
      }

      return {
        'success': false,
        'message': 'Google sign-in error: ${error.message ?? error.code}',
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
