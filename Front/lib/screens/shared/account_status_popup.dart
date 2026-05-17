import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import 'appeal_form_screen.dart';

class AccountStatusPopup extends StatefulWidget {
  final UserStatus status;
  final String? banReason;
  final String? suspensionReason;
  final DateTime? suspendedUntil;

  const AccountStatusPopup({
    super.key,
    required this.status,
    this.banReason,
    this.suspensionReason,
    this.suspendedUntil,
  });

  @override
  State<AccountStatusPopup> createState() => _AccountStatusPopupState();
}

class _AccountStatusPopupState extends State<AccountStatusPopup> {
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    if (widget.status == UserStatus.suspended && widget.suspendedUntil != null) {
      _updateCountdown();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateCountdown();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (widget.suspendedUntil != null) {
      final now = DateTime.now();
      final remaining = widget.suspendedUntil!.difference(now);
      
      if (remaining.isNegative) {
        // Suspension expired, refresh user status
        _refreshUserStatus();
      } else {
        setState(() {
          _remainingTime = remaining;
        });
      }
    }
  }

  Future<void> _refreshUserStatus() async {
    // Suspension expired — user will be re-authenticated on next action.
    // No further action needed here; the app handles status on navigation.
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isBanned = widget.status == UserStatus.banned;
    final isSuspended = widget.status == UserStatus.suspended;

    return WillPopScope(
      onWillPop: () async {
        // Prevent popup from being dismissed
        return false;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isBanned 
                        ? [const Color(0xFFFF4757), const Color(0xFFE74C3C)]
                        : [const Color(0xFFFFA502), const Color(0xFFFF8C42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isBanned ? Icons.block : Icons.access_time,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isBanned ? 'Account Banned' : 'Account Suspended',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBanned) ...[
                      const Text(
                        'Your account has been permanently banned.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                          height: 1.5,
                        ),
                      ),
                      if (widget.banReason != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFEB3B3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reason:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF856404),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.banReason!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    
                    if (isSuspended) ...[
                      const Text(
                        'Your account has been temporarily suspended.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                          height: 1.5,
                        ),
                      ),
                      if (widget.suspensionReason != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reason:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.suspensionReason!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (isSuspended && widget.suspendedUntil != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4B63FF)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Time Remaining:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B63FF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDuration(_remainingTime),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4B63FF),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Contact Support Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppealFormScreen(
                                userStatus: widget.status,
                                banReason: widget.banReason,
                                suspensionReason: widget.suspensionReason,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.support_agent, size: 20),
                        label: const Text(
                          'Contact Support',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B63FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
