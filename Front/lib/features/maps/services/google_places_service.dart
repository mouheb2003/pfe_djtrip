import 'dart:async';
import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/map_place.dart';
import '../models/map_place_suggestion.dart';

class PlacesApiException implements Exception {
  const PlacesApiException(this.message);

  final String message;

  @override
  String toString() => 'PlacesApiException: $message';
}

class GooglePlacesService {
  GooglePlacesService({http.Client? client, String? apiKey})
    : _client = client,
      _apiKey = apiKey ?? 'AIzaSyAKG3yUqz3-9kEdXdKdEMuTxIGN9XypUwE';

  final http.Client? _client;
  final String _apiKey;

  static const String _host = 'places.googleapis.com';
  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<List<MapPlaceSuggestion>> fetchAutocompleteSuggestions({
    required String query,
    required String sessionToken,
    required double latitude,
    required double longitude,
    String languageCode = 'fr',
    double radiusMeters = 40000,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return const [];
    }

    _ensureApiKey();

    // Places API v1 autocomplete endpoint.
    final uri = Uri.https(_host, '/v1/places:autocomplete');
    final body = <String, dynamic>{
      'input': trimmedQuery,
      'sessionToken': sessionToken,
      'languageCode': languageCode,
      'locationBias': {
        'circle': {
          'center': {'latitude': latitude, 'longitude': longitude},
          'radius': radiusMeters,
        },
      },
      'includedRegionCodes': ['tn'],
    };

    final response = await _sendPost(uri: uri, body: body, fieldMask: '*');
    final decoded = _decodeAsMap(response.body);

    final suggestionsRaw = decoded['suggestions'];
    if (suggestionsRaw is! List) {
      return const [];
    }

    final suggestions = <MapPlaceSuggestion>[];
    final seenPlaceIds = <String>{};

    for (final item in suggestionsRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final prediction = item['placePrediction'];
      if (prediction is! Map<String, dynamic>) {
        continue;
      }

      final rawPlaceId = (prediction['placeId'] ?? prediction['place'] ?? '')
          .toString();
      final placeId = _normalizePlaceId(rawPlaceId);
      if (placeId.isEmpty || seenPlaceIds.contains(placeId)) {
        continue;
      }

      final structured = prediction['structuredFormat'];
      String primaryText = '';
      String secondaryText = '';

      if (structured is Map<String, dynamic>) {
        primaryText = ((structured['mainText'] as Map?)?['text'] ?? '')
            .toString()
            .trim();
        secondaryText = ((structured['secondaryText'] as Map?)?['text'] ?? '')
            .toString()
            .trim();
      }

      if (primaryText.isEmpty) {
        primaryText = ((prediction['text'] as Map?)?['text'] ?? '')
            .toString()
            .trim();
      }

      if (primaryText.isEmpty) {
        continue;
      }

      seenPlaceIds.add(placeId);
      suggestions.add(
        MapPlaceSuggestion(
          placeId: placeId,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
      );
    }

    return suggestions;
  }

  Future<MapPlace> fetchPlaceDetails({
    required String placeId,
    String languageCode = 'fr',
  }) async {
    _ensureApiKey();

    final normalizedId = _normalizePlaceId(placeId);
    if (normalizedId.isEmpty) {
      throw const PlacesApiException('Invalid place id.');
    }

    final encodedId = Uri.encodeComponent(normalizedId);
    final uri = Uri.https(_host, '/v1/places/$encodedId', {
      'languageCode': languageCode,
    });

    // Places API v1 details endpoint.
    final response = await _sendGet(
      uri: uri,
      fieldMask: 'id,displayName,location,rating,formattedAddress,primaryType',
    );

    final decoded = _decodeAsMap(response.body);
    return _parsePlace(decoded);
  }

  Future<List<MapPlace>> fetchNearbyPlaces({
    required double latitude,
    required double longitude,
    List<String> includedTypes = const ['restaurant', 'hotel', 'beach'],
    double radiusMeters = 5000,
    int maxResultCount = 30,
    String languageCode = 'fr',
  }) async {
    _ensureApiKey();

    final uri = Uri.https(_host, '/v1/places:searchNearby');
    final body = <String, dynamic>{
      'includedTypes': includedTypes,
      'maxResultCount': maxResultCount,
      'languageCode': languageCode,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': latitude, 'longitude': longitude},
          'radius': radiusMeters,
        },
      },
    };

