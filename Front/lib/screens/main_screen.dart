import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'home_tab_screen.dart';
import 'explore_tab_screen.dart';
import 'activities_tab_screen.dart';
import 'tourist_bookings_screen.dart';
import 'booking_requests_screen.dart';
import 'profile_screen.dart';
import 'organisator_profile_screen.dart';

class MainScreen extends StatefulWidget {
  final User user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late User _currentUser;
  Timer? _autoRefreshTimer;

  // Screens are built as a getter so they always use the latest _currentUser.
  // Flutter's reconciler reuses the existing State when the widget type matches,
  // so switching tabs never loses scroll position or local state.
  List<Widget> get _screens => _currentUser.userType == 'Organisator'
      ? [
          HomeTabScreen(user: _currentUser),
          ExploreTabScreen(),
          ActivitiesTabScreen(user: _currentUser),
          BookingRequestsScreen(),
          OrganisatorProfileScreen(user: _currentUser),
        ]
      : [
          HomeTabScreen(user: _currentUser),
          ExploreTabScreen(),
          ActivitiesTabScreen(user: _currentUser),
          TouristBookingsScreen(user: _currentUser),
          ProfileScreen(user: _currentUser),
        ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    // Refresh user data every 30 seconds automatically
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshUserData(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserData() async {
    try {
      final result = await AuthService.getMyInfo();
      if (result['success'] == true && result['user'] != null && mounted) {
        setState(() {
          _currentUser = result['user'];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isOrganisator = widget.user.userType == 'Organisator';

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Refresh data on every tab switch so values are always up-to-date
            _refreshUserData();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFFF6B1A),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: isOrganisator
              ? [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.event_outlined),
                    activeIcon: Icon(Icons.event),
                    label: 'Activities',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_outlined),
                    activeIcon: Icon(Icons.calendar_today),
                    label: 'Bookings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ]
              : [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.event_outlined),
                    activeIcon: Icon(Icons.event),
                    label: 'Activities',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark_outlined),
                    activeIcon: Icon(Icons.bookmark),
                    label: 'Bookings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
        ),
      ),
    );
  }
}
