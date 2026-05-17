import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

import '../../models/lieu_model.dart';
import '../../services/lieu_service.dart';

/// Result returned when user confirms a location on the map.
class MapPickerResult {
  final LatLng latLng;
  final String address;
  final String placeName;

  MapPickerResult({
    required this.latLng,
    required this.address,
    this.placeName = '',
  });
}

/// Unified search result item (from BD or geocoding).
class _SearchItem {
  final String name;
  final String subtitle;
  final LatLng position;
  final String source; // 'bd' or 'geo'

  const _SearchItem({
    required this.name,
    required this.subtitle,
    required this.position,
    required this.source,
  });
}

class InteractiveDjerbaMapScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final LatLng? initialPoint;

  const InteractiveDjerbaMapScreen({
    super.key,
    this.initialPosition,
    this.initialPoint,
  });

  @override
  State<InteractiveDjerbaMapScreen> createState() =>
      _InteractiveDjerbaMapScreenState();
}

class _InteractiveDjerbaMapScreenState
    extends State<InteractiveDjerbaMapScreen> {
  // Djerba center
  static const LatLng _djerbaCenter = LatLng(33.8076, 10.8451);
  static const double _defaultZoom = 12.0;

  late LatLng _pickedLatLng;
  String _placeName = '';
  String _address = '';
  bool _loading = false;
  bool _loadingSearch = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  // All places from BD
  List<LieuModel> _bdPlaces = [];
  bool _bdLoaded = false;

  // Search results (combined BD + geocoding)
  List<_SearchItem> _searchResults = [];
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _pickedLatLng =
        widget.initialPosition ?? widget.initialPoint ?? _djerbaCenter;

    _loadBdPlaces();

    // Reverse geocode initial position if provided
    if (widget.initialPosition != null || widget.initialPoint != null) {
      _reverseGeocode(_pickedLatLng);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── LOAD BD PLACES ───────────────────────────────────────────────

  Future<void> _loadBdPlaces() async {
    try {
      final lieux = await LieuService.getLieux();
      if (!mounted) return;
      setState(() {
        _bdPlaces = lieux;
        _bdLoaded = true;
        _updateMarkers();
      });
      debugPrint('📍 MAP: Loaded ${lieux.length} places from BD');
    } catch (e) {
      debugPrint('📍 MAP ERROR: Failed to load BD places: $e');
      if (mounted) setState(() => _bdLoaded = true);
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};

    // 1) Add BD markers
    for (final lieu in _bdPlaces) {
      if (lieu.latitude != null && lieu.longitude != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('bd_${lieu.id ?? lieu.titre}'),
            position: LatLng(lieu.latitude!, lieu.longitude!),
            infoWindow: InfoWindow(
              title: lieu.titre,
              snippet: lieu.sousTitre,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            onTap: () {
              _onMapTapped(LatLng(lieu.latitude!, lieu.longitude!));
            },
          ),
        );
      }
    }

    // 2) Add picked location marker
    newMarkers.add(
      Marker(
        markerId: const MarkerId('picked_location'),
        position: _pickedLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    setState(() {
      _markers = newMarkers;
    });
  }

  // ─── REVERSE GEOCODE ──────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _loading = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final name = pm.name ?? pm.street ?? '';
        final locality = pm.locality ?? '';
        final country = pm.country ?? '';

        // Build a readable address
        final parts = [name, locality, country]
            .where((s) => s.isNotEmpty)
            .toList();
        final fullAddress = parts.join(', ');

        // Try to find matching BD place nearby
        final nearbyBd = _findNearbyBdPlace(latLng);

        setState(() {
          if (nearbyBd != null) {
            _placeName = nearbyBd.titre;
            _address = fullAddress.isNotEmpty ? fullAddress : nearbyBd.sousTitre;
          } else {
            _placeName = name.isNotEmpty ? name : locality;
            _address = fullAddress;
          }
          _loading = false;
        });
      } else {
        setState(() {
          _placeName = '';
          _address = 'Unknown location';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('📍 MAP ERROR: Reverse geocoding failed: $e');
      if (!mounted) return;

      // Fallback: check BD
      final nearbyBd = _findNearbyBdPlace(latLng);
      setState(() {
        _placeName = nearbyBd?.titre ?? '';
        _address = nearbyBd?.sousTitre ?? 'Location selected';
        _loading = false;
      });
    }
  }

  /// Find a BD place within ~200m of the given point.
  LieuModel? _findNearbyBdPlace(LatLng point) {
    const threshold = 0.002; // ~200m
    for (final lieu in _bdPlaces) {
      if (lieu.latitude == null || lieu.longitude == null) continue;
      final dLat = (lieu.latitude! - point.latitude).abs();
      final dLng = (lieu.longitude! - point.longitude).abs();
      if (dLat < threshold && dLng < threshold) return lieu;
    }
    return null;
  }

  // ─── SEARCH ───────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  static const List<String> _fixedLocations = [
    'Djerba Explore Park',
    'Houmt Souk Medina',
    'Guellala Museum',
    'Djerba Heritage Museum',
    'Borj Ghazi Mustapha Fort',
    'Midoun Beach',
    'Sidi Mahrsi Beach',
    'Djerba Golf Club',
    'Crocodile Farm',
    'Djerba Aqua Park',
  ];

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _loadingSearch = true);

    final results = <_SearchItem>[];
    final lowerQuery = query.toLowerCase();

    // 1) Search BD places
    for (final lieu in _bdPlaces) {
      if (lieu.titre.toLowerCase().contains(lowerQuery) ||
          lieu.sousTitre.toLowerCase().contains(lowerQuery) ||
          lieu.categorie.toLowerCase().contains(lowerQuery)) {
        if (lieu.latitude != null && lieu.longitude != null) {
          results.add(_SearchItem(
            name: lieu.titre,
            subtitle: lieu.sousTitre.isNotEmpty
                ? lieu.sousTitre
                : lieu.categoryLabelEn,
            position: LatLng(lieu.latitude!, lieu.longitude!),
            source: 'bd',
          ));
        }
      }
    }

    // 1.5) Search Fixed Locations
    for (final fixed in _fixedLocations) {
      if (fixed.toLowerCase().contains(lowerQuery)) {
        // Check if already found in BD results
        if (!results.any((r) => r.name.toLowerCase() == fixed.toLowerCase())) {
          // Try to find in _bdPlaces for coordinates
          final match = _bdPlaces.firstWhere(
            (l) => l.titre.toLowerCase() == fixed.toLowerCase(),
            orElse: () => LieuModel(
              id: 'fixed_${fixed.hashCode}',
              titre: fixed,
              sousTitre: 'Djerba, Tunisia',
              description: 'Partner location in Djerba',
              categorie: 'Fixed',
              imagePortrait: '',
              images: const [],
              noteMoyenne: 0.0,
              nombreAvis: 0,
              topDestination: false,
              prix: 'FREE',
              latitude: null,
              longitude: null,
            ),
          );

          if (match.latitude != null && match.longitude != null) {
            results.add(_SearchItem(
              name: match.titre,
              subtitle: match.sousTitre,
              position: LatLng(match.latitude!, match.longitude!),
              source: 'bd',
            ));
          }
        }
      }
    }

    // 2) Search via geocoding API (address search)
    try {
      final locations = await locationFromAddress('$query, Djerba, Tunisia');
      for (final loc in locations.take(5)) {
        // Avoid duplicates near existing BD results
        final isDuplicate = results.any((r) =>
            (r.position.latitude - loc.latitude).abs() < 0.001 &&
            (r.position.longitude - loc.longitude).abs() < 0.001);
        if (!isDuplicate) {
          results.add(_SearchItem(
            name: query,
            subtitle: 'Djerba, Tunisia',
            position: LatLng(loc.latitude, loc.longitude),
            source: 'geo',
          ));
        }
      }
    } catch (e) {
      debugPrint('📍 MAP: Geocoding search failed for "$query": $e');
    }

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _showResults = results.isNotEmpty;
      _loadingSearch = false;
    });
  }

  // ─── USER ACTIONS ─────────────────────────────────────────────────

  void _selectSearchResult(_SearchItem item) {
    setState(() {
      _pickedLatLng = item.position;
      _placeName = item.name;
      _address = item.subtitle;
      _searchResults = [];
      _showResults = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(item.position, 15),
    );
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      _pickedLatLng = latLng;
      _placeName = '';
      _address = '';
      _showResults = false;
    });
    _updateMarkers();
    _reverseGeocode(latLng);
  }

  void _confirmSelection() {
    final displayName = _placeName.isNotEmpty ? _placeName : _address;
    Navigator.pop(
      context,
      MapPickerResult(
        latLng: _pickedLatLng,
        address: _address.isNotEmpty ? _address : displayName,
        placeName: displayName,
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayName = _placeName.isNotEmpty
        ? _placeName
        : (_address.isNotEmpty ? _address : 'Tap on map to select');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Select Location',
          style: TextStyle(
            color: Color(0xFF245CF7),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF245CF7)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF245CF7),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E9FF)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.search, color: Color(0xFF245CF7), size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _performSearch(v.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search places in Djerba...',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.grey, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showResults = false;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                if (_loadingSearch)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),

          // ── Map + Overlays ──
          Expanded(
            child: Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLatLng,
                    zoom: _defaultZoom,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onTap: _onMapTapped,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                ),

                // Search Results Overlay
                if (_showResults && _searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: item.source == 'bd'
                                      ? const Color(0xFF245CF7).withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.source == 'bd'
                                      ? Icons.place
                                      : Icons.travel_explore,
                                  color: item.source == 'bd'
                                      ? const Color(0xFF245CF7)
                                      : Colors.orange,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                item.subtitle,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                item.source == 'bd' ? 'DB' : 'Map',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => _selectSearchResult(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Loading indicator
                if (_loading)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Locating...',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                // My Location button
                Positioned(
                  right: 14,
                  bottom: 160,
                  child: FloatingActionButton.small(
                    heroTag: 'my_location',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_djerbaCenter, _defaultZoom),
                      );
                    },
                    child: const Icon(Icons.my_location,
                        color: Color(0xFF245CF7), size: 20),
                  ),
                ),

                // ── Bottom Info Card ──
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Place name (prominent)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF245CF7).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place,
                                  color: Color(0xFF245CF7), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1B2458),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_address.isNotEmpty &&
                                      _address != displayName)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        _address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Coordinates (secondary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.gps_fixed,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_pickedLatLng.latitude.toStringAsFixed(6)}, ${_pickedLatLng.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _confirmSelection,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Confirm this location',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF245CF7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
