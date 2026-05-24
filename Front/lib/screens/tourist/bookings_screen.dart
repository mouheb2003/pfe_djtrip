import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'tabs/bookings_tab.dart';
import 'tourist_main_screen.dart';

class BookingsScreen extends StatelessWidget {
  final int initialTabIndex;

  const BookingsScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F3FE),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F3FE),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF1F235F)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TouristMainScreen()),
                (route) => false,
              );
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR JOURNEY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.primary,
              ),
            ),
            Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1F235F),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(child: BookingsTab(initialTabIndex: initialTabIndex)),
    );
  }
}
