import 'package:flutter/material.dart';
import 'place_detail_screen_v2.dart';

class PlaceDetailScreen extends StatelessWidget {
  final dynamic place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return PlaceDetailScreenV2(place: place);
  }
}
