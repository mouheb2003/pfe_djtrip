import 'package:flutter/material.dart';

import '../config/app_routes.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _isRedirecting = false;

  static Future<void> forceLogoutToLogin({String? message}) async {
    if (_isRedirecting) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _isRedirecting = true;

    try {
      final popupMessage = (message ?? '').trim();
      if (popupMessage.isNotEmpty) {
        final dialogContext = navigator.overlay?.context;
        if (dialogContext != null) {
          await showDialog<void>(
            context: dialogContext,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Compte restreint'),
              content: Text(popupMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}

    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    _isRedirecting = false;
  }
}
