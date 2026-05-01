import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/map_place.dart';
import '../models/map_place_suggestion.dart';
import '../services/google_directions_service.dart';
import '../services/google_places_service.dart';

// A small widget that attempts to fetch the image bytes via http
// and displays them with Image.memory. This helps when Image.network
// fails due to redirects or other issues with direct network image loading.
class NetworkImageWithFallback extends StatelessWidget {
  const NetworkImageWithFallback({Key? key, required this.url})
    : super(key: key);

  final String url;

  Future<Uint8List?> _fetchBytes(String u) async {
    try {
      final uri = Uri.parse(u);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      try {
        // ignore: avoid_print
        print(
          '[NetworkImageWithFallback] GET ${uri.toString()} -> ${resp.statusCode}',
        );
      } catch (_) {}
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _fetchBytes(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          );
        }
        return Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image)),
        );
      },
    );
  }
}

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  static const LatLng _djerbaCenter = LatLng(33.8076, 10.8451);

  final GooglePlacesService _placesService = GooglePlacesService();
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  GoogleMapController? _mapController;

  Timer? _debounce;
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  Timer? _cameraIdleDebounce;
  String _autocompleteSessionToken = '';

  LatLng _currentCenter = _djerbaCenter;
  LatLng? _currentLocation;
  MapPlace? _selectedPlace;
  List<MapPlaceSuggestion> _suggestions = const [];
  List<MapPlaceSuggestion> _originSuggestions = const [];
  List<MapPlaceSuggestion> _destinationSuggestions = const [];
  List<MapPlace> _nearbyPlaces = const [];
  List<LatLng> _routePoints = const [];
  String? _routeDistanceText;
  String? _routeDurationText;

  bool _isLoadingSuggestions = false;
  bool _isLoadingOriginSuggestions = false;
  bool _isLoadingDestinationSuggestions = false;
  bool _isLoadingPlaceDetails = false;
  bool _isLoadingNearby = false;
  bool _isLocatingUser = false;
  bool _isLoadingItinerary = false;
  bool _showManualItineraryPanel = false;

  LatLng? _manualOrigin;
  LatLng? _manualDestination;

  LatLng? _lastNearbyFetchCenter;
  static const List<String> _broadPlaceTypes = <String>[
    'restaurant',
    'cafe',
    'hotel',
    'lodging',
    'beach',
    'tourist_attraction',
    'museum',
    'park',
    'shopping_mall',
    'store',
    'mosque',
  ];
  late List<String> _selectedPlaceTypes;

  @override
  void initState() {
    super.initState();
    _selectedPlaceTypes = List<String>.from(_broadPlaceTypes);
    _autocompleteSessionToken = _createSessionToken();
    unawaited(_loadNearby(center: _djerbaCenter));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    _cameraIdleDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String _createSessionToken() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  void _updateSelectedTypes(String type) {
    setState(() {
      if (_selectedPlaceTypes.contains(type)) {
        _selectedPlaceTypes.remove(type);
      } else {
        _selectedPlaceTypes.add(type);
      }
    });
    unawaited(_loadNearby(center: _currentCenter));
  }

  void _resetTypeFilters() {
    setState(() {
      _selectedPlaceTypes = List<String>.from(_broadPlaceTypes);
    });
    unawaited(_loadNearby(center: _currentCenter));
  }

  Future<void> _onSearchChanged(String value) async {
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    // Debounce user typing to avoid calling autocomplete on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSuggestions = true;
      });

      try {
        final response = await _placesService.fetchAutocompleteSuggestions(
          query: query,
          sessionToken: _autocompleteSessionToken,
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
        );

        if (!mounted) {
          return;
        }

        final latestQuery = _searchController.text.trim();
        if (latestQuery != query) {
          return;
        }

        setState(() {
          _suggestions = response;
          _isLoadingSuggestions = false;
        });
      } on PlacesApiException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingSuggestions = false;
        });
        _showError(error.message);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingSuggestions = false;
        });
        _showError('Failed to fetch suggestions. Please try again.');
      }
    });
  }

  Future<void> _onSuggestionTap(MapPlaceSuggestion suggestion) async {
    _searchFocusNode.unfocus();
    setState(() {
      _isLoadingPlaceDetails = true;
      _suggestions = const [];
      _searchController.text = suggestion.fullText;
    });

    try {
      final place = await _placesService.fetchPlaceDetails(
        placeId: suggestion.placeId,
      );

      if (!mounted) {
        return;
      }

      _selectedPlace = place;
      // Debug: print generated photo URL for troubleshooting
      try {
        // ignore: avoid_print
        print('[Places] selected place photoUrl: ${place.photoUrl}');
      } catch (_) {}
      _currentCenter = place.position;
      _clearItinerary();

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: place.position, zoom: 14.5),
        ),
      );

      // Refresh nearby markers around the selected place.
      await _loadNearby(center: place.position);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPlaceDetails = false;
      });

      _autocompleteSessionToken = _createSessionToken();
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPlaceDetails = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPlaceDetails = false;
      });
      _showError('Failed to load place details.');
    }
  }

  Future<void> _loadNearby({required LatLng center}) async {
    setState(() {
      _isLoadingNearby = true;
    });

    try {
      final nearby = await _placesService.fetchNearbyPlaces(
        latitude: center.latitude,
        longitude: center.longitude,
        includedTypes: _selectedPlaceTypes,
        radiusMeters: 7000,
        maxResultCount: 40,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearbyPlaces = nearby;
        _currentCenter = center;
        _lastNearbyFetchCenter = center;
        _isLoadingNearby = false;
      });
      try {
        // Debug print first few photoUrls
        for (var i = 0; i < (nearby.length < 3 ? nearby.length : 3); i++) {
          final p = nearby[i];
          // ignore: avoid_print
          print('[Places] nearby[${i}] photoUrl: ${p.photoUrl}');
        }
      } catch (_) {}
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      _showError('Failed to fetch nearby places.');
    }
  }

  bool _shouldRefreshNearbyForCenter(LatLng center) {
    final previous = _lastNearbyFetchCenter;
    if (previous == null) {
      return true;
    }

    final latDiff = (center.latitude - previous.latitude).abs();
    final lngDiff = (center.longitude - previous.longitude).abs();

    return latDiff > 0.015 || lngDiff > 0.015;
  }

  Future<void> _loadNearbyForVisibleRegion() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    setState(() {
      _isLoadingNearby = true;
    });

    try {
      final bounds = await controller.getVisibleRegion();

      final north = bounds.northeast.latitude;
      final east = bounds.northeast.longitude;
      final south = bounds.southwest.latitude;
      final west = bounds.southwest.longitude;

      final center = LatLng((north + south) / 2, (east + west) / 2);

      final samplePoints = <LatLng>[
        center,
        LatLng(north, east),
        LatLng(north, west),
        LatLng(south, east),
        LatLng(south, west),
      ];

      final calls = samplePoints
          .map(
            (point) => _placesService.fetchNearbyPlaces(
              latitude: point.latitude,
              longitude: point.longitude,
              includedTypes: _selectedPlaceTypes,
              radiusMeters: 3500,
              maxResultCount: 20,
            ),
          )
          .toList(growable: false);

      final results = await Future.wait(calls);
      final merged = <MapPlace>[];
      final seen = <String>{};

      for (final places in results) {
        for (final place in places) {
          if (seen.add(place.placeId)) {
            merged.add(place);
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nearbyPlaces = merged;
        _currentCenter = center;
        _lastNearbyFetchCenter = center;
        _isLoadingNearby = false;
      });
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      _showError('Failed to load places on the visible area.');
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLocatingUser = true;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw const PlacesApiException(
          'Location services are disabled. Enable GPS and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PlacesApiException('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);
      _currentLocation = latLng;
      _selectedPlace = null;
      _currentCenter = latLng;
      _clearItinerary();

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 14.0),
        ),
      );

      await _loadNearby(center: latLng);

      if (!mounted) {
        return;
      }
      setState(() {
        _isLocatingUser = false;
      });
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLocatingUser = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLocatingUser = false;
      });
      _showError('Failed to get current location.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearItinerary() {
    _routePoints = const [];
    _routeDistanceText = null;
    _routeDurationText = null;
  }

  Future<void> _onOriginChanged(String value) async {
    _originDebounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) {
        return;
      }
      setState(() {
        _originSuggestions = const [];
        _isLoadingOriginSuggestions = false;
      });
      return;
    }

    _originDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingOriginSuggestions = true;
      });

      try {
        final response = await _placesService.fetchAutocompleteSuggestions(
          query: query,
          sessionToken: _createSessionToken(),
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
        );

        if (!mounted || _originController.text.trim() != query) {
          return;
        }

        setState(() {
          _originSuggestions = response;
          _isLoadingOriginSuggestions = false;
        });
      } on PlacesApiException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingOriginSuggestions = false;
        });
        _showError(error.message);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingOriginSuggestions = false;
        });
        _showError('Failed to fetch origin suggestions.');
      }
    });
  }

  Future<void> _onDestinationChanged(String value) async {
    _destinationDebounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationSuggestions = const [];
        _isLoadingDestinationSuggestions = false;
      });
      return;
    }

    _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDestinationSuggestions = true;
      });

      try {
        final response = await _placesService.fetchAutocompleteSuggestions(
          query: query,
          sessionToken: _createSessionToken(),
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
        );

        if (!mounted || _destinationController.text.trim() != query) {
          return;
        }

        setState(() {
          _destinationSuggestions = response;
          _isLoadingDestinationSuggestions = false;
        });
      } on PlacesApiException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingDestinationSuggestions = false;
        });
        _showError(error.message);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingDestinationSuggestions = false;
        });
        _showError('Failed to fetch destination suggestions.');
      }
    });
  }

  Future<void> _onOriginSuggestionTap(MapPlaceSuggestion suggestion) async {
    _originFocusNode.unfocus();
    try {
      final place = await _placesService.fetchPlaceDetails(
        placeId: suggestion.placeId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _manualOrigin = place.position;
        _originController.text = suggestion.fullText;
        _originSuggestions = const [];
      });
    } on PlacesApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Failed to load origin details.');
    }
  }

  Future<void> _onDestinationSuggestionTap(
    MapPlaceSuggestion suggestion,
  ) async {
    _destinationFocusNode.unfocus();
    try {
      final place = await _placesService.fetchPlaceDetails(
        placeId: suggestion.placeId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _manualDestination = place.position;
        _destinationController.text = suggestion.fullText;
        _destinationSuggestions = const [];
      });
    } on PlacesApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Failed to load destination details.');
    }
  }

  Future<void> _useCurrentLocationAsOrigin() async {
    try {
      final origin = await _resolveRouteOrigin();
      if (!mounted) {
        return;
      }
      setState(() {
        _manualOrigin = origin;
        _originController.text = 'Ma position actuelle';
        _originSuggestions = const [];
      });
    } on PlacesApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Failed to resolve current location.');
    }
  }

  Future<void> _buildManualItinerary() async {
    if (_manualOrigin == null || _manualDestination == null) {
      _showError('Select origin and destination first.');
      return;
    }

    setState(() {
      _isLoadingItinerary = true;
    });

    try {
      final route = await _directionsService.fetchDrivingRoute(
        origin: _manualOrigin!,
        destination: _manualDestination!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = route.points;
        _routeDistanceText = route.distanceText.isEmpty
            ? null
            : route.distanceText;
        _routeDurationText = route.durationText.isEmpty
            ? null
            : route.durationText;
        _isLoadingItinerary = false;
      });

      if (_routePoints.isNotEmpty) {
        final bounds = _latLngBoundsFromPoints(
          _routePoints,
          _manualOrigin!,
          _manualDestination!,
        );
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 64),
        );
      }
    } on DirectionsApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingItinerary = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingItinerary = false;
      });
      _showError('Failed to build manual itinerary.');
    }
  }

  Future<LatLng> _resolveRouteOrigin() async {
    if (_currentLocation != null) {
      return _currentLocation!;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const PlacesApiException(
        'Location services are disabled. Enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PlacesApiException('Location permission was not granted.');
    }

    final position = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(position.latitude, position.longitude);
    return _currentLocation!;
  }

  Future<void> _buildItineraryToSelectedPlace() async {
    final destination = _selectedPlace;
    if (destination == null) {
      _showError('Select a place first.');
      return;
    }

    setState(() {
      _isLoadingItinerary = true;
    });

    try {
      final origin = await _resolveRouteOrigin();
      final route = await _directionsService.fetchDrivingRoute(
        origin: origin,
        destination: destination.position,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints = route.points;
        _routeDistanceText = route.distanceText.isEmpty
            ? null
            : route.distanceText;
        _routeDurationText = route.durationText.isEmpty
            ? null
            : route.durationText;
        _isLoadingItinerary = false;
      });

      if (_routePoints.isNotEmpty) {
        final bounds = _latLngBoundsFromPoints(
          _routePoints,
          origin,
          destination.position,
        );
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 64),
        );
      }
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingItinerary = false;
      });
      _showError(error.message);
    } on DirectionsApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingItinerary = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingItinerary = false;
      });
      _showError('Failed to build itinerary.');
    }
  }

  LatLngBounds _latLngBoundsFromPoints(
    List<LatLng> points,
    LatLng origin,
    LatLng destination,
  ) {
    final allPoints = <LatLng>[origin, destination, ...points];
    var south = allPoints.first.latitude;
    var north = allPoints.first.latitude;
    var west = allPoints.first.longitude;
    var east = allPoints.first.longitude;

    for (final point in allPoints.skip(1)) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Nearby markers are color-coded by place type.
    for (final place in _nearbyPlaces) {
      markers.add(
        Marker(
          markerId: MarkerId('nearby_${place.placeId}'),
          position: place.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHueForType(place.primaryType),
          ),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: _buildMarkerSnippet(place),
          ),
          onTap: () {
            setState(() {
              _selectedPlace = place;
            });
          },
        ),
      );
    }

    if (_selectedPlace != null) {
      // Keep a dedicated highlighted marker for the place chosen by search.
      markers.add(
        Marker(
          markerId: const MarkerId('selected_place'),
          position: _selectedPlace!.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: _selectedPlace!.name,
            snippet: _buildMarkerSnippet(_selectedPlace!),
          ),
        ),
      );
    }

    if (_manualOrigin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('manual_origin'),
          position: _manualOrigin!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Départ'),
        ),
      );
    }

    if (_manualDestination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('manual_destination'),
          position: _manualDestination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('selected_itinerary'),
        points: _routePoints,
        width: 6,
        color: const Color(0xFF1768AC),
      ),
    };
  }

  String _buildMarkerSnippet(MapPlace place) {
    final rating = place.rating;
    final ratingText = rating == null
        ? 'No rating'
        : 'Rating: ${rating.toStringAsFixed(1)}';
    final address = (place.address ?? '').trim();
    if (address.isEmpty) {
      return ratingText;
    }
    return '$ratingText | $address';
  }

  double _markerHueForType(String? primaryType) {
    final type = (primaryType ?? '').toLowerCase();

    if (type.contains('restaurant')) {
      return BitmapDescriptor.hueRed;
    }
    if (type.contains('hotel') || type.contains('lodging')) {
      return BitmapDescriptor.hueBlue;
    }
    if (type.contains('beach')) {
      return BitmapDescriptor.hueCyan;
    }
    return BitmapDescriptor.hueOrange;
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _djerbaCenter,
                zoom: 12.2,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: (_) {
                _searchFocusNode.unfocus();
                _originFocusNode.unfocus();
                _destinationFocusNode.unfocus();
                if (_suggestions.isNotEmpty) {
                  setState(() {
                    _suggestions = const [];
                    _originSuggestions = const [];
                    _destinationSuggestions = const [];
                  });
                }
              },
              onCameraIdle: () async {
                final controller = _mapController;
                if (controller == null) {
                  return;
                }
                final center = await controller.getLatLng(
                  ScreenCoordinate(
                    x: (MediaQuery.of(context).size.width / 2).round(),
                    y: (MediaQuery.of(context).size.height / 2).round(),
                  ),
                );
                _currentCenter = center;

                _cameraIdleDebounce?.cancel();
                _cameraIdleDebounce = Timer(
                  const Duration(milliseconds: 700),
                  () {
                    if (!_shouldRefreshNearbyForCenter(center)) {
                      return;
                    }
                    unawaited(_loadNearbyForVisibleRegion());
                  },
                );
              },
              mapType: MapType.hybrid,
              buildingsEnabled: true,
              compassEnabled: true,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: true,
              markers: markers,
              polylines: _buildPolylines(),
            ),

            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  _buildSearchBar(),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSuggestionsDropdown(),
                  ] else ...[
                    const SizedBox(height: 8),
                    _buildTypeFilters(),
                  ],
                ],
              ),
            ),

            if (_isLoadingNearby || _isLoadingPlaceDetails)
              Positioned(
                top: 86,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              ),

            if (_selectedPlace != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: _showManualItineraryPanel ? 260 : 20,
                child: _buildSelectedPlaceCard(_selectedPlace!),
              ),

            if (_showManualItineraryPanel)
              Positioned(
                left: 12,
                right: 12,
                bottom: 20,
                child: _buildManualItineraryPanel(),
              ),

            Positioned(
              right: 12,
              bottom: _showManualItineraryPanel
                  ? 280
                  : (_selectedPlace == null ? 26 : 120),
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'location_btn',
                    onPressed: _isLocatingUser ? null : _goToCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1768AC),
                    child: _isLocatingUser
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'itinerary_panel_btn',
                    onPressed: () {
                      setState(() {
                        _showManualItineraryPanel = !_showManualItineraryPanel;
                        _originSuggestions = const [];
                        _destinationSuggestions = const [];
                        _originFocusNode.unfocus();
                        _destinationFocusNode.unfocus();
                      });
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5B21B6),
                    child: Icon(
                      _showManualItineraryPanel ? Icons.close : Icons.route,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'djerba_center_btn',
                    onPressed: () async {
                      await _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          const CameraPosition(
                            target: _djerbaCenter,
                            zoom: 12.2,
                          ),
                        ),
                      );
                      await _loadNearby(center: _djerbaCenter);
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A8754),
                    child: const Icon(Icons.travel_explore),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF1768AC)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                unawaited(_onSearchChanged(value));
              },
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search places in Djerba',
                border: InputBorder.none,
              ),
            ),
          ),
          if (_isLoadingSuggestions)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _suggestions = const [];
                });
              },
              child: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(
              suggestion.primaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: suggestion.secondaryText.isEmpty
                ? null
                : Text(
                    suggestion.secondaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () {
              unawaited(_onSuggestionTap(suggestion));
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedPlaceCard(MapPlace place) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((place.photoUrl ?? '').isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: NetworkImageWithFallback(url: place.photoUrl!),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            place.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if ((place.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              place.address!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            place.rating == null
                ? 'No rating available'
                : 'Rating: ${place.rating!.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Color(0xFF0A8754),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingItinerary
                      ? null
                      : _buildItineraryToSelectedPlace,
                  icon: _isLoadingItinerary
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route),
                  label: const Text('Itinéraire'),
                ),
              ),
              if (_routePoints.isNotEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    setState(_clearItinerary);
                  },
                  child: const Text('Effacer'),
                ),
              ],
            ],
          ),
          if (_routeDistanceText != null || _routeDurationText != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (_routeDistanceText != null) _routeDistanceText,
                if (_routeDurationText != null) _routeDurationText,
              ].whereType<String>().join(' • '),
              style: const TextStyle(
                color: Color(0xFF1768AC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtrer par type',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (_selectedPlaceTypes.length != _broadPlaceTypes.length)
                GestureDetector(
                  onTap: _resetTypeFilters,
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1768AC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _broadPlaceTypes.map((type) {
              final isSelected = _selectedPlaceTypes.contains(type);
              return GestureDetector(
                onTap: () => _updateSelectedTypes(type),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1768AC)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1768AC)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _formatPlaceType(type),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatPlaceType(String type) {
    final formatted = type
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
    return formatted;
  }

  Widget _buildManualItineraryPanel() {
    final activeSuggestions = _originFocusNode.hasFocus
        ? _originSuggestions
        : (_destinationFocusNode.hasFocus
              ? _destinationSuggestions
              : const <MapPlaceSuggestion>[]);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.route, color: Color(0xFF1768AC), size: 18),
              SizedBox(width: 8),
              Text(
                'Itinéraire manuel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _originController,
            focusNode: _originFocusNode,
            onChanged: (value) {
              _manualOrigin = null;
              unawaited(_onOriginChanged(value));
            },
            decoration: InputDecoration(
              hintText: 'Départ',
              prefixIcon: const Icon(Icons.trip_origin),
              suffixIcon: _isLoadingOriginSuggestions
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _destinationController,
            focusNode: _destinationFocusNode,
            onChanged: (value) {
              _manualDestination = null;
              unawaited(_onDestinationChanged(value));
            },
            decoration: InputDecoration(
              hintText: 'Destination',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: _isLoadingDestinationSuggestions
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          if (activeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeSuggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = activeSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      suggestion.primaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: suggestion.secondaryText.isEmpty
                        ? null
                        : Text(
                            suggestion.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () {
                      if (_originFocusNode.hasFocus) {
                        unawaited(_onOriginSuggestionTap(suggestion));
                      } else {
                        unawaited(_onDestinationSuggestionTap(suggestion));
                      }
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _useCurrentLocationAsOrigin,
                icon: const Icon(Icons.my_location),
                label: const Text('Ma position'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isLoadingItinerary ? null : _buildManualItinerary,
                icon: _isLoadingItinerary
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route),
                label: const Text('Tracer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
