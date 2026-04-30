import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/lieu_model.dart';

enum PlaceNameSource { placesApi, geocodingApi, localDatabase, coordinates }

enum PlaceNameErrorType {
  apiNotConfigured,
  apiNotEnabled,
  invalidApiKey,
  quotaExceeded,
  requestDenied,
  network,
  unexpected,
}

class PlaceNameError {
  final PlaceNameErrorType type;
  final String message;

  const PlaceNameError({required this.type, required this.message});
}

class PlaceNameResolution {
  final String displayName;
  final PlaceNameSource source;
  final PlaceNameError? error;

  const PlaceNameResolution({
    required this.displayName,
    required this.source,
    this.error,
  });
}

class PlaceNameResolverService {
  PlaceNameResolverService({http.Client? client, String? googleApiKey})
    : _client = client ?? http.Client(),
      _googleApiKey =
          (googleApiKey ??
                  const String.fromEnvironment(
                    'GOOGLE_MAPS_API_KEY',
                    defaultValue: 'AIzaSyAKG3yUqz3-9kEdXdKdEMuTxIGN9XypUwE',
                  ))
              .trim();

  final http.Client _client;
  final String _googleApiKey;

  static const Duration _timeout = Duration(seconds: 8);
  static const double _localFallbackMaxMeters = 450;

  Future<PlaceNameResolution> resolvePlaceName({
    required double latitude,
    required double longitude,
    List<LieuModel> localFallback = const <LieuModel>[],
    String language = 'fr',
  }) async {
    final lat = latitude;
    final lng = longitude;
    PlaceNameError? collectedError;

    if (_googleApiKey.isEmpty) {
      final local = _nearestLocalPlace(lat, lng, localFallback);
      if (local != null) {
        return PlaceNameResolution(
          displayName: local.titre.trim(),
          source: PlaceNameSource.localDatabase,
          error: const PlaceNameError(
            type: PlaceNameErrorType.apiNotConfigured,
            message:
                'Google API key is not configured. Add --dart-define=GOOGLE_MAPS_API_KEY=... at run/build time.',
          ),
        );
      }

      return PlaceNameResolution(
        displayName: _formatCoordinates(lat, lng),
        source: PlaceNameSource.coordinates,
        error: const PlaceNameError(
          type: PlaceNameErrorType.apiNotConfigured,
          message:
              'Google API key is not configured. Add --dart-define=GOOGLE_MAPS_API_KEY=... at run/build time.',
        ),
      );
    }

    final nearbyResult = await _resolveWithNearbySearch(
      latitude: lat,
      longitude: lng,
      language: language,
    );
    if (nearbyResult != null && nearbyResult.displayName.trim().isNotEmpty) {
      return nearbyResult;
    }
    collectedError ??= nearbyResult?.error;

    final geocodeResult = await _resolveWithGeocoding(
      latitude: lat,
      longitude: lng,
      language: language,
    );
    if (geocodeResult != null && geocodeResult.displayName.trim().isNotEmpty) {
      return geocodeResult;
    }
    collectedError ??= geocodeResult?.error;

    final local = _nearestLocalPlace(lat, lng, localFallback);
    if (local != null) {
      return PlaceNameResolution(
        displayName: local.titre.trim(),
        source: PlaceNameSource.localDatabase,
        error: collectedError,
      );
    }

    return PlaceNameResolution(
      displayName: _formatCoordinates(lat, lng),
      source: PlaceNameSource.coordinates,
      error: collectedError,
    );
  }

