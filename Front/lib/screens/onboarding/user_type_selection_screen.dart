import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';
import 'dynamic_onboarding_screen.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedUserType;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onUserTypeSelected(String userType) {
    HapticFeedback.lightImpact();
    setState(() => _selectedUserType = userType);
  }

  void _onNextPressed() {
    if (_selectedUserType != null) {
      _persistTypeAndContinue(_selectedUserType!);
    }
  }

  String _mapToBackendUserType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'organizer' || v == 'organisator') return 'Organisator';
    if (v == 'business') return 'Business';
    return 'Touriste';
  }

  Future<void> _persistTypeAndContinue(String raw) async {
    final backendType = _mapToBackendUserType(raw);
    try {
      final res = await OnboardingService.updateUserType(backendType);
      if (!mounted) return;

      if (res['success'] == true) {
        // Refresh user data from backend to get updated userType
        await AuthService.refreshCurrentUser();
        
        // Small delay to ensure cache is updated
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate directly to onboarding screen
        if (!mounted) return;
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => DynamicOnboardingScreen(),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Unable to save account type')),
      );
    } catch (e) {
      if (!mounted) return;
      print('Error in _persistTypeAndContinue: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save account type right now')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FF),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      
                      // Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to DJTrip!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E225E),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose your account type to get started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[400] : const Color(0xFF6C757D),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // User Type Cards
                      Column(
                        children: [
                          // Tourist Card
                          _UserTypeCard(
                            title: 'Tourist',
                            subtitle: 'Discover amazing activities and experiences',
                            description: 'Book activities, join tours, and explore destinations with local guides',
                            icon: Icons.explore,
                            color: const Color(0xFF4B63FF),
                            isSelected: _selectedUserType == 'tourist',
                            onTap: () => _onUserTypeSelected('tourist'),
                            isDark: isDark,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Organizer Card
                          _UserTypeCard(
                            title: 'Organizer',
                            subtitle: 'Share your experiences with others',
                            description: 'Create and manage activities, guide tourists, and grow your business',
                            icon: Icons.business_center,
                            color: const Color(0xFF00B894),
                            isSelected: _selectedUserType == 'organizer',
                            onTap: () => _onUserTypeSelected('organizer'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Bottom Section
                      Column(
                        children: [
                          // Info text for organizer
                          if (_selectedUserType == 'organizer')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFC107),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: const Color(0xFF856404),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Your account will require approval before you can create activities',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFF856404),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Next Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _selectedUserType != null ? _onNextPressed : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4B63FF),
                                disabledBackgroundColor: const Color(0xFFCBD5E0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedUserType != null ? Colors.white : const Color(0xFF6C757D),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF6C757D),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/login');
                                },
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4B63FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? color.withOpacity(0.3)
                  : Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
          border: Border.all(
            color: isSelected 
                ? color 
                : color.withOpacity(0.2),
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E225E)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                            ? Colors.white.withOpacity(0.9)
                            : color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected 
                            ? Colors.white.withOpacity(0.8)
                            : (isDark ? Colors.grey[400] : const Color(0xFF6C757D)),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Selection Indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: color,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
