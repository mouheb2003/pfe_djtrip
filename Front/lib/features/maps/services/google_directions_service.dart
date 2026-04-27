import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsApiException implements Exception {
  const DirectionsApiException(this.message);

  final String message;

  @override
  String toString() => 'DirectionsApiException: $message';
}

class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });

  final List<LatLng> points;
  final String distanceText;
  final String durationText;
}

class GoogleDirectionsService {
  GoogleDirectionsService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? 'AIzaSyAKG3yUqz3-9kEdXdKdEMuTxIGN9XypUwE';

  final http.Client _client;
  final String _apiKey;

  static const Duration _timeout = Duration(seconds: 12);

  Future<DirectionsRoute> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    String language = 'fr',
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw const DirectionsApiException('Google Maps API key is missing.');
    }

    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'language': language,
      'key': _apiKey,
    });

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DirectionsApiException(
        'Directions API request failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const DirectionsApiException('Unexpected Directions API response.');
    }

    final status = (decoded['status'] ?? '').toString();
    if (status != 'OK') {
      final errorMessage = (decoded['error_message'] ?? '').toString().trim();
      throw DirectionsApiException(
        errorMessage.isNotEmpty
            ? errorMessage
            : 'Directions API returned status $status.',
      );
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const DirectionsApiException('No route found.');
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      throw const DirectionsApiException('Invalid route data received.');
    }

    final overviewPolyline = firstRoute['overview_polyline'];
    final encodedPoints = overviewPolyline is Map<String, dynamic>
        ? (overviewPolyline['points'] ?? '').toString()
        : '';

    final legs = firstRoute['legs'];
    String distanceText = '';
    String durationText = '';

    if (legs is List && legs.isNotEmpty && legs.first is Map<String, dynamic>) {
      final leg = legs.first as Map<String, dynamic>;
      final distance = leg['distance'];
      final duration = leg['duration'];
      if (distance is Map<String, dynamic>) {
        distanceText = (distance['text'] ?? '').toString();
      }
      if (duration is Map<String, dynamic>) {
        durationText = (duration['text'] ?? '').toString();
      }
    }

    return DirectionsRoute(
      points: encodedPoints.isEmpty ? const [] : _decodePolyline(encodedPoints),
      distanceText: distanceText,
      durationText: durationText,
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final polylinePoints = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylinePoints;
  }
}
