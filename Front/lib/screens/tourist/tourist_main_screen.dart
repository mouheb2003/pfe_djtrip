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
  String _homeSignature = '';
  String _activitiesSignature = '';
  String _networkSignature = '';
  String _messagesSignature = '';
  bool _showHomeDot = false;
  bool _showActivitiesDot = false;
  bool _showNetworkDot = false;
  bool _showMessagesDot = false;
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
        onExploreTap: () => _goToTab(1),
        onMessagesTap: () => _goToTab(5),
        onActivitiesTap: () => _goToTab(2),
        onNotificationsTap: () => _openNotifications(),
        showMessagesDot: _showMessagesDot,
      ),
      MapExplorerScreen(
        onToggleNavbar: (visible) {
          setState(() {
            _isNavbarVisible = visible;
          });
        },
      ),
      const MyActivitiesScreen(),
      const ScreenNetwork(),
      TouristProfileTab(onNavigateToTab: _goToTab),
      const MessagesScreen(),
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

  Future<String> _buildHomeSignature() async {
    final lieux = await LieuService.getLieux();
    final ids = lieux.map((e) => e.id).where((e) => e.isNotEmpty).toList()
      ..sort();
    if (ids.isEmpty) return 'none';
    return 'count:${ids.length}|first:${ids.first}|last:${ids.last}';
  }

  Future<String> _buildActivitiesSignature() async {
    final bookings = await InscriptionService.getMyBookings();
    final entries = <String>[];
    for (final status in ['pending', 'confirmed', 'cancelled']) {
      final list = bookings[status] ?? const [];
      for (final item in list) {
        entries.add('${item.id}:${item.statut}');
      }
    }
    entries.sort();
    if (entries.isEmpty) return 'none';
    return 'count:${entries.length}|${entries.join(',')}';
  }

  Future<String> _buildNetworkSignature() async {
    final posts = await PostService.getFeedPosts();
    if (posts.isEmpty) return 'none';

    posts.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    final first = posts.first;
    final latestId = (first['_id'] ?? first['id'] ?? '').toString();
    final latestTs = (first['createdAt'] ?? '').toString();
    return 'count:${posts.length}|id:$latestId|ts:$latestTs';
  }

  Future<String> _buildMessagesSignature() async {
    final conversations = await MessageService.getConversations();
    if (conversations.isEmpty) return 'none';

    final unread = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    conversations.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    final latest = conversations.first;
    final latestTs = latest.lastMessageTime?.millisecondsSinceEpoch ?? 0;
    return 'unread:$unread|latest:${latest.partnerId}:$latestTs';
  }

  Future<void> _refreshNoveltyBadges() async {
    try {
      final signatures = await Future.wait<String>([
        _buildHomeSignature(),
        _buildActivitiesSignature(),
        _buildNetworkSignature(),
        _buildMessagesSignature(),
      ]);
      if (!mounted) return;

      _homeSignature = signatures[0];
      _activitiesSignature = signatures[1];
      _networkSignature = signatures[2];
      _messagesSignature = signatures[3];

      final unseen = await Future.wait<bool>([
        NoveltyBadgeService.hasUnseen(_sectionHome, _homeSignature),
        NoveltyBadgeService.hasUnseen(_sectionActivities, _activitiesSignature),
        NoveltyBadgeService.hasUnseen(_sectionNetwork, _networkSignature),
        NoveltyBadgeService.hasUnseen(_sectionMessages, _messagesSignature),
      ]);
      if (!mounted) return;

      setState(() {
        _showHomeDot = _currentIndex != 0 && unseen[0];
        _showActivitiesDot = _currentIndex != 2 && unseen[1];
        _showNetworkDot = _currentIndex != 3 && unseen[2];
        _showMessagesDot = _currentIndex != 5 && unseen[3];

        // Keep Home hero message icon in sync by rebuilding first page instance.
        _pages[0] = HomeTab(
          onExploreTap: () => _goToTab(1),
          onMessagesTap: () => _goToTab(5),
          onActivitiesTap: () => _goToTab(2),
          onNotificationsTap: () => _openNotifications(),
          showMessagesDot: _showMessagesDot,
        );
      });
    } catch (_) {
      // Best-effort badges: ignore network/service failures.
    }
  }

  void _markSeenForTab(int index) {
    if (index == 0 && _homeSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionHome, _homeSignature);
    }
    if (index == 2 && _activitiesSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionActivities, _activitiesSignature);
    }
    if (index == 3 && _networkSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionNetwork, _networkSignature);
    }
    if (index == 5 && _messagesSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionMessages, _messagesSignature);
    }
  }

  void _goToTab(int index) {
    if (!mounted) return;
    _markSeenForTab(index);
    setState(() {
      _currentIndex = index;
      if (index == 0) _showHomeDot = false;
      if (index == 2) _showActivitiesDot = false;
      if (index == 3) _showNetworkDot = false;
      if (index == 5) _showMessagesDot = false;

      _pages[0] = HomeTab(
        onExploreTap: () => _goToTab(1),
        onMessagesTap: () => _goToTab(5),
        onActivitiesTap: () => _goToTab(2),
        onNotificationsTap: () => _openNotifications(),
        showMessagesDot: _showMessagesDot,
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
                showDot: _showHomeDot,
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
                icon: Icons.public,
                activeIcon: Icons.public,
                label: 'Network',
                index: 3,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                showDot: _showNetworkDot,
              ),
              _NavItem(
                icon: Icons.event_note_outlined,
                activeIcon: Icons.event_note,
                label: 'Activities',
                index: 2,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                showDot: _showActivitiesDot,
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
              ),
            ],
          ),
        ),
        // center handled as a normal _NavItem in the Row above
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
  final bool showDot;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.showDot = false,
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
                if (showDot)
                  const Positioned(top: -2, right: -5, child: _RedDot()),
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

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }
}
