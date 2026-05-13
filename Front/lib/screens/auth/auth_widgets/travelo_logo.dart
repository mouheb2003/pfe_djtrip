import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DJTripLogo extends StatelessWidget {
  final double size;

  const DJTripLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/logos/app_logo.png',
        height: size,
        width: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
