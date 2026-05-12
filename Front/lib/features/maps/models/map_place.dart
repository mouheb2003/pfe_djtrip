import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPlace {
  const MapPlace({
    required this.placeId,
    required this.name,
    required this.position,
    this.address,
    this.rating,
    this.primaryType,
    this.photoUrl,
  });

  final String placeId;
  final String name;
  final LatLng position;
  final String? address;
  final double? rating;
  final String? primaryType;
  final String? photoUrl;
}
