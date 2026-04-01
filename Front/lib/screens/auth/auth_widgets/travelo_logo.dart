import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DJTripLogo extends StatelessWidget {
  final double size;

  const DJTripLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'DJTrip',
        style: TextStyle(
          fontSize: size * 0.25,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
