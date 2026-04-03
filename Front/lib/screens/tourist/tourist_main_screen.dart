import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'my_activities_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/explore_tab.dart';
import 'tabs/screen_network.dart';
import 'tabs/tourist_profile_tab.dart';
import '../shared/messages_screen.dart';

class TouristMainScreen extends StatefulWidget {
  final int initialIndex;
  const TouristMainScreen({super.key, this.initialIndex = 0});

  @override
  State<TouristMainScreen> createState() => _TouristMainScreenState();
}

class _TouristMainScreenState extends State<TouristMainScreen> {
  late int _currentIndex;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      HomeTab(
        onExploreTap: () => _goToTab(1),
        onMessagesTap: () => _goToTab(5),
      ),
      const ExploreTab(),
      const MyActivitiesScreen(),
      const ScreenNetwork(),
      TouristProfileTab(onNavigateToTab: _goToTab),
      const MessagesScreen(),
    ];
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const navBg = Color(0xFFE9ECFB);
    const navActive = AppColors.primary;
    const navInactive = Color(0xFF7B82A8);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 14,
                right: 14,
                bottom: 8,
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: navBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: 'Home',
                          index: 0,
                          currentIndex: _currentIndex,
                          onTap: _goToTab,
                          activeColor: navActive,
                          inactiveColor: navInactive,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.explore_outlined,
                          activeIcon: Icons.explore,
                          label: 'Explore',
                          index: 1,
                          currentIndex: _currentIndex,
                          onTap: _goToTab,
                          activeColor: navActive,
                          inactiveColor: navInactive,
                        ),
                      ),
                      const SizedBox(width: 56),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.event_note_outlined,
                          activeIcon: Icons.event_note,
                          label: 'Activities',
                          index: 2,
                          currentIndex: _currentIndex,
                          onTap: _goToTab,
                          activeColor: navActive,
                          inactiveColor: navInactive,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: 'Profile',
                          index: 4,
                          currentIndex: _currentIndex,
                          onTap: _goToTab,
                          activeColor: navActive,
                          inactiveColor: navInactive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -8,
                child: GestureDetector(
                  onTap: () => _goToTab(3),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: navBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _currentIndex == 3
                              ? AppColors.primaryDark
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.public,
                          color: cs.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 57,
                child: Text(
                  'Network',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _currentIndex == 3 ? AppColors.primary : navInactive,
                  ),
                ),
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
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
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 20,
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
