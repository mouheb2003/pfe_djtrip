import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import '../config/app_routes.dart';
import '../screens/shared/appeal_form_screen.dart';
import '../models/user_model.dart';
import '../screens/auth/onboarding_screen.dart';
import 'auth_service.dart';

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

      // Only show restriction dialog if there's a valid restriction type
      // This prevents false positives from generic error messages
      if (payload.type.isNotEmpty && 
          (payload.isBanned || payload.isSuspended)) {
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

    await AuthService.clearLocalSession();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    _isRedirecting = false;
  }

  static void navigateToOnboarding({String userType = 'Touriste'}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => OnboardingScreen(userType: userType)),
    );
  }

  static void navigateToWaitingApproval() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamedAndRemoveUntil(AppRoutes.waitingApproval, (route) => false);
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
    DateTime? suspendedUntil;
    final suspendedUntilValue = raw?['suspendedUntil'];
    final suspendedUntilRaw = (suspendedUntilValue ?? '').toString().trim();

    // Debug logging
    print('[RESTRICT] suspendedUntilValue: $suspendedUntilValue (${suspendedUntilValue.runtimeType})');
    print('[RESTRICT] suspendedUntilRaw: "$suspendedUntilRaw"');

    // Accept common formats:
    // - ISO string: "2026-04-10T12:34:56.000Z"
    // - epoch millis / seconds
    // - Mongo Extended JSON: {"$date":"..."} or {"$date":{"$numberLong":"..."}}
    suspendedUntil = DateTime.tryParse(suspendedUntilRaw);
    print('[RESTRICT] After ISO parse: $suspendedUntil');

    if (suspendedUntil == null && suspendedUntilValue is int) {
      // Heuristic: > 10^12 is millis, else seconds.
      suspendedUntil = DateTime.fromMillisecondsSinceEpoch(
        suspendedUntilValue > 1000000000000 ? suspendedUntilValue : suspendedUntilValue * 1000,
      );
      print('[RESTRICT] After int parse: $suspendedUntil');
    }
    if (suspendedUntil == null) {
      final asNum = num.tryParse(suspendedUntilRaw);
      if (asNum != null) {
        final asInt = asNum.toInt();
        suspendedUntil = DateTime.fromMillisecondsSinceEpoch(
          asInt > 1000000000000 ? asInt : asInt * 1000,
        );
        print('[RESTRICT] After num parse: $suspendedUntil');
      }
    }
    if (suspendedUntil == null && suspendedUntilRaw.startsWith('{')) {
      try {
        final decoded = jsonDecode(suspendedUntilRaw);
        print('[RESTRICT] Decoded JSON: $decoded');
        if (decoded is Map) {
          final dateVal = decoded[r'$date'];
          print('[RESTRICT] dateVal: $dateVal (${dateVal.runtimeType})');
          if (dateVal is String) {
            suspendedUntil = DateTime.tryParse(dateVal);
            print('[RESTRICT] After dateVal string parse: $suspendedUntil');
          } else if (dateVal is Map) {
            final numberLong = dateVal[r'$numberLong']?.toString();
            final ms = int.tryParse(numberLong ?? '');
            if (ms != null) {
              suspendedUntil = DateTime.fromMillisecondsSinceEpoch(ms);
              print('[RESTRICT] After numberLong parse: $suspendedUntil');
            }
          } else if (dateVal is int) {
            suspendedUntil = DateTime.fromMillisecondsSinceEpoch(dateVal);
            print('[RESTRICT] After dateVal int parse: $suspendedUntil');
          }
        }
      } catch (e) {
        print('[RESTRICT] JSON decode error: $e');
      }
    }
    print('[RESTRICT] Final suspendedUntil: $suspendedUntil');

    final remainingRaw = raw?['remainingSeconds'];
    final remainingSeconds = remainingRaw is int
        ? remainingRaw
        : int.tryParse(remainingRaw?.toString() ?? '');
    print('[RESTRICT] remainingSeconds: $remainingSeconds');

    // STRICT: No fallback inference based on message text
    // Only accept explicit type values from backend to prevent false positives
    // If type is empty, treat as no restriction (will be handled by caller)

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
  Duration? _initial;

  DateTime? get _until => widget.payload.suspendedUntil ?? _fallbackUntil;

  @override
  void initState() {
    super.initState();
    if (widget.payload.isSuspended) {
      if (widget.payload.suspendedUntil != null) {
        final until = widget.payload.suspendedUntil!;
        final diff = until.difference(DateTime.now());
        _initial = diff.isNegative ? const Duration(seconds: 1) : diff;
      } else {
        final seconds = widget.payload.remainingSeconds ?? 0;
        if (seconds > 0) {
          _initial = Duration(seconds: seconds);
          _fallbackUntil = DateTime.now().add(_initial!);
        }
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
        ? const Color(0xFFDC2626) // Red for banned
        : const Color(0xFFF97316); // Orange for suspension

    final title = isBanned ? 'Account banned' : 'Account suspended';

    final subtitle = isBanned
        ? 'Your account has been permanently banned. Please contact support if you believe this is an error.'
        : 'Your access has been restricted. Please contact support if you believe this is an error.';

    final iconData = isBanned ? Icons.block_flipped : Icons.block_flipped;

    final iconColor = themeColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
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
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: themeColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Temps restant:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (_initial == null && _until == null)
                            ? 'Indéfini'
                            : _formatRemaining(_remaining),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Dynamic progress based on remaining time
                    if (_initial != null && _initial!.inMilliseconds > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (1.0 -
                                  (_remaining.inMilliseconds /
                                          _initial!.inMilliseconds)
                                      .clamp(0.0, 1.0)),
                          minHeight: 8,
                          color: themeColor,
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_until != null)
                      Text(
                        'Réactivation automatique à: '
                        '${_until!.toLocal().day}/${_until!.toLocal().month}/${_until!.toLocal().year} '
                        '${_until!.toLocal().hour.toString().padLeft(2, '0')}:${_until!.toLocal().minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
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
                            suspensionReason: isSuspended
                                ? widget.payload.reason
                                : null,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
      ),
    );
  }
}
