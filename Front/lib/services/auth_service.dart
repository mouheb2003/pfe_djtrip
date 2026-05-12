import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';
import 'api_service.dart';
import 'navigation_service.dart';
import 'fcm_notification_service.dart';
import 'heartbeat_service.dart';
import '../config/app_routes.dart';
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
    _guardSocket?.off('new_notification');
    _guardSocket?.off('connect_error');
    _guardSocket?.off('account_restricted');
    _guardSocket?.disconnect();
    _guardSocket?.dispose();
    _guardSocket = null;
  }

  static Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'djtrip_notifications',
      'DJTrip Notifications',
      channelDescription: 'Notifications for DJTrip',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      int.tryParse(data['notificationId']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
      data['title']?.toString() ?? 'Notification',
      data['message']?.toString() ?? '',
      platformChannelSpecifics,
    );
  }

  static Future<void> _handleAccountRestriction(dynamic data) async {
    if (_handlingRestriction) return;
    _handlingRestriction = true;

    try {
      // Safely parse the payload
      final restriction = <String, dynamic>{};
      String message = 'Your account is restricted. Please sign in again.';

      if (data is Map) {
        // STRICT CHECK: Only process if type is 'ACCOUNT_RESTRICTED' or valid restriction type
        final type = data['type']?.toString().trim().toUpperCase() ?? '';
        
        // Only accept explicit restriction types from backend
        if (type != 'ACCOUNT_RESTRICTED' && 
            type != 'BANNED' && 
            type != 'SUSPENDED') {
          // Not a valid restriction type, ignore
          return;
        }

        final fromMessage = data['message']?.toString().trim() ?? '';
        final fromReason = data['reason']?.toString().trim() ?? '';
        final suspendedUntil = data['suspendedUntil'];
        final remainingSeconds = data['remainingSeconds'];

        if (type.isNotEmpty) restriction['type'] = type.toLowerCase();
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
    } catch (e) {
      // Log error but don't crash
      print('[AuthService] Error handling account restriction: $e');
    } finally {
      _handlingRestriction = false;
    }
  }

  static Future<void> _handleSessionExpiration() async {
    // Handle session expiration separately - normal logout without restriction popup
    try {
      await clearLocalSession();
      final navigator = NavigationService.navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.login, 
          (route) => false,
        );
      }
    } catch (e) {
      print('[AuthService] Error handling session expiration: $e');
    }
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

    // Handle successful connection
    socket.on('connect', (_) {
      print('[AuthService] Account guard socket connected');
    });

    // Handle disconnection
    socket.on('disconnect', (_) {
      print('[AuthService] Account guard socket disconnected');
    });

    // Handle new notifications
    socket.on('new_notification', (data) {
      print('[AuthService] Received new_notification event: $data');
      // Show local notification
      _showLocalNotification(data);
    });

    // ONLY handle explicit account restrictions from backend
    // This is the ONLY reliable source of real restrictions
    socket.on('account_restricted', (data) async {
      print('[AuthService] Received account_restricted event: $data');
      await _handleAccountRestriction(data);
    });

    // Handle connection errors - DO NOT trigger restriction logic
    // Only log for debugging and let socket reconnection handle it
    socket.on('connect_error', (error) async {
      print('[AuthService] Socket connection error: $error');
      // Socket will automatically reconnect due to enableReconnection()
      // Do NOT call _handleAccountRestriction here to avoid false positives
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
    
    // 💓 Start heartbeat service after successful authentication
    try {
      HeartbeatService.instance.startHeartbeat();
      print('💓 [AUTH] Heartbeat service started after user authentication');
    } catch (e) {
      print('❌ [AUTH] Error starting heartbeat service: $e');
    }
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

  /// Refresh current user data from backend and update cache
  static Future<Map<String, dynamic>?> refreshCurrentUser() async {
    try {
      final res = await ApiClient.get('/users/me');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['user'] is Map<String, dynamic>) {
          final user = body['user'] as Map<String, dynamic>;
          await saveUser(user);
          return user;
        }
      }
      return null;
    } catch (e) {
      print('[AuthService] Error refreshing current user: $e');
      return null;
    }
  }

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

        // 🚀 NEW: Check if email verification is required
        if (body['emailVerified'] == false) {
          return {
            'success': true,
            'emailVerified': false,
            'user': user,
          };
        }

        return {'success': true, 'emailVerified': true, 'user': user};
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
        print('[AUTH SIGNIN 403] Full response body: $body');
        print('[AUTH SIGNIN 403] type: ${body['type']}');
        print('[AUTH SIGNIN 403] message: ${body['message']}');
        print('[AUTH SIGNIN 403] reason: ${body['reason']}');
        print('[AUTH SIGNIN 403] suspendedUntil: ${body['suspendedUntil']} (${body['suspendedUntil']?.runtimeType})');
        print('[AUTH SIGNIN 403] remainingSeconds: ${body['remainingSeconds']}');

        final type = body['type']?.toString().trim() ?? '';
        final fromMessage = body['message']?.toString().trim() ?? '';
        final fromReason = body['reason']?.toString().trim() ?? '';
        final suspendedUntil = body['suspendedUntil'];
        final remainingSeconds = body['remainingSeconds'];

        print('[AUTH SIGNIN 403] Extracted - type: $type, suspendedUntil: $suspendedUntil, remainingSeconds: $remainingSeconds');

        final restriction = <String, dynamic>{};
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

        print('[AUTH SIGNIN 403] Final restriction map: $restriction');

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
    String? username, // Optional: if not provided, backend will auto-generate
  }) async {
    try {
      final res = await ApiClient.post('/users/signup', {
        'fullname': fullname,
        'email': email,
        'mot_de_passe': password,
        'userType': userType,
        if (username != null) 'username': username, // Only send if provided
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
        'requires_onboarding': body['requires_onboarding'] ?? false,
        'skip_user_type_selection': body['skip_user_type_selection'] ?? true,
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
    // 📱 Remove FCM token on logout
    try {
      await FcmNotificationService().deleteToken();
    } catch (e) {
      print('[AuthService] Error removing FCM token: $e');
    }
    await clearLocalSession();
  }

  /// Clears local auth/session state without calling backend.
  static Future<void> clearLocalSession() async {
    _stopAccountGuardSocket();
    _cachedUser = null;
    
    // 💓 Stop heartbeat service on logout
    try {
      HeartbeatService.instance.stopHeartbeat();
      print('💓 [AUTH] Heartbeat service stopped on logout');
    } catch (e) {
      print('❌ [AUTH] Error stopping heartbeat service: $e');
    }
    
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

      // Sign out first to ensure account selection is shown
      await _googleSignIn.signOut();

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

      final res = await ApiClient.post('/auth/google', {
        'idToken': idToken,
      }, auth: false);

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = {};
      }

      if (res.statusCode != 200) {
        // Handle account status errors (suspended, banned, inactive)
        if (res.statusCode == 403) {
          final type = body['type']?.toString().trim() ?? '';
          final fromMessage = body['message']?.toString().trim() ?? '';
          final fromReason = body['reason']?.toString().trim() ?? '';
          final suspendedUntil = body['suspendedUntil'];
          final remainingSeconds = body['remainingSeconds'];

          final restriction = <String, dynamic>{};
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

        // Handle lockout (423)
        if (res.statusCode == 423) {
          return {
            'success': false,
            'locked': true,
            'message': body['message'] ?? 'Account temporarily locked.',
            'remainingSeconds': body['remainingSeconds'] ?? 60,
          };
        }

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

      // Send FCM token to backend after successful login
      try {
        await FcmNotificationService().sendTokenToBackend();
      } catch (_) {
        // FCM token send failure should not block login
      }

      // Handle onboarding requirement for new Google users
      final requiresOnboarding = body['requires_onboarding'] as bool? ?? false;
      final isNewUser = body['is_new_user'] as bool? ?? false;

      return {
        'success': true,
        'user': user,
        'requires_onboarding': requiresOnboarding,
        'is_new_user': isNewUser,
      };
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

      // Send FCM token to backend after successful login
      try {
        await FcmNotificationService().sendTokenToBackend();
      } catch (_) {
        // FCM token send failure should not block login
      }

      return {'success': true, 'user': user};
    } catch (_) {
      return {
        'success': false,
        'message': 'Facebook authentication failed. Please try again.',
      };
    }
  }

  // ── Language Preferences ──────────────────────────────────────
  static const _keyLanguage = 'djtrip_language_preference';
  static const _keyTermsAccepted = 'djtrip_terms_accepted';

  static Future<String?> getLanguagePreference() async {
    return await _storage.read(key: _keyLanguage);
  }

  static Future<void> saveLanguagePreference(String language) async {
    await _storage.write(key: _keyLanguage, value: language);
  }

  static Future<bool> hasAcceptedTerms() async {
    final accepted = await _storage.read(key: _keyTermsAccepted);
    return accepted == 'true';
  }

  static Future<void> acceptTermsOfUse() async {
    await _storage.write(key: _keyTermsAccepted, value: 'true');
  }

  static Future<bool> hasAcceptedPrivacyPolicy() async {
    final accepted = await _storage.read(key: 'djtrip_privacy_policy_accepted');
    return accepted == 'true';
  }

  static Future<void> acceptPrivacyPolicy() async {
    await _storage.write(key: 'djtrip_privacy_policy_accepted', value: 'true');
  }
}
