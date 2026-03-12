import 'package:flutter/material.dart';
import '../models/message.dart' as msg_model;
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'conversations_screen.dart';
import 'organizer/my_activities_screen.dart';
import 'organizer/archive_screen.dart';
import 'booking_requests_screen.dart';
import 'organisator_profile_screen.dart';

class OrganizerMainScreen extends StatefulWidget {
  final User user;

  const OrganizerMainScreen({super.key, required this.user});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  int _currentIndex = 0;
  late User _currentUser;
  int _unreadCount = 0;
  int _messagesRefreshTrigger = 0;

  static const int _messagesTabIndex = 3;

  List<Widget> get _screens => [
    MyActivitiesScreen(user: _currentUser, onUserDataChanged: _refreshUserData),
    ArchiveScreen(user: _currentUser, onUserDataChanged: _refreshUserData),
    const BookingRequestsScreen(),
    ConversationsScreen(
      refreshTrigger: _messagesRefreshTrigger,
      userType: 'organisateur',
    ),
    OrganisatorProfileScreen(user: _currentUser),
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    MessageService.connect();
    MessageService.onMessage(_onIncomingMessage);
    _loadUnreadCount();
  }

  @override
  void dispose() {
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

  void _onIncomingMessage(msg_model.Message msg) {
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
      if (result['success'] == true && result['user'] != null) {
        setState(() {
          _currentUser = result['user'];
        });
      }
    } catch (e) {
      // Silently fail - user data will remain unchanged
      print('Error refreshing user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == _messagesTabIndex) {
                _unreadCount = 0;
                _messagesRefreshTrigger++;
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2D5016),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 13,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.event_note),
              activeIcon: Icon(Icons.event_note, size: 28),
              label: 'My Activities',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.archive),
              activeIcon: Icon(Icons.archive, size: 28),
              label: 'Archive',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today, size: 28),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              activeIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                child: const Icon(Icons.chat_bubble, size: 28),
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              activeIcon: Icon(Icons.person, size: 28),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
