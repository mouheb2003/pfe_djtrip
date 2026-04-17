import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_notification_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/navigation_service.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import '../onboarding/user_type_selection_screen.dart';
import '../organizer/waiting_approval_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;
  String? _errorMsg;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final storage = FlutterSecureStorage();
    final savedEmail = await storage.read(key: 'remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      final savedPassword = await storage.read(key: 'remembered_password');
      setState(() {
        _emailCtrl.text = savedEmail;
        if (savedPassword != null && savedPassword.isNotEmpty) {
          _passwordCtrl.text = savedPassword;
        }
        _rememberMe = true;
      });
    } else {
      setState(() {
        _rememberMe = false;
      });
    }
  }

  Future<void> _saveRememberedEmail(String email, String password) async {
    final storage = FlutterSecureStorage();
    if (_rememberMe) {
      await storage.write(key: 'remembered_email', value: email);
      await storage.write(key: 'remembered_password', value: password);
    } else {
      await storage.delete(key: 'remembered_email');
      await storage.delete(key: 'remembered_password');
    }
  }

  void _startLockoutTimer(int seconds) {
    // ... lockout logic ...
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSecondsRemaining = seconds;
      _errorMsg =
          'Too many attempts. Try again in $_lockoutSecondsRemaining s.';
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSecondsRemaining > 0) {
        setState(() {
          _lockoutSecondsRemaining--;
          _errorMsg =
              'Too many attempts. Try again in $_lockoutSecondsRemaining s.';
        });
      } else {
        timer.cancel();
        setState(() => _errorMsg = null);
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final result = await AuthService.signIn(email, password);
      if (!mounted) return;

      if (result['success'] == true) {
        await _saveRememberedEmail(email, password);
        final user = result['user'] as Map<String, dynamic>?;
        final userType = user?['userType'] as String? ?? 'Touriste';

        // � Send FCM token to backend for push notifications
        try {
          await FcmNotificationService().sendTokenToBackend();
        } catch (e) {
          debugPrint('Error sending FCM token: $e');
          // Don't block login if FCM fails
        }

        // �🚀 NEW: Handle email verification flow
        if (result['emailVerified'] == false) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: user?['email'] ?? email,
                userType: userType,
              ),
            ),
          );
          return;
        }

        // 🚀 NEW: Handle onboarding flow
        final bool requiresOnboarding = result['requires_onboarding'] ?? false;
        final bool skipUserTypeSelection = result['skip_user_type_selection'] ?? true;

        if (requiresOnboarding) {
          if (skipUserTypeSelection) {
            // Account exists with a type, go directly to onboarding
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OnboardingScreen(userType: userType),
              ),
            );
          } else {
            // New account, show user type selection first
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UserTypeSelectionScreen(),
              ),
            );
          }
          return;
        }

        // ✅ Organizer gating: still pending admin approval
        if (userType == 'Organisator' || userType == 'Organizer') {
          try {
            final status = await OnboardingService.getOnboardingStatus();
            final isApproved = status['is_approved'] ?? true;
            if (status['success'] == true && isApproved == false) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
              );
              return;
            }
          } catch (_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
            );
            return;
          }
        }

        final route = (userType == 'Organisator' || userType == 'Organizer')
            ? AppRoutes.organizerMain
            : AppRoutes.touristMain;
        Navigator.pushReplacementNamed(context, route);
      } else if (result['locked'] == true) {
        _startLockoutTimer(result['remainingSeconds'] as int? ?? 60);
      } else if (result['handledRestriction'] == true) {
        setState(() => _errorMsg = null);
      } else {
        setState(() => _errorMsg = result['message'] as String?);
      }
    } catch (_) {
      if (mounted) setState(() => _errorMsg = 'An error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed to pure white for consistency
      body: SafeArea(
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.splash),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Brand Logo / Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logos/app_logo.png',
                          height: 100,
                          width: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue your journey',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 50),

                    // Input Fields
                    _buildInputField(
                      controller: _emailCtrl,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _passwordCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF9CA3AF),
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),

                    // Remember Me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Error Message
                    if (_errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Login Button
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isLoading || _lockoutSecondsRemaining > 0)
                            ? null
                            : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Navigation to Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.signup,
                          ),
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          suffixIcon: suffixIcon,
          hintStyle: TextStyle(color: AppColors.textLight),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
