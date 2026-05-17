import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SnackBarType { success, error, info, warning }

class SnackbarUtils {
  SnackbarUtils._();

  static void showSnackBar(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Clear existing snackbars
    scaffoldMessenger.removeCurrentSnackBar();

    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xFF10B981); // Emerald 500
        icon = Icons.check_circle_rounded;
        iconColor = Colors.white;
        break;
      case SnackBarType.error:
        backgroundColor = const Color(0xFFEF4444); // Red 500
        icon = Icons.error_rounded;
        iconColor = Colors.white;
        break;
      case SnackBarType.warning:
        backgroundColor = const Color(0xFFF59E0B); // Amber 500
        icon = Icons.warning_rounded;
        iconColor = Colors.white;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = AppColors.primary;
        icon = Icons.info_rounded;
        iconColor = Colors.white;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    showSnackBar(context, message: message, type: SnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    showSnackBar(context, message: message, type: SnackBarType.error);
  }

  static void showInfo(BuildContext context, String message) {
    showSnackBar(context, message: message, type: SnackBarType.info);
  }

  static void showWarning(BuildContext context, String message) {
    showSnackBar(context, message: message, type: SnackBarType.warning);
  }
}
