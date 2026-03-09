import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
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

  List<Widget> get _screens => [
    MyActivitiesScreen(user: _currentUser, onUserDataChanged: _refreshUserData),
    ArchiveScreen(user: _currentUser, onUserDataChanged: _refreshUserData),
    const BookingRequestsScreen(),
    OrganisatorProfileScreen(user: _currentUser),
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note),
              activeIcon: Icon(Icons.event_note, size: 28),
              label: 'My Activities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.archive),
              activeIcon: Icon(Icons.archive, size: 28),
              label: 'Archive',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today, size: 28),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
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