  Future<PlaceNameResolution?> _resolveWithNearbySearch({
    required double latitude,
    required double longitude,
    required String language,
  }) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude'
      '&radius=120'
      '&language=$language'
      '&key=$_googleApiKey',
    );

    final response = await _safeGet(uri);
    if (response == null) {
      return const PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.placesApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.network,
          message: 'Network error while requesting Places API.',
        ),
      );
    }

    if (response.statusCode != 200) {
      return PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.placesApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.unexpected,
          message: 'Places API HTTP ${response.statusCode}.',
        ),
      );
    }

    final decoded = _safeDecodeMap(response.body);
    if (decoded == null) {
      return const PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.placesApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.unexpected,
          message: 'Invalid Places API response format.',
        ),
      );
    }

    final status = (decoded['status'] ?? '').toString();
    if (status != 'OK') {
      return PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.placesApi,
        error: _mapGoogleStatusError(
          status: status,
          errorMessage: (decoded['error_message'] ?? '').toString(),
          endpointLabel: 'Places API',
        ),
      );
    }

    final results = decoded['results'];
    if (results is! List) return null;

    final bestName = _extractBestPlacesName(results);
    if (bestName == null) return null;

    return PlaceNameResolution(
      displayName: bestName,
      source: PlaceNameSource.placesApi,
    );
  }

  Future<PlaceNameResolution?> _resolveWithGeocoding({
    required double latitude,
    required double longitude,
    required String language,
  }) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$latitude,$longitude'
      '&language=$language'
      '&key=$_googleApiKey',
    );

    final response = await _safeGet(uri);
    if (response == null) {
      return const PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.geocodingApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.network,
          message: 'Network error while requesting Geocoding API.',
        ),
      );
    }

    if (response.statusCode != 200) {
      return PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.geocodingApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.unexpected,
          message: 'Geocoding API HTTP ${response.statusCode}.',
        ),
      );
    }

    final decoded = _safeDecodeMap(response.body);
    if (decoded == null) {
      return const PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.geocodingApi,
        error: PlaceNameError(
          type: PlaceNameErrorType.unexpected,
          message: 'Invalid Geocoding API response format.',
        ),
      );
    }

    final status = (decoded['status'] ?? '').toString();
    if (status != 'OK') {
      return PlaceNameResolution(
        displayName: '',
        source: PlaceNameSource.geocodingApi,
        error: _mapGoogleStatusError(
          status: status,
          errorMessage: (decoded['error_message'] ?? '').toString(),
          endpointLabel: 'Geocoding API',
        ),
      );
    }

    final results = decoded['results'];
    if (results is! List) return null;

    final bestName = _extractBestGeocodeName(results);
    if (bestName == null) return null;

    return PlaceNameResolution(
      displayName: bestName,
      source: PlaceNameSource.geocodingApi,
    );
  }

  Future<http.Response?> _safeGet(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _safeDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  PlaceNameError _mapGoogleStatusError({
    required String status,
    required String errorMessage,
    required String endpointLabel,
  }) {
    if (status == 'REQUEST_DENIED') {
      final lower = errorMessage.toLowerCase();
      if (lower.contains('api key')) {
        return PlaceNameError(
          type: PlaceNameErrorType.invalidApiKey,
          message: '$endpointLabel denied: invalid API key.',
        );
      }
      if (lower.contains('not enabled')) {
        return PlaceNameError(
          type: PlaceNameErrorType.apiNotEnabled,
          message: '$endpointLabel denied: API is not enabled in Google Cloud.',
        );
      }
      return PlaceNameError(
        type: PlaceNameErrorType.requestDenied,
        message: '$endpointLabel denied: ${errorMessage.trim()}',
      );
    }

    if (status == 'OVER_QUERY_LIMIT') {
      return PlaceNameError(
        type: PlaceNameErrorType.quotaExceeded,
        message: '$endpointLabel quota exceeded.',
      );
    }

    if (status == 'ZERO_RESULTS') {
      return PlaceNameError(
        type: PlaceNameErrorType.unexpected,
        message: '$endpointLabel returned zero results.',
      );
    }

    return PlaceNameError(
      type: PlaceNameErrorType.unexpected,
      message: '$endpointLabel failed: $status ${errorMessage.trim()}'.trim(),
    );
  }

  String? _extractBestPlacesName(List results) {
    final candidates = <String>[];
    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      final rawName = (item['name'] ?? '').toString().trim();
      final vicinity = (item['vicinity'] ?? '').toString().trim();

      final name = _cleanName(rawName);
      if (name.isEmpty || _isUnusableName(name)) continue;

      if (vicinity.isNotEmpty && !_isUnusableName(vicinity)) {
        candidates.add('$name, $vicinity');
      } else {
        candidates.add(name);
      }
    }

    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  String? _extractBestGeocodeName(List results) {
    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;

      final rawFormatted = (item['formatted_address'] ?? '').toString().trim();
      final formatted = _cleanName(rawFormatted);
      if (formatted.isNotEmpty && !_isUnusableName(formatted)) {
        return formatted;
      }

      final components = item['address_components'];
      if (components is List) {
        for (final c in components) {
          if (c is! Map<String, dynamic>) continue;
          final longName = _cleanName((c['long_name'] ?? '').toString());
          if (longName.isNotEmpty && !_isUnusableName(longName)) {
            return longName;
          }
        }
      }
    }
    return null;
  }

  String _cleanName(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isUnusableName(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    if (text.contains('+')) return true;

    final onlyCoordinates = RegExp(r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$');
    return onlyCoordinates.hasMatch(text);
  }

  LieuModel? _nearestLocalPlace(
    double latitude,
    double longitude,
    List<LieuModel> localPlaces,
  ) {
    LieuModel? nearest;
    var nearestDistance = double.infinity;

    for (final place in localPlaces) {
      final lat = place.latitude;
      final lng = place.longitude;
      if (lat == null || lng == null) continue;

      final d = _distanceMeters(latitude, longitude, lat, lng);
      if (d < nearestDistance) {
        nearest = place;
        nearestDistance = d;
      }
    }

    if (nearest != null && nearestDistance <= _localFallbackMaxMeters) {
      return nearest;
    }
    return null;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}
