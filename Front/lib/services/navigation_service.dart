import 'package:flutter/material.dart';
import 'dart:async';

import '../config/app_routes.dart';

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
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${mins}m ${secs}s';
    }
    if (hours > 0) {
      return '${hours}h ${mins}m ${secs}s';
    }
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final isBanned = widget.payload.isBanned;
    final isSuspended = widget.payload.isSuspended;
    final themeColor = isBanned
        ? const Color(0xFFDC2626)
        : isSuspended
        ? const Color(0xFFF59E0B)
        : const Color(0xFF4F46E5);

    final title = isBanned
        ? 'Your account is banned'
        : isSuspended
        ? 'Your account is suspended'
        : 'Account restricted';

    final subtitle = isBanned
        ? 'Your DJTrip account has been banned. You cannot access the app.'
        : isSuspended
        ? 'Your DJTrip account is temporarily suspended. Sign in again later.'
        : (widget.payload.message.isNotEmpty
              ? widget.payload.message
              : 'Your account access is currently restricted.');

    final iconData = isBanned
        ? Icons.gpp_bad_rounded
        : isSuspended
        ? Icons.hourglass_top_rounded
        : Icons.lock_outline_rounded;
    final iconColor = themeColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: const Color(0xFFF8FAFC),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      title: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30 / 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF475569), height: 1.35),
          ),
          if (widget.payload.reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeColor.withOpacity(0.32)),
              ),
              child: Text(
                'Reason: ${widget.payload.reason}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (isSuspended) ...[
            const SizedBox(height: 12),
            Text(
              'Remaining suspension time: ${_formatRemaining(_remaining)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: themeColor),
            ),
            const SizedBox(height: 6),
            Text(
              _remaining > Duration.zero
                  ? 'Sign in again later when the timer reaches zero.'
                  : 'You can reconnect now.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (isBanned) ...[
            const SizedBox(height: 12),
            const Text(
              'Ban status is permanent until the admin restores your account.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: themeColor,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Go back to login'),
          ),
        ),
      ],
    );
  }
}
