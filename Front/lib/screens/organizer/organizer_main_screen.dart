import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'tabs/my_activities_tab.dart';
import 'tabs/archive_tab.dart';
import 'tabs/organizer_profile_tab.dart';
import '../tourist/tabs/screen_network.dart';
import '../shared/messages_screen.dart';

class OrganizerMainScreen extends StatefulWidget {
  const OrganizerMainScreen({super.key});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  int _currentIndex = 0;

  final _pages = const [
    MyActivitiesTab(),
    ArchiveTab(),
    ScreenNetwork(),
    MessagesScreen(),
    OrganizerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
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
                          icon: Icons.calendar_today_outlined,
                          activeIcon: Icons.calendar_today,
                          label: 'Activities',
                          index: 0,
                          currentIndex: _currentIndex,
                          onTap: (i) => setState(() => _currentIndex = i),
                          activeColor: navActive,
                          inactiveColor: navInactive,
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
                      const SizedBox(width: 56),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          label: 'Messages',
                          index: 3,
                          currentIndex: _currentIndex,
                          onTap: (i) => setState(() => _currentIndex = i),
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
                          onTap: (i) => setState(() => _currentIndex = i),
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
                  onTap: () => setState(() => _currentIndex = 2),
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
                          color: _currentIndex == 2
                              ? AppColors.primaryDark
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hub,
                          color: Colors.white,
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
                    color: _currentIndex == 2 ? AppColors.primary : navInactive,
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
