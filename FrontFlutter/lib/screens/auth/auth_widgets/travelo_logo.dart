import 'package:flutter/material.dart';

class DJTripLogo extends StatelessWidget {
  final double size;

  const DJTripLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFB84D), Color(0xFFFF6B1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
