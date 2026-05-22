import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import 'my_activities_screen.dart';
import 'tabs/home_tab.dart';
import '../../features/maps/presentation/map_explorer_screen.dart';
import 'tabs/screen_network.dart';
import 'tabs/tourist_profile_tab.dart';
import '../shared/messages_screen.dart';
import '../shared/notification_history_screen.dart';
import '../../services/lieu_service.dart';
import '../../services/post_service.dart';
import '../../services/message_service.dart';
import '../../services/inscription_service.dart';
import '../../services/novelty_badge_service.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/review_reminder_service.dart' as review_service;
import '../../models/inscription_model.dart';
import '../../models/activity_model.dart';
import '../../models/booking_model.dart';
import '../shared/review_prompt_modal.dart';

class TouristMainScreen extends StatefulWidget {
  final int initialIndex;
  const TouristMainScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _TouristMainScreenState createState() => _TouristMainScreenState();
}

class _TouristMainScreenState extends State<TouristMainScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;
  int _homeCount = 0;
  int _activitiesCount = 0;
  int _networkCount = 0;
  int _messagesCount = 0;
  final String _sectionHome = 'home';
  final String _sectionActivities = 'activities';
  final String _sectionNetwork = 'network';
  final String _sectionMessages = 'messages';
  bool _isNavbarVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _pages = [
      HomeTab(
        onExploreTap: () => _goToTab(2),
        onMessagesTap: () => _goToTab(3),
        onActivitiesTap: () => _goToTab(1),
        onNotificationsTap: () => _goToTab(4),
        onProfileTap: () => _goToTab(6),
        showMessagesDot: _messagesCount > 0,
      ),
      const MyActivitiesScreen(),
      MapExplorerScreen(
        onToggleNavbar: (visible) {
          setState(() {
            _isNavbarVisible = visible;
          });
        },
      ),
      const MessagesScreen(),
      const NotificationHistoryScreen(isTab: true),
      const ScreenNetwork(),
      TouristProfileTab(onNavigateToTab: _goToTab),
    ];

    _refreshNoveltyBadges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        _checkAndShowReviewPopup();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAndShowReviewPopup() async {
    if (!mounted) return;

    try {
      final pendingReview =
          await review_service.ReviewReminderService.getNextPendingReview();
      if (pendingReview == null) return;

      final booking = pendingReview['booking'] as InscriptionModel;
      final activity = pendingReview['activity'] as ActivityModel;

      // Convert InscriptionModel to BookingModel for ReviewPromptModal
      final bookingModel = BookingModel(
        id: booking.id,
        activityId: booking.activite?['_id'] ?? '',
        touristeId: booking.touriste?['_id'] ?? '',
        organisateurId: booking.organisateur?['_id'] ?? '',
        statut: booking.statut,
        createdAt: booking.dateDemande ?? DateTime.now(),
        dateReservation: booking.dateDemande ?? DateTime.now(),
        nombreParticipants: booking.nombreParticipants,
        prixTotal: booking.prixTotal,
        checkedIn: booking.qrUsedAt != null,
        hasReviewed: false,
        activity: booking.activite,
        touriste: booking.touriste,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            ReviewPromptModal(booking: bookingModel, activity: activity),
      );

      // Mark as shown after popup is closed
      await review_service.ReviewReminderService.markAsShown(booking.id);
    } catch (e) {
      debugPrint('[TouristMainScreen] Error showing review popup: $e');
    }
  }

  Future<List<String>> _getHomeIds() async {
    try {
      final lieux = await LieuService.getLieux();
      return lieux.map((e) => e.id).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _getHomeCount() async {
    final ids = await _getHomeIds();
    final prefs = await SharedPreferences.getInstance();
    final userId = (await AuthService.getUserId() ?? '').trim();
    final scope = userId.isEmpty ? 'guest' : userId;
    final key = 'novelty_seen_${scope}_home_all_seen_ids';
    final seen = prefs.getStringList(key) ?? [];
    if (seen.isEmpty) {
      await prefs.setStringList(key, ids);
      return 0;
    }
    return ids.where((id) => !seen.contains(id)).length;
  }

  Future<List<String>> _getActivitiesIds() async {
    try {
      final bookings = await InscriptionService.getMyBookings();
      final ids = <String>[];
      for (final status in ['pending', 'confirmed', 'cancelled']) {
        final list = bookings[status] ?? const [];
        for (final item in list) {
          ids.add(item.id);
        }
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  Future<int> _getActivitiesCount() async {
    final ids = await _getActivitiesIds();
    final prefs = await SharedPreferences.getInstance();
    final userId = (await AuthService.getUserId() ?? '').trim();
    final scope = userId.isEmpty ? 'guest' : userId;
    final key = 'novelty_seen_${scope}_activities_all_seen_ids';
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
    final key = 'novelty_seen_${scope}_network_all_seen_ids';
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
        _getHomeCount(),
        _getActivitiesCount(),
        _getNetworkCount(),
        _getMessagesCount(),
      ]);
      if (!mounted) return;

      setState(() {
        _homeCount = _currentIndex == 0 ? 0 : results[0];
        _activitiesCount = _currentIndex == 1 ? 0 : results[1];
        _networkCount = _currentIndex == 5 ? 0 : results[2];
        _messagesCount = _currentIndex == 3 ? 0 : results[3];

        // Keep Home hero message icon in sync by rebuilding first page instance.
        _pages[0] = HomeTab(
          onExploreTap: () => _goToTab(2),
          onMessagesTap: () => _goToTab(3),
          onActivitiesTap: () => _goToTab(1),
          onNotificationsTap: () => _goToTab(4),
          onProfileTap: () => _goToTab(6),
          showMessagesDot: _messagesCount > 0,
        );
      });
    } catch (_) {
      // Best-effort badges: ignore network/service failures.
    }
  }

  void _markSeenForTab(int index) async {
    if (index == 0) {
      final ids = await _getHomeIds();
      final prefs = await SharedPreferences.getInstance();
      final userId = (await AuthService.getUserId() ?? '').trim();
      final scope = userId.isEmpty ? 'guest' : userId;
      final key = 'novelty_seen_${scope}_home_all_seen_ids';
      final seenIds = prefs.getStringList(key) ?? [];
      final newSet = {...seenIds, ...ids}.toList();
      await prefs.setStringList(key, newSet);
      setState(() => _homeCount = 0);
    }
    if (index == 1) {
      final ids = await _getActivitiesIds();
      final prefs = await SharedPreferences.getInstance();
      final userId = (await AuthService.getUserId() ?? '').trim();
      final scope = userId.isEmpty ? 'guest' : userId;
      final key = 'novelty_seen_${scope}_activities_all_seen_ids';
      final seenIds = prefs.getStringList(key) ?? [];
      final newSet = {...seenIds, ...ids}.toList();
      await prefs.setStringList(key, newSet);
      setState(() => _activitiesCount = 0);
    }
    if (index == 5) {
      final ids = await _getNetworkIds();
      final prefs = await SharedPreferences.getInstance();
      final userId = (await AuthService.getUserId() ?? '').trim();
      final scope = userId.isEmpty ? 'guest' : userId;
      final key = 'novelty_seen_${scope}_network_all_seen_ids';
      final seenIds = prefs.getStringList(key) ?? [];
      final newSet = {...seenIds, ...ids}.toList();
      await prefs.setStringList(key, newSet);
      setState(() => _networkCount = 0);
    }
  }

  void _goToTab(int index) {
    if (!mounted) return;
    _markSeenForTab(index);
    setState(() {
      _currentIndex = index;
      if (index == 0) _homeCount = 0;
      if (index == 1) _activitiesCount = 0;
      if (index == 5) _networkCount = 0;
      if (index == 3) _messagesCount = 0;

      _pages[0] = HomeTab(
        onExploreTap: () => _goToTab(2),
        onMessagesTap: () => _goToTab(3),
        onActivitiesTap: () => _goToTab(1),
        onNotificationsTap: () => _goToTab(4),
        onProfileTap: () => _goToTab(6),
        showMessagesDot: _messagesCount > 0,
      );
      _isNavbarVisible = true; // Show navbar when switching tabs
    });
    _refreshNoveltyBadges();
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const navBg = Color(0xFFE9ECFB);
    const navActive = AppColors.primary;
    const navInactive = Color(0xFF7B82A8);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isNavbarVisible ? 18 : -100,
            left: 16,
            right: 16,
            child: _buildFloatingNavBar(navBg, navActive, navInactive),
          ),
        ],
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
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _homeCount,
              ),
              _NavItem(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note,
                label: 'Activities',
                index: 1,
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
                index: 2,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Messages',
                index: 3,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _messagesCount,
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
                icon: Icons.public,
                activeIcon: Icons.public,
                label: 'Network',
                index: 5,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                badgeCount: _networkCount,
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
