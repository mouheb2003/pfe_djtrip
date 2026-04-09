import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../config/app_routes.dart';
import '../screens/shared/appeal_form_screen.dart';
import '../models/user_model.dart';
import '../screens/auth/onboarding_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _isRedirecting = false;

  static Future<void> forceLogoutToLogin({
    String? message,
    Map<String, dynamic>? restriction,
  }) async {
    if (_isRedirecting) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _isRedirecting = true;

    try {
      final payload = _RestrictionPayload.from(
        message: message,
        raw: restriction,
      );

      if (payload.message.isNotEmpty || payload.reason.isNotEmpty) {
        final dialogContext = navigator.overlay?.context;
        if (dialogContext != null) {
          await showDialog<void>(
            context: dialogContext,
            barrierDismissible: false,
            builder: (context) => _AccountRestrictedDialog(payload: payload),
          );
        }
      }
    } catch (_) {}

    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    _isRedirecting = false;
  }

  static void navigateToOnboarding({String userType = 'Touriste'}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(userType: userType),
      ),
    );
  }

  static void navigateToWaitingApproval() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Use welcome as a temporary fallback or a dedicated screen if available
    navigator.pushReplacementNamed(AppRoutes.welcome);
  }

  static void navigateToHome({String? userType}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final route = (userType == 'Organisator' || userType == 'Organizer')
        ? AppRoutes.organizerMain
        : AppRoutes.touristMain;
    navigator.pushNamedAndRemoveUntil(route, (route) => false);
  }
}

class _RestrictionPayload {
  final String type;
  final String message;
  final String reason;
  final DateTime? suspendedUntil;
  final int? remainingSeconds;

  const _RestrictionPayload({
    required this.type,
    required this.message,
    required this.reason,
    required this.suspendedUntil,
    required this.remainingSeconds,
  });

  bool get isBanned => type == 'banned';
  bool get isSuspended => type == 'suspended';

  UserStatus get toUserStatus {
    if (isBanned) return UserStatus.banned;
    if (isSuspended) return UserStatus.suspended;
    return UserStatus.active;
  }

  static _RestrictionPayload from({
    String? message,
    Map<String, dynamic>? raw,
  }) {
    var type = (raw?['type'] ?? '').toString().trim().toLowerCase();
    final reason = (raw?['reason'] ?? '').toString().trim();
    final msg = (raw?['message'] ?? message ?? '').toString().trim();
    final suspendedUntilRaw = (raw?['suspendedUntil'] ?? '').toString().trim();
    final suspendedUntil = DateTime.tryParse(suspendedUntilRaw);
    final remainingRaw = raw?['remainingSeconds'];
    final remainingSeconds = remainingRaw is int
        ? remainingRaw
        : int.tryParse(remainingRaw?.toString() ?? '');

    // Fallback inference when backend does not include explicit type.
    if (type.isEmpty) {
      final probe = '${msg.toLowerCase()} ${reason.toLowerCase()}';
      if (probe.contains('banned') || probe.contains('banni')) {
        type = 'banned';
      } else if (probe.contains('suspended') ||
          probe.contains('suspendu') ||
          probe.contains('suspendu')) {
        type = 'suspended';
      }
    }

    return _RestrictionPayload(
      type: type,
      message: msg,
      reason: reason,
      suspendedUntil: suspendedUntil,
      remainingSeconds: remainingSeconds,
    );
  }
}

class _AccountRestrictedDialog extends StatefulWidget {
  final _RestrictionPayload payload;

  const _AccountRestrictedDialog({required this.payload});

  @override
  State<_AccountRestrictedDialog> createState() =>
      _AccountRestrictedDialogState();
}

class _AccountRestrictedDialogState extends State<_AccountRestrictedDialog> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  DateTime? _fallbackUntil;

  @override
  void initState() {
    super.initState();
    if (widget.payload.isSuspended && widget.payload.suspendedUntil == null) {
      final seconds = widget.payload.remainingSeconds ?? 0;
      if (seconds > 0) {
        _fallbackUntil = DateTime.now().add(Duration(seconds: seconds));
      }
    }
    _updateRemaining();
    if (widget.payload.isSuspended) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_updateRemaining);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final until = widget.payload.suspendedUntil ?? _fallbackUntil;
    if (until == null) {
      _remaining = Duration.zero;
      return;
    }

    final diff = until.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  String _formatRemaining(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isBanned = widget.payload.isBanned;
    final isSuspended = widget.payload.isSuspended;
    
    final themeColor = isBanned
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB); // Use Blue for suspension as per image

    final title = isBanned
        ? 'Account banned'
        : 'Account suspended';

    final subtitle = isBanned
        ? 'Your account has been permanently banned. Please contact support if you believe this is an error.'
        : 'Your access has been restricted. Please contact support if you believe this is an error.';

    final iconData = isBanned
        ? Icons.block_flipped
        : Icons.block_flipped;
    
    final iconColor = themeColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 36),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Suspension Timer Card
            if (isSuspended) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Reconnect in:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatRemaining(_remaining),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar placeholder
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.6, // Static placeholder for visual consistency
                        child: Container(
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Column(
              children: [
                // Appeal Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppealFormScreen(
                            userStatus: widget.payload.toUserStatus,
                            banReason: isBanned ? widget.payload.reason : null,
                            suspensionReason: isSuspended ? widget.payload.reason : null,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Submit Appeal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Back to Login Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Go back to login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
