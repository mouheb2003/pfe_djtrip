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
import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../../../theme/app_theme.dart';
import '../../../screens/tourist/place_detail_screen.dart';

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
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // ignore: avoid_print
              print('[NetworkImageWithFallback] Error loading image: $error');
              print('[NetworkImageWithFallback] URL: $url');
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          );
        }
        // Debug print for loading state
        // ignore: avoid_print
        print('[NetworkImageWithFallback] Loading image from URL: $url');
        print('[NetworkImageWithFallback] Snapshot data: ${snapshot.hasData}');
        print('[NetworkImageWithFallback] Snapshot error: ${snapshot.error}');

        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }
}

class PlaceListItem extends StatelessWidget {
  const PlaceListItem({Key? key, required this.place, required this.onTap})
    : super(key: key);

  final MapPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade200,
              ),
              child: place.photoUrl != null && place.photoUrl!.isNotEmpty
                  ? NetworkImageWithFallback(url: place.photoUrl!)
                  : Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  if (place.rating != null)
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  // Address
                  if (place.address != null)
                    Text(
                      place.address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final LieuService _lieuService = LieuService();
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
  List<LieuModel> _lieuxFromBD = [];

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
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedPlaceTypes = [];
    _autocompleteSessionToken = _createSessionToken();
    unawaited(_loadNearby(center: _djerbaCenter));
    unawaited(_loadLieuxFromBD());
  }

  Future<void> _loadLieuxFromBD() async {
    try {
      final lieux = await LieuService.getLieux();
      setState(() {
        _lieuxFromBD = lieux
            .where((l) => l.latitude != null && l.longitude != null)
            .toList();
      });
    } catch (e) {
      // Silently handle error
    }
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

  Future<void> _updateSelectedTypes(String type) async {
    setState(() {
      if (_selectedPlaceTypes.contains(type)) {
        _selectedPlaceTypes.remove(type);
      } else {
        // Only keep the selected type (single select)
        _selectedPlaceTypes.clear();
        _selectedPlaceTypes.add(type);
      }
    });
    // Debug: log selected types so we can trace filter behavior
    try {
      // ignore: avoid_print
      print(
        '[MapExplorer] _updateSelectedTypes -> toggled: $type, selectedTypes: $_selectedPlaceTypes',
      );
    } catch (_) {}

    await _loadNearby(center: _currentCenter);

    // Show the bottom sheet with filtered places
    if (mounted && _selectedPlaceTypes.isNotEmpty) {
      _showPlacesForTypeSheet(_selectedPlaceTypes);
    }
  }

  void _resetTypeFilters() {
    setState(() {
      _selectedPlaceTypes = [];
    });
    try {
      // ignore: avoid_print
      print(
        '[MapExplorer] _resetTypeFilters -> reset to: $_selectedPlaceTypes',
      );
    } catch (_) {}

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
      // ignore: avoid_print
      print(
        '[MapExplorer] _loadNearby -> center: ${center.latitude}, ${center.longitude}, selectedFilter: $_selectedFilter, includedTypes: $_selectedPlaceTypes',
      );
    } catch (_) {}

    try {
      // Use selectedFilter to determine includedTypes
      final includedTypes = _selectedFilter == 'all'
          ? <String>[]
          : <String>[_selectedFilter];

      // Debug print
      // ignore: avoid_print
      print('[MapExplorer] Fetching nearby with includedTypes: $includedTypes');

      final nearby = await _placesService.fetchNearbyPlaces(
        latitude: center.latitude,
        longitude: center.longitude,
        includedTypes: includedTypes,
        radiusMeters: 7000,
        maxResultCount: 20,
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
        // Debug print first few places: name, primaryType and photoUrl
        for (var i = 0; i < (nearby.length < 5 ? nearby.length : 5); i++) {
          final p = nearby[i];
          // ignore: avoid_print
          print(
            '[Places] nearby[${i}] name: ${p.name}, primaryType: ${p.primaryType}, photoUrl: ${p.photoUrl}',
          );
        }
      } catch (_) {}
    } on PlacesApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      // Error suppressed
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
      // Error suppressed
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNearby = false;
      });
      // Error suppressed
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

  void _showPlacesForTypeSheet(List<String> selectedTypes) {
    // Debug: log selected types & nearby count before showing sheet
    try {
      // ignore: avoid_print
      print(
        '[MapExplorer] showPlacesForTypeSheet -> selectedTypes: $selectedTypes, nearbyCount: ${_nearbyPlaces.length}',
      );
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            final filteredPlaces = selectedTypes.isEmpty
                ? _nearbyPlaces
                : _nearbyPlaces.where((place) {
                    return place.primaryType != null &&
                        selectedTypes.contains(place.primaryType);
                  }).toList();

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lieux trouvés (${filteredPlaces.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Places list
                Expanded(
                  child: filteredPlaces.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun lieu trouvé pour les filtres sélectionnés',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) {
                            final place = filteredPlaces[index];
                            return PlaceListItem(
                              place: place,
                              onTap: () {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(place.position),
                                );
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPlaceDetailsModal(MapPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag indicator
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Détails du lieu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Large photo with gradient overlay
                    if ((place.photoUrl ?? '').isNotEmpty) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: NetworkImageWithFallback(
                                url: place.photoUrl!,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Name with Type badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Type badge
                              if ((place.primaryType ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2158F6,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    place.primaryType!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2158F6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info section with divider
                    Divider(
                      color: Colors.grey.shade200,
                      thickness: 1,
                      height: 24,
                    ),

                    // Rating and info row
                    Row(
                      children: [
                        // Rating
                        if (place.rating != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${place.rating!.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Address section
                    if ((place.address ?? '').trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2158F6,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF2158F6),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Adresse',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    place.address!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _buildItineraryToSelectedPlace();
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF2158F6),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.transparent,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_rounded,
                                      color: Color(0xFF2158F6),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Itinéraire',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2158F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaceDetailScreen(
                                      place: {
                                        '_id': place.placeId,
                                        'title': place.name,
                                        'subtitle': place.primaryType ?? '',
                                        'description': place.address ?? '',
                                        'image': place.photoUrl ?? '',
                                        'images': [
                                          if ((place.photoUrl ?? '').isNotEmpty)
                                            place.photoUrl!,
                                        ],
                                        'rating':
                                            (place.rating?.toStringAsFixed(
                                              1,
                                            )) ??
                                            '0.0',
                                        'nombreAvis': 0,
                                        'top_destination': false,
                                        'activity_id': null,
                                        'coordonnees': {
                                          'latitude': place.position.latitude,
                                          'longitude': place.position.longitude,
                                        },
                                        'price': 0,
                                        'categorie':
                                            place.primaryType ?? 'Place',
                                      },
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2158F6),
                                      Color(0xFF1B42CC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2158F6,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Plus Détail',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    // Debug print
    // ignore: avoid_print
    print(
      '[MapExplorer] Building markers - lieuxFromBD count: ${_lieuxFromBD.length}',
    );
    print('[MapExplorer] Current filter: $_selectedFilter');

    // Add markers for lieux from database
    for (final lieu in _lieuxFromBD) {
      // Show lieux from BD based on filter
      if (_selectedFilter != 'all') {
        // Only show lieux from BD of this specific type
        final lieuType = lieu.categorie?.toLowerCase() ?? '';
        final filterType = _selectedFilter.toLowerCase();

        // Handle plural/singular matching
        bool isMatch = false;
        if (filterType == 'restaurant') {
          isMatch =
              lieuType.contains('restaurant') ||
              lieuType.contains('restaurants');
        } else if (filterType == 'museum') {
          isMatch = lieuType.contains('museum') || lieuType.contains('museums');
        } else if (filterType == 'beach') {
          isMatch = lieuType.contains('beach') || lieuType.contains('beaches');
        } else if (filterType == 'hotel') {
          isMatch =
              lieuType.contains('hotel') ||
              lieuType.contains('accommodation') ||
              lieuType.contains('lodging');
        } else if (filterType == 'park') {
          isMatch = lieuType.contains('park') || lieuType.contains('parks');
        } else if (filterType == 'cafe') {
          isMatch = lieuType.contains('cafe') || lieuType.contains('cafes');
        } else if (filterType == 'shopping_mall' || filterType == 'store') {
          isMatch =
              lieuType.contains('shopping') ||
              lieuType.contains('store') ||
              lieuType.contains('mall');
        } else if (filterType == 'mosque') {
          isMatch = lieuType.contains('mosque') || lieuType.contains('mosques');
        } else if (filterType == 'tourist_attraction') {
          isMatch =
              lieuType.contains('tourist') ||
              lieuType.contains('attraction') ||
              lieuType.contains('activity') ||
              lieuType.contains('activities');
        } else {
          isMatch = lieuType == filterType;
        }

        // Debug print
        // ignore: avoid_print
        print(
          '[MapExplorer] Lieu BD: "${lieu.titre}" - categorie: "$lieuType" - filter: "$filterType" - match: $isMatch',
        );

        if (!isMatch) {
          continue;
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId('lieu_${lieu.id}'),
          position: LatLng(lieu.latitude!, lieu.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHueForType(lieu.categorie),
          ),
          infoWindow: InfoWindow(title: lieu.titre, snippet: lieu.sousTitre),
          onTap: () {
            // Convert LieuModel to MapPlace compatibility
            final mapPlace = MapPlace(
              placeId: lieu.id,
              name: lieu.titre,
              position: LatLng(lieu.latitude!, lieu.longitude!),
              address: lieu.sousTitre,
              rating: lieu.noteMoyenne,
              primaryType: lieu.categorie,
              photoUrl: lieu.displayImage.isNotEmpty ? lieu.displayImage : null,
            );
            setState(() {
              _selectedPlace = mapPlace;
            });
          },
        ),
      );
    }

    // Debug print
    // ignore: avoid_print
    print(
      '[MapExplorer] Building nearby markers - _nearbyPlaces count: ${_nearbyPlaces.length}',
    );
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

    // Add current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Ma position'),
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

    // Debug print
    // ignore: avoid_print
    print('[MapExplorer] _markerHueForType: "$primaryType" -> "$type"');
    if (type.contains('restaurant')) {
      return BitmapDescriptor.hueRed;
    }
    if (type.contains('hotel') || type.contains('lodging')) {
      return BitmapDescriptor.hueBlue;
    }
    if (type.contains('beach')) {
      return BitmapDescriptor.hueCyan;
    }
    if (type.contains('museum')) {
      return BitmapDescriptor.hueOrange;
    }
    if (type.contains('park')) {
      return BitmapDescriptor.hueGreen;
    }
    if (type.contains('cafe')) {
      return BitmapDescriptor.hueYellow;
    }
    if (type.contains('shopping_mall') || type.contains('store')) {
      return BitmapDescriptor.hueViolet;
    }
    if (type.contains('mosque')) {
      return BitmapDescriptor.hueAzure;
    }
    if (type.contains('tourist_attraction')) {
      return BitmapDescriptor.hueMagenta;
    }
    return BitmapDescriptor.hueOrange;
  }

  Future<void> _hideSelectedPlaceInfoWindow() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    try {
      await controller.hideMarkerInfoWindow(const MarkerId('selected_place'));
    } catch (_) {}

    final selectedPlace = _selectedPlace;
    if (selectedPlace != null) {
      try {
        await controller.hideMarkerInfoWindow(
          MarkerId('nearby_${selectedPlace.placeId}'),
        );
      } catch (_) {}
    }
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
                unawaited(_hideSelectedPlaceInfoWindow());
                setState(() {
                  _suggestions = const [];
                  _originSuggestions = const [];
                  _destinationSuggestions = const [];
                  _selectedPlace = null;
                  _showManualItineraryPanel = false;
                });
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                unawaited(_onSearchChanged(value));
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher des lieux à Djerba',
                hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_isLoadingSuggestions)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _suggestions = const [];
                });
              },
              child: Icon(
                Icons.close,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showPlaceDetailsModal(place),
              icon: const Icon(Icons.info_outline),
              label: const Text('Plus de détails'),
            ),
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _broadPlaceTypes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" filter
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All', style: TextStyle(fontSize: 12)),
                selected: _selectedFilter == 'all',
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.primary,
                checkmarkColor: AppColors.onPrimary,
                side: BorderSide(
                  color: _selectedFilter == 'all'
                      ? AppColors.primary
                      : AppColors.outline,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = 'all';
                    _selectedPlaceTypes = [];
                  });
                  unawaited(_loadNearbyForVisibleRegion());
                },
              ),
            );
          }

          final type = _broadPlaceTypes[index - 1];
          final isSelected = _selectedFilter == type;
          final displayName = type
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) {
                if (word.isEmpty) return '';
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(displayName, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.onPrimary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.outline,
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? type : 'all';
                  _selectedPlaceTypes = selected ? [type] : [];
                });
                unawaited(_loadNearbyForVisibleRegion());
              },
            ),
          );
        },
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
