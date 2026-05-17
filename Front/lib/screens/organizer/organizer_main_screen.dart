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
  static const String _sectionMessages = 'organizer_messages';

  late int _currentIndex;
  Timer? _noveltyTimer;

  bool _showActivitiesDot = false;
  bool _showNetworkDot = false;
  bool _showMessagesDot = false;

  String _activitiesSignature = '';
  String _networkSignature = '';
  String _messagesSignature = '';

  List<Widget> get _pages => [
    const MyActivitiesTab(),
    const ExploreActivitiesScreen(),
    const ScreenNetwork(),
    const MessagesScreen(),
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

  Future<String> _buildActivitiesSignature() async {
    final activities = await ActivityService.getMyActivities(refresh: true);
    if (activities.isEmpty) return 'none';

    final items =
        activities
            .map(
              (a) =>
                  '${a.id}:${a.nombreReservations}:${a.updatedAt?.millisecondsSinceEpoch ?? 0}',
            )
            .toList()
          ..sort();
    return 'count:${items.length}|${items.join(',')}';
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
        _buildActivitiesSignature(),
        _buildNetworkSignature(),
        _buildMessagesSignature(),
      ]);
      if (!mounted) return;

      _activitiesSignature = signatures[0];
      _networkSignature = signatures[1];
      _messagesSignature = signatures[2];

      final unseen = await Future.wait<bool>([
        NoveltyBadgeService.hasUnseen(_sectionActivities, _activitiesSignature),
        NoveltyBadgeService.hasUnseen(_sectionNetwork, _networkSignature),
        NoveltyBadgeService.hasUnseen(_sectionMessages, _messagesSignature),
      ]);
      if (!mounted) return;

      setState(() {
        _showActivitiesDot = _currentIndex != 0 && unseen[0];
        _showNetworkDot = _currentIndex != 2 && unseen[1];
        _showMessagesDot = _currentIndex != 3 && unseen[2];
      });
    } catch (_) {
      // Best-effort badges: ignore service errors.
    }
  }

  void _goToTab(int index) {
    if (index == 0 && _activitiesSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionActivities, _activitiesSignature);
    }
    if (index == 2 && _networkSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionNetwork, _networkSignature);
    }
    if (index == 3 && _messagesSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionMessages, _messagesSignature);
    }

    setState(() {
      _currentIndex = index;
      if (index == 0) _showActivitiesDot = false;
      if (index == 2) _showNetworkDot = false;
      if (index == 3) _showMessagesDot = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const navBg = Color(0xFFF2F1FA);
    const navActive = AppColors.primary;
    const navInactive = Color(0xFF7B82A8);

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
                showDot: _showActivitiesDot,
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
                index: 2,
                currentIndex: _currentIndex,
                onTap: _goToTab,
                activeColor: navActive,
                inactiveColor: navInactive,
                showDot: _showNetworkDot,
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
                showDot: _showMessagesDot,
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
