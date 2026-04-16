import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../config/app_routes.dart';
import 'tabs/my_activities_tab.dart';
import 'tabs/archive_tab.dart';
import 'tabs/organizer_profile_tab.dart';
import '../tourist/tabs/screen_network.dart';
import '../shared/messages_screen.dart';
import '../notifications_screen.dart';
import '../../services/activity_service.dart';
import '../../services/inscription_service.dart';
import '../../services/message_service.dart';
import '../../services/post_service.dart';
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
  static const String _sectionRequests = 'organizer_requests';
  static const String _sectionNetwork = 'organizer_network';
  static const String _sectionMessages = 'organizer_messages';

  late int _currentIndex;
  Timer? _noveltyTimer;

  bool _showActivitiesDot = false;
  bool _showRequestsDot = false;
  bool _showNetworkDot = false;
  bool _showMessagesDot = false;

  String _activitiesSignature = '';
  String _requestsSignature = '';
  String _networkSignature = '';
  String _messagesSignature = '';

  List<Widget> get _pages => [
    MyActivitiesTab(
      showRequestsDot: _showRequestsDot,
      onOpenRequests: _markRequestsSeen,
    ),
    const ArchiveTab(),
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

  Future<String> _buildRequestsSignature() async {
    final requests = await InscriptionService.getOrganizerPendingRequests();
    if (requests.isEmpty) return 'none';
    final items = requests.map((r) => r.id).where((e) => e.isNotEmpty).toList()
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
        _buildRequestsSignature(),
        _buildNetworkSignature(),
        _buildMessagesSignature(),
      ]);
      if (!mounted) return;

      _activitiesSignature = signatures[0];
      _requestsSignature = signatures[1];
      _networkSignature = signatures[2];
      _messagesSignature = signatures[3];

      final unseen = await Future.wait<bool>([
        NoveltyBadgeService.hasUnseen(_sectionActivities, _activitiesSignature),
        NoveltyBadgeService.hasUnseen(_sectionRequests, _requestsSignature),
        NoveltyBadgeService.hasUnseen(_sectionNetwork, _networkSignature),
        NoveltyBadgeService.hasUnseen(_sectionMessages, _messagesSignature),
      ]);
      if (!mounted) return;

      setState(() {
        _showActivitiesDot = _currentIndex != 0 && unseen[0];
        _showRequestsDot = unseen[1];
        _showNetworkDot = _currentIndex != 2 && unseen[2];
        _showMessagesDot = _currentIndex != 3 && unseen[3];
      });
    } catch (_) {
      // Best-effort badges: ignore service errors.
    }
  }

  void _markRequestsSeen() {
    if (_requestsSignature.isNotEmpty) {
      NoveltyBadgeService.markSeen(_sectionRequests, _requestsSignature);
    }
    if (mounted) {
      setState(() => _showRequestsDot = false);
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
    const navBg = Color(0xFFF2F1FA);
    const navActive = AppColors.primary;
    const navInactive = Color(0xFF7B82A8);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        color: const Color(0xFFF2F1FA),
        padding: const EdgeInsets.only(bottom: 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: 'Activities',
                      index: 0,
                      currentIndex: _currentIndex,
                      onTap: _goToTab,
                      activeColor: navActive,
                      inactiveColor: navInactive,
                      showDot: _showActivitiesDot || _showRequestsDot,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.inventory_2_outlined,
                      activeIcon: Icons.inventory_2,
                      label: 'Archive',
                      index: 1,
                      currentIndex: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i),
                      activeColor: navActive,
                      inactiveColor: navInactive,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _goToTab(2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _currentIndex == 2
                                      ? AppColors.primaryDark
                                      : AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.public,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              if (_showNetworkDot)
                                const Positioned(
                                  top: -2,
                                  right: -2,
                                  child: _RedDot(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Network',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _currentIndex == 2 ? AppColors.primary : navInactive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
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
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profile',
                      index: 4,
                      currentIndex: _currentIndex,
                      onTap: (i) => setState(() => _currentIndex = i),
                      activeColor: navActive,
                      inactiveColor: navInactive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: 20,
                ),
                if (showDot)
                  const Positioned(top: -2, right: -5, child: _RedDot()),
              ],
            ),
            const SizedBox(height: 2),
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
