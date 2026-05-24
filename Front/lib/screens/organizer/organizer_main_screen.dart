import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../config/app_routes.dart';
import 'tabs/my_activities_tab.dart';
import 'tabs/organizer_profile_tab.dart';
import '../tourist/tabs/screen_network.dart';
import '../shared/messages_screen.dart';
import '../notifications_screen.dart';
import 'explore_activities_screen.dart';
import '../../services/activity_service.dart';
import '../../services/message_service.dart';
import '../../services/post_service.dart';
import '../shared/ai_chat_screen.dart';
import '../../services/novelty_badge_service.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrganizerMainScreen extends StatefulWidget {
  final int initialIndex;
  const OrganizerMainScreen({super.key, this.initialIndex = 0});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  static const Duration _noveltyRefreshInterval = Duration(seconds: 12);

  static const String _sectionActivities = 'organizer_activities';
  static const String _sectionNetwork = 'organizer_network';

  late int _currentIndex;
  Timer? _noveltyTimer;

  int _activitiesCount = 0;
  int _networkCount = 0;
  int _messagesCount = 0;

  List<Widget> get _pages => [
    const MyActivitiesTab(),
    const ExploreActivitiesScreen(),
    const MessagesScreen(),
    const ScreenNetwork(),
    const NotificationsScreen(isTab: true),
    const OrganizerProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final status = await OnboardingService.getOnboardingStatus();
        final userType = status['userType'] ?? 'Touriste';
        final isApproved = status['is_approved'] ?? true;
        final isOnboarded = status['is_onboarded'] ?? false;
        if (!mounted) return;

        if (userType == 'Organisator' && isOnboarded == true && isApproved == false) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.waitingApproval,
            (route) => false,
          );
        }
      } catch (_) {
        // If status can't be fetched, keep existing UI (best-effort).
      }
    });
    _refreshNoveltyBadges();
    _noveltyTimer = Timer.periodic(_noveltyRefreshInterval, (_) {
      _refreshNoveltyBadges();
    });
  }

  @override
  void dispose() {
    _noveltyTimer?.cancel();
    super.dispose();
  }

  Future<List<String>> _getActivitiesIds() async {
    try {
      final activities = await ActivityService.getMyActivities(refresh: true);
      return activities.map((a) => a.id).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _getActivitiesCount() async {
    final ids = await _getActivitiesIds();
    final prefs = await SharedPreferences.getInstance();
    final userId = (await AuthService.getUserId() ?? '').trim();
    final scope = userId.isEmpty ? 'guest' : userId;
    final key = 'novelty_seen_${scope}_organizer_activities_all_seen_ids';
    final seen = prefs.getStringList(key) ?? [];
    if (seen.isEmpty) {
      await prefs.setStringList(key, ids);
      return 0;
    }
    return ids.where((id) => !seen.contains(id)).length;
  }

  Future<List<String>> _getNetworkIds() async {
    try {
      final posts = await PostService.getFeedPosts();
      return posts.map((p) => (p['_id'] ?? p['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _getNetworkCount() async {
    final ids = await _getNetworkIds();
    final prefs = await SharedPreferences.getInstance();
    final userId = (await AuthService.getUserId() ?? '').trim();
    final scope = userId.isEmpty ? 'guest' : userId;
    final key = 'novelty_seen_${scope}_organizer_network_all_seen_ids';
    final seen = prefs.getStringList(key) ?? [];
    if (seen.isEmpty) {
      await prefs.setStringList(key, ids);
      return 0;
    }
    return ids.where((id) => !seen.contains(id)).length;
  }

  Future<int> _getMessagesCount() async {
    try {
      final conversations = await MessageService.getConversations();
      return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _refreshNoveltyBadges() async {
    try {
      final results = await Future.wait([
        _getActivitiesCount(),
        _getNetworkCount(),
        _getMessagesCount(),
      ]);
      if (!mounted) return;

      setState(() {
        _activitiesCount = _currentIndex == 0 ? 0 : results[0];
        _networkCount = _currentIndex == 3 ? 0 : results[1];
        _messagesCount = _currentIndex == 2 ? 0 : results[2];
      });
    } catch (_) {
      // Best-effort badges: ignore service errors.
    }
  }

  void _markSeenForTab(int index) async {
    if (index == 0) {
      final ids = await _getActivitiesIds();
      final prefs = await SharedPreferences.getInstance();
      final userId = (await AuthService.getUserId() ?? '').trim();
      final scope = userId.isEmpty ? 'guest' : userId;
      final key = 'novelty_seen_${scope}_organizer_activities_all_seen_ids';
      final seenIds = prefs.getStringList(key) ?? [];
      final newSet = {...seenIds, ...ids}.toList();
      await prefs.setStringList(key, newSet);
      setState(() => _activitiesCount = 0);
    }
    if (index == 3) {
      final ids = await _getNetworkIds();
      final prefs = await SharedPreferences.getInstance();
      final userId = (await AuthService.getUserId() ?? '').trim();
      final scope = userId.isEmpty ? 'guest' : userId;
      final key = 'novelty_seen_${scope}_organizer_network_all_seen_ids';
      final seenIds = prefs.getStringList(key) ?? [];
      final newSet = {...seenIds, ...ids}.toList();
      await prefs.setStringList(key, newSet);
      setState(() => _networkCount = 0);
    }
  }

  void _goToTab(int index) {
    _markSeenForTab(index);
    setState(() {
      _currentIndex = index;
      if (index == 0) _activitiesCount = 0;
      if (index == 3) _networkCount = 0;
      if (index == 2) _messagesCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF2F1FA);
    const navActive = AppColors.primary;
    final navInactive = isDark ? const Color(0xFF9DA3C8) : const Color(0xFF7B82A8);

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _pages),
            Positioned(
              bottom: 18,
              left: 16,
              right: 16,
              child: _buildFloatingNavBar(navBg, navActive, navInactive),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(Color navBg, Color navActive, Color navInactive) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Main pill-shaped nav bar
        Container(
          height: 70,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Activities',
                index: 0,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _activitiesCount,
              ),
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Explore',
                index: 1,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Messages',
                index: 2,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _messagesCount,
              ),
              _NavItem(
                icon: Icons.public,
                activeIcon: Icons.public,
                label: 'Network',
                index: 3,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _networkCount,
              ),
              _NavItem(
                icon: Icons.notifications_none,
                activeIcon: Icons.notifications,
                label: 'Notifs',
                index: 4,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 5,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: isActive ? 50 : 40,
                  height: isActive ? 50 : 40,
                  alignment: Alignment.center,
                  decoration: isActive
                      ? BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? cs.onPrimary : inactiveColor,
                    size: isActive ? 26 : 18,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 0.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
