import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/app_routes.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'onboarding/user_type_selection_screen.dart';
import 'onboarding/dynamic_onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;
  final String _logoText = 'DJTrip';

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;

      if (result['success'] == true) {
        final user = result['user'] as Map<String, dynamic>?;
        final userType = (user?['userType'] as String?)?.trim();
        final bool isNewUser = result['is_new_user'] as bool? ?? false;
        final bool requiresOnboarding = result['requires_onboarding'] as bool? ?? false;

        // 🚀 CORRECTED: Only show user type selection for NEW Google users without type
        // Existing users should have their userType already set
        if (isNewUser && (userType == null || userType.isEmpty)) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
          );
          return;
        }

        // 🚀 NEW: Handle onboarding for users who need it
        if (requiresOnboarding) {
          // User exists but needs onboarding, go directly to dynamic onboarding
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DynamicOnboardingScreen(),
            ),
          );
          return;
        }

        final route = (userType == 'Organisator' || userType == 'Organizer')
            ? AppRoutes.organizerMain
            : AppRoutes.touristMain;
        Navigator.pushReplacementNamed(context, route);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Google login failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred during Google login')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: Column(
        children: [
          // Top Image Section (approx 35% of height)
          SizedBox(
            height: size.height * 0.35,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image - Djerba themed
                Image.asset(
                  'assets/Pics/Djerbasplash.png',
                  fit: BoxFit.cover,
                ),
                
                // DJTrip Logo with Glassmorphism (Top Left)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Official App Logo
                            Image.asset(
                              'assets/logos/app_logo.png',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(width: 10),
                            // ANIMATED TEXT: 'DJTrip' letter-by-letter
                            AnimatedBuilder(
                              animation: _logoAnimation,
                              builder: (context, child) {
                                final charCount = (_logoAnimation.value * _logoText.length).floor();
                                return Text(
                                  _logoText.substring(0, charCount),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary, // Blue title
                                    letterSpacing: 0.5,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Content Section
          Expanded(
            child: Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF121212) : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // Title Area
                    Text(
                      'Discover',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const Text(
                      'Djerba',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtitle
                    Text(
                      'Join our community of explorers and\nfind the island\'s hidden treasures.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Continue with Google Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isLoading ? null : _handleGoogleLogin,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                else ...[
                                  Image.network(
                                    'https://www.google.com/favicon.ico',
                                    height: 20,
                                    width: 20,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.g_mobiledata,
                                        color: Color(0xFF4285F4),
                                        size: 20,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Continue to Log In Button
                    Container(
                      width: double.infinity,
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pushNamed(context, AppRoutes.login),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.email_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Continue to Log In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign up text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.signup),
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Footer Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.beach_access_rounded, color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF), size: 28),
                        const SizedBox(width: 32),
                        Icon(Icons.restaurant_rounded, color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF), size: 28),
                        const SizedBox(width: 32),
                        Icon(Icons.explore_rounded, color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF), size: 28),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
