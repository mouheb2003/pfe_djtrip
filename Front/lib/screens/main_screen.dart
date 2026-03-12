import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart' as message_dart;
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'home_tab_screen.dart';
import 'explore_tab_screen.dart';
import 'activities_tab_screen.dart';
import 'conversations_screen.dart';
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
  int _unreadCount = 0;
  int _messagesRefreshTrigger = 0;

  static const int _messagesTabIndex = 4;

  // Screens are built as a getter so they always use the latest _currentUser.
  // Flutter's reconciler reuses the existing State when the widget type matches,
  // so switching tabs never loses scroll position or local state.
  List<Widget> get _screens => _currentUser.userType == 'Organisator'
      ? [
          HomeTabScreen(user: _currentUser),
          ExploreTabScreen(),
          ActivitiesTabScreen(user: _currentUser),
          BookingRequestsScreen(),
          ConversationsScreen(refreshTrigger: _messagesRefreshTrigger),
          OrganisatorProfileScreen(user: _currentUser),
        ]
      : [
          HomeTabScreen(user: _currentUser),
          ExploreTabScreen(),
          ActivitiesTabScreen(user: _currentUser),
          TouristBookingsScreen(user: _currentUser),
          ConversationsScreen(refreshTrigger: _messagesRefreshTrigger),
          ProfileScreen(user: _currentUser),
        ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    MessageService.connect();
    MessageService.onMessage(_onIncomingMessage);
    _loadUnreadCount();
    // Refresh user data every 30 seconds automatically
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshUserData(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    // Only unregister the notification callback here.
    // disconnect() is called exclusively by AuthService.logout() so it never
    // interrupts an active session when the shell widget is rebuilt.
    MessageService.offMessage(_onIncomingMessage);
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await MessageService.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _onIncomingMessage(message_dart.Message msg) {
    // Only count messages sent by the other party (not our own sent confirmation)
    if (msg.senderId == _currentUser.id) return;
    if (!mounted) return;
    if (_currentIndex != _messagesTabIndex) {
      setState(() => _unreadCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.chat_bubble, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('You have a new message'),
            ],
          ),
          backgroundColor: const Color(0xFF2D5016),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            textColor: const Color(0xFFFF6B1A),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _currentIndex = _messagesTabIndex;
                  _unreadCount = 0;
                  _messagesRefreshTrigger++;
                });
              }
            },
          ),
        ),
      );
    }
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == _messagesTabIndex) {
              _unreadCount = 0;
              _messagesRefreshTrigger++;
            }
          });
          _refreshUserData();
        },
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFFF6B1A).withOpacity(0.15),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        destinations: isOrganisator
            ? [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: Color(0xFFFF6B1A)),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore, color: Color(0xFFFF6B1A)),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event, color: Color(0xFFFF6B1A)),
                  label: 'Activities',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(
                    Icons.calendar_today,
                    color: Color(0xFFFF6B1A),
                  ),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: Color(0xFFFF6B1A),
                    ),
                  ),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: Color(0xFFFF6B1A)),
                  label: 'Profile',
                ),
              ]
            : [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: Color(0xFFFF6B1A)),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore, color: Color(0xFFFF6B1A)),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event, color: Color(0xFFFF6B1A)),
                  label: 'Activities',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outlined),
                  selectedIcon: Icon(Icons.bookmark, color: Color(0xFFFF6B1A)),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unreadCount > 0,
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: Color(0xFFFF6B1A),
                    ),
                  ),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: Color(0xFFFF6B1A)),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}
