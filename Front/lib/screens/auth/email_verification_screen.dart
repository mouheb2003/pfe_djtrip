import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../onboarding/user_type_selection_screen.dart';
import '../onboarding/dynamic_onboarding_screen.dart';
import '../../config/app_routes.dart';
import '../../utils/snackbar_utils.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String userType;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.userType,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _ctrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 120;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrl) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _mm => (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
  String get _ss => (_remainingSeconds % 60).toString().padLeft(2, '0');
  bool get _canResend => _remainingSeconds == 0;

  Future<void> _verify() async {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _errorMsg = 'Please enter the complete code.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    try {
      final result = await AuthService.verifyEmail(code);
      if (!mounted) return;
      if (result['success'] == true) {
        final bool requiresOnboarding = result['requires_onboarding'] ?? false;
        final bool skipUserTypeSelection = result['skip_user_type_selection'] ?? true;

        if (requiresOnboarding) {
          if (skipUserTypeSelection) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DynamicOnboardingScreen(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UserTypeSelectionScreen(),
              ),
            );
          }
        } else {
          final route = (widget.userType == 'Organisator' || widget.userType == 'Organizer')
              ? AppRoutes.organizerMain
              : AppRoutes.touristMain;
          Navigator.pushReplacementNamed(context, route);
        }
      } else {
        SnackbarUtils.showError(context, result['message'] ?? 'Invalid or expired code.');
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    try {
      final result = await AuthService.resendVerification(widget.email);
      if (!mounted) return;
      if (result['success'] == true) {
        for (final c in _ctrl) c.clear();
        _focus[0].requestFocus();
        _startTimer();
        SnackbarUtils.showSuccess(context, result['message'] ?? 'Verification code resent.');
      } else {
        SnackbarUtils.showError(context, result['message'] ?? 'Failed to resend.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative background circle
          Positioned(
            top: -100,
            left: -100,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: AppColors.primary.withOpacity(0.05),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Top navigation bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'DJTrip',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Email icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Title
                        const Text(
                          'Verify your email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Subtitle with email address
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: 'We sent a 6-digit code to\n',
                              ),
                              TextSpan(
                                text: widget.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // OTP input boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) => _buildOtpBox(i)),
                        ),
                        const SizedBox(height: 40),

                        // Countdown timer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTimerUnit(_mm, 'MIN'),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildTimerUnit(_ss, 'SEC'),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Resend code row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't receive a code? ",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            GestureDetector(
                              onTap: _canResend ? _resend : null,
                              child: _isResending
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Resend',
                                      style: TextStyle(
                                        color: _canResend
                                            ? AppColors.primary
                                            : AppColors.textLight,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        const SizedBox(height: 10),
                        // Verify button
                        Container(
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentSoft],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Verify',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 50,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _ctrl[index],
        focusNode: _focus[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          height: 1.0,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _focus[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _focus[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildTimerUnit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