    // Places API v1 nearby search endpoint.
    final response = await _sendPost(
      uri: uri,
      body: body,
      fieldMask:
          'places.id,places.displayName,places.location,places.rating,places.formattedAddress,places.primaryType',
    );

    final decoded = _decodeAsMap(response.body);
    final placesRaw = decoded['places'];
    if (placesRaw is! List) {
      return const [];
    }

    final places = <MapPlace>[];
    final seenPlaceIds = <String>{};

    for (final item in placesRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final place = _parsePlace(item);
      if (seenPlaceIds.add(place.placeId)) {
        places.add(place);
      }
    }

    return places;
  }

  Future<http.Response> _sendPost({
    required Uri uri,
    required Map<String, dynamic> body,
    required String fieldMask,
  }) async {
    final client = _client ?? http.Client();

    try {
      final response = await client
          .post(uri, headers: _headers(fieldMask), body: jsonEncode(body))
          .timeout(_requestTimeout);

      _throwIfFailed(response);
      return response;
    } on TimeoutException {
      throw const PlacesApiException('Places API request timed out.');
    } on http.ClientException {
      throw const PlacesApiException(
        'Network error while contacting Places API.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<http.Response> _sendGet({
    required Uri uri,
    required String fieldMask,
  }) async {
    final client = _client ?? http.Client();

    try {
      final response = await client
          .get(uri, headers: _headers(fieldMask))
          .timeout(_requestTimeout);

      _throwIfFailed(response);
      return response;
    } on TimeoutException {
      throw const PlacesApiException('Places API request timed out.');
    } on http.ClientException {
      throw const PlacesApiException(
        'Network error while contacting Places API.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, String> _headers(String fieldMask) {
    return <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': fieldMask,
    };
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message =
        'Places API request failed with status ${response.statusCode}.';

    final decoded = _tryDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final apiMessage = (error['message'] ?? '').toString().trim();
        if (apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      }
    }

    throw PlacesApiException(message);
  }

  Map<String, dynamic> _decodeAsMap(String raw) {
    final decoded = _tryDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const PlacesApiException('Unexpected Places API response format.');
  }

  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  MapPlace _parsePlace(Map<String, dynamic> data) {
    final id = _normalizePlaceId((data['id'] ?? '').toString());
    final displayName = data['displayName'];
    final location = data['location'];

    if (id.isEmpty ||
        displayName is! Map<String, dynamic> ||
        location is! Map<String, dynamic>) {
      throw const PlacesApiException(
        'Incomplete place data received from API.',
      );
    }

    final name = (displayName['text'] ?? '').toString().trim();
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();

    if (name.isEmpty || lat == null || lng == null) {
      throw const PlacesApiException(
        'Invalid place details received from API.',
      );
    }

    return MapPlace(
      placeId: id,
      name: name,
      position: LatLng(lat, lng),
      address: (data['formattedAddress'] ?? '').toString().trim(),
      rating: (data['rating'] as num?)?.toDouble(),
      primaryType: (data['primaryType'] ?? '').toString().trim(),
    );
  }

  String _normalizePlaceId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('places/')) {
      return trimmed.substring('places/'.length);
    }
    return trimmed;
  }

  void _ensureApiKey() {
    if (_apiKey.trim().isEmpty) {
      throw const PlacesApiException(
        'Google Maps API key is missing. Run with --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY.',
      );
    }
  }
}
