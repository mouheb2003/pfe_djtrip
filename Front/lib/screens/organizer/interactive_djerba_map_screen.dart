import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../../models/place_model.dart';

class MapPickerResult {
  final LatLng latLng;
  final String address;

  MapPickerResult({
    required this.latLng,
    required this.address,
  });
}

class InteractiveDjerbaMapScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final LatLng? initialPoint;

  const InteractiveDjerbaMapScreen({super.key, this.initialPosition, this.initialPoint});

  @override
  State<InteractiveDjerbaMapScreen> createState() => _InteractiveDjerbaMapScreenState();
}

class _InteractiveDjerbaMapScreenState extends State<InteractiveDjerbaMapScreen> {
  // Djerba bounds for better map display
  static const LatLng _djerbaCenter = LatLng(33.8076, 10.8451);
  static const double _defaultZoom = 12.0;
  
  late LatLng _pickedLatLng;
  String _address = '';
  bool _loading = false;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<PlaceModel> _searchResults = [];
  List<PlaceModel> _allPlaces = [];

  @override
  void initState() {
    super.initState();
    _pickedLatLng = widget.initialPosition ?? widget.initialPoint ?? _djerbaCenter;
    
    // Initialize with some default places
    _loadDefaultPlaces();
    
    // Get initial address if coordinates provided
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

  void _loadDefaultPlaces() {
    setState(() {
      _allPlaces = [
        PlaceModel(
          placeId: '1',
          name: 'Djerba Explore Park',
          formattedAddress: 'Djerba Explore Park, Midoun',
          coordinates: const LatLng(33.7931, 10.8606),
          types: ['park'],
          rating: 4.2,
        ),
        PlaceModel(
          placeId: '2',
          name: 'Houmt Souk Medina',
          formattedAddress: 'Houmt Souk, Djerba',
          coordinates: const LatLng(33.8815, 10.8606),
          types: ['market'],
          rating: 4.5,
        ),
        PlaceModel(
          placeId: '3',
          name: 'Guellala Museum',
          formattedAddress: 'Guellala Museum, Djerba',
          coordinates: const LatLng(33.7234, 10.7890),
          types: ['museum'],
          rating: 4.0,
        ),
        PlaceModel(
          placeId: '4',
          name: 'Djerba Golf Club',
          formattedAddress: 'Djerba Golf Club, Midoun',
          coordinates: const LatLng(33.7981, 10.8980),
          types: ['golf'],
          rating: 4.3,
        ),
      ];
      _searchResults = _allPlaces;
    });
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _loading = true);
    
    try {
      // Use geocoding API to get address from coordinates
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final placeInfo = placemarks.first;
        setState(() {
          _address = '${placeInfo.street ?? ''}, ${placeInfo.locality ?? ''}, ${placeInfo.country ?? ''}';
          _loading = false;
        });
        debugPrint('🔍 GEOCODING: Address from coordinates: ${placeInfo.street}, ${placeInfo.locality}');
      } else {
        setState(() {
          _address = 'Unknown location';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('🔍 ERROR: Reverse geocoding failed: $e');
      setState(() {
        _address = 'Location error';
        _loading = false;
      });
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = _allPlaces;
      });
      return;
    }

    setState(() => _loading = true);
    
    try {
      // Simple mock search implementation
      final filteredPlaces = _allPlaces.where((place) =>
        place.name.toLowerCase().contains(query.toLowerCase())
      ).toList();
      
      setState(() {
        _searchResults = filteredPlaces;
        _loading = false;
      });
      
      debugPrint('🔍 SEARCH: Found ${filteredPlaces.length} places for "$query"');
    } catch (e) {
      debugPrint('🔍 ERROR: Search failed: $e');
      setState(() {
        _searchResults = [];
        _loading = false;
      });
    }
  }

  void _selectPlace(PlaceModel place) {
    if (place.coordinates != null) {
      final latLng = place.coordinates!;
      setState(() {
        _pickedLatLng = latLng;
        _searchResults.clear(); // Clear search results after selection
        _searchController.clear(); // Clear search text
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      _address = place.formattedAddress ?? ''; // Use formatted address from Google Places
      _searchFocusNode.unfocus(); // Hide keyboard
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocations(_searchController.text);
    });
  }

  void _onSearchSubmitted(String value) {
    _searchLocations(value);
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      _pickedLatLng = latLng;
    });
    _reverseGeocode(latLng);
  }

  void _confirmSelection() {
    Navigator.pop(context, MapPickerResult(
      latLng: _pickedLatLng,
      address: _address,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
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
          TextButton(
            onPressed: _confirmSelection,
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Color(0xFF245CF7),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E9FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF245CF7), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _onSearchSubmitted,
                    onChanged: (value) => _onSearchChanged(),
                    decoration: InputDecoration(
                      hintText: 'Search destinations...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                              )
                            : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLatLng,
                    zoom: _defaultZoom,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  onTap: _onMapTapped,
                  markers: {
                    Marker(
                      markerId: const MarkerId('picked_location'),
                      position: _pickedLatLng,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),

                // Loading Indicator
                if (_loading)
                  const Positioned(
                    top: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Searching...'),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      child: Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: place.iconUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        place.iconUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.place, color: Colors.grey),
                                          );
                                        },
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.place, color: Colors.grey),
                                    ),
                              title: Text(
                                place.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                place.vicinity ?? place.formattedAddress ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => _selectPlace(place),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Address Display
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Selected Location:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Lat: ${_pickedLatLng.latitude.toStringAsFixed(6)}, Lng: ${_pickedLatLng.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
