import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

// Imports de ton projet - Vérifie bien que ces chemins existent
import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../../../features/maps/services/google_directions_service.dart';
import '../place_detail_screen_v2.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  // Coordonnées par défaut (Djerba)
  static const LatLng _djerbaCenter = LatLng(33.8076, 10.8451);

  // Contrôleurs
  GoogleMapController? _mapController;
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _originCtrl = TextEditingController(
    text: "Ma position actuelle",
  );
  final TextEditingController _destinationCtrl = TextEditingController();

  // Données et État
  List<LieuModel> _lieux = const <LieuModel>[];
  String _activeFilter = 'All';
  LieuModel? _selectedLieu;
  LatLng? _customPickedLocation;
  LatLng? _currentUserLocation;
  List<LatLng> _routePoints = [];
  bool _showItineraryPanel = false;

  // Filtres disponibles
  static const List<String> _filters = [
    'All',
    'Museums',
    'Beaches',
    'Dining',
    'History',
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _searchCtrl.addListener(_onSearchChanged);
    _loadLieux();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // --- INITIALISATION ---

  Future<void> _checkPermissions() async {
    await Permission.location.request();
    await _refreshCurrentPosition();
  }

  String _formatCoords(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  Future<void> _refreshCurrentPosition({bool centerMap = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final point = LatLng(pos.latitude, pos.longitude);

    if (!mounted) return;
    setState(() {
      _currentUserLocation = point;
      _originCtrl.text = _formatCoords(point);
    });

    if (centerMap) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
    }
  }

  Future<void> _loadLieux() async {
    try {
      final lieux = await LieuService.getLieux();
      if (!mounted) return;
      setState(() {
        _lieux = lieux;
      });
    } catch (e) {
      debugPrint("Erreur chargement lieux: $e");
      if (!mounted) return;
      setState(() {});
    }
  }

  // --- LOGIQUE DE NAVIGATION (CORRIGÉE) ---

  Future<void> _continueInGoogleMaps() async {
    double? lat;
    double? lng;

    // On récupère les coordonnées de la destination
    if (_selectedLieu != null) {
      lat = _selectedLieu!.latitude;
      lng = _selectedLieu!.longitude;
    } else if (_customPickedLocation != null) {
      lat = _customPickedLocation!.latitude;
      lng = _customPickedLocation!.longitude;
    }

    if (lat == null || lng == null) return;

    // IMPORTANT : On laisse 'origin' vide.
    // Google Maps interprète l'absence d'origine comme "Ma position actuelle" (Current Location).
    // Cela évite le bug de la Californie (Amphitheatre Pkwy).
    final String url =
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving";

    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir Google Maps")),
      );
    }
  }

  // --- GESTION DES ACTIONS CARTE ---

  void _onMapLongPress(LatLng position) {
    setState(() {
      _customPickedLocation = position;
      _selectedLieu = null;
      _destinationCtrl.text = _formatCoords(position);
      _showItineraryPanel = true;
      _routePoints = []; // Reset route
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    _fetchRoute();
  }

  void _selectLieu(LieuModel lieu) {
    final point = LatLng(lieu.latitude!, lieu.longitude!);
    setState(() {
      _selectedLieu = lieu;
      _customPickedLocation = null;
      _destinationCtrl.text = _formatCoords(point);
      _routePoints = []; // Reset route
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(point));
  }

  Future<void> _fetchRoute() async {
    LatLng? destination;
    if (_selectedLieu != null) {
      destination = LatLng(_selectedLieu!.latitude!, _selectedLieu!.longitude!);
    } else if (_customPickedLocation != null) {
      destination = _customPickedLocation;
    }

    if (destination == null || _currentUserLocation == null) return;

    try {
      final route = await _directionsService.fetchDrivingRoute(
        origin: _currentUserLocation!,
        destination: destination,
      );
      if (mounted) {
        setState(() {
          _routePoints = route.points;
        });

        // Ajuster la caméra pour voir tout l'itinéraire
        if (_routePoints.isNotEmpty) {
          final bounds = _getBounds(_routePoints);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération de l'itinéraire: $e");
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _recenterToDjerba() async {
    if (_currentUserLocation == null) {
      await _refreshCurrentPosition(centerMap: true);
      return;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentUserLocation!, 15),
    );
  }

  // --- LOGIQUE DE FILTRAGE ---

  List<LieuModel> get _visibleLieux {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _lieux.where((lieu) {
      final c = lieu.categorie.toLowerCase();
      final t = lieu.titre.toLowerCase();
      final s = lieu.sousTitre.toLowerCase();

      final filterOk =
          _activeFilter == 'All' ||
          (_activeFilter == 'Museums' && c.contains('museum')) ||
          (_activeFilter == 'Beaches' && c.contains('beach')) ||
          (_activeFilter == 'Dining' &&
              (c.contains('restaurant') ||
                  s.contains('restaurant') ||
                  t.contains('cafe'))) ||
          (_activeFilter == 'History' &&
              (c.contains('village') ||
                  t.contains('history') ||
                  s.contains('histor')));

      if (!filterOk) return false;
      if (query.isEmpty) return true;
      return t.contains(query) || s.contains(query) || c.contains(query);
    }).toList();
  }

  List<LieuModel> get _searchSuggestions {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return const <LieuModel>[];
    return _visibleLieux.take(6).toList(growable: false);
  }

  void _onSearchSubmitted(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return;

    final suggestions = _searchSuggestions;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No destination found for this search')),
      );
      return;
    }

    _selectLieu(suggestions.first);
    _searchFocusNode.unfocus();
  }

  void _onSelectSearchResult(LieuModel lieu) {
    _searchCtrl.text = lieu.titre;
    _searchCtrl.selection = TextSelection.collapsed(
      offset: _searchCtrl.text.length,
    );
    _selectLieu(lieu);
    _searchFocusNode.unfocus();
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = _visibleLieux
        .where((l) => l.latitude != null && l.longitude != null)
        .map(
          (l) => Marker(
            markerId: MarkerId(l.id),
            position: LatLng(l.latitude!, l.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedLieu?.id == l.id
                  ? BitmapDescriptor.hueViolet
                  : BitmapDescriptor.hueRose,
            ),
            onTap: () => _selectLieu(l),
            infoWindow: InfoWindow(
              title: l.titre,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailScreenV2(place: _toPlaceMap(l)),
                ),
              ),
            ),
          ),
        )
        .toSet();

    if (_customPickedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('manual_pick'),
          position: _customPickedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: const Color(0xFF2158F6),
        width: 5,
      ),
    };
  }

  Map<String, dynamic> _toPlaceMap(LieuModel l) {
    return {
      '_id': l.id,
      'title': l.titre,
      'subtitle': l.sousTitre,
      'description': l.description,
      'image': l.displayImage,
      'images': l.images,
      'rating': l.noteMoyenne.toStringAsFixed(1),
      'nombreAvis': l.nombreAvis,
      'top_destination': l.topDestination,
      'activity_id': l.activiteLieeId,
      'coordonnees': {'latitude': l.latitude, 'longitude': l.longitude},
      'price': l.prix,
      'categorie': l.categorie,
    };
  }

  // --- INTERFACE (BUILD) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. LA CARTE
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _djerbaCenter,
              zoom: 11.5,
            ),
            onMapCreated: (c) => _mapController = c,
            onLongPress: _onMapLongPress,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
          ),

          // 2. OVERLAY D'INTERFACE (RECHERCHE OU ITINERAIRE)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  _showItineraryPanel
                      ? _buildItineraryPanel()
                      : _buildSearchBar(),
                  const SizedBox(height: 12),
                  if (!_showItineraryPanel) _buildFilterList(),
                  if (!_showItineraryPanel && _searchSuggestions.isNotEmpty)
                    const SizedBox(height: 10),
                  if (!_showItineraryPanel && _searchSuggestions.isNotEmpty)
                    _buildSearchSuggestions(),
                ],
              ),
            ),
          ),

          // 3. BOUTONS FLOTTANTS (BAS)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton Plus Détails (S'affiche quand on sélectionne un lieu)
                if (_selectedLieu != null && !_showItineraryPanel)
                  Hero(
                    tag: 'details_fab',
                    child: Material(
                      color: const Color(0xFF2158F6),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaceDetailScreenV2(
                                place: _toPlaceMap(_selectedLieu!),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                "Plus Détails",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Bouton Itinerary (S'affiche quand on a une position personnalisée)
                if (_customPickedLocation != null &&
                    _selectedLieu == null &&
                    !_showItineraryPanel)
                  Hero(
                    tag: 'itinerary_fab',
                    child: Material(
                      color: const Color(0xFF2158F6),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          setState(() {
                            _showItineraryPanel = true;
                          });
                          _fetchRoute();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                "Itinerary",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                /* Bouton Continue (S'affiche quand le panneau itinéraire est ouvert)
                if (_showItineraryPanel)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continueInGoogleMaps,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2158F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Continue in Google Maps",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),*/
              ],
            ),
          ),

          // 4. BOUTON RECENTRER (S'affiche si on n'est pas en mode itinéraire)
          if (!_showItineraryPanel)
            Positioned(
              right: 18,
              bottom: 72,
              child: Hero(
                tag: 'recenter_fab',
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _recenterToDjerba,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.my_location, color: Color(0xFF2158F6)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- COMPOSANTS DE L'INTERFACE ---

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF245CF7), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search destinations...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchSuggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade200),
        itemBuilder: (context, index) {
          final lieu = _searchSuggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place, color: Color(0xFF2158F6)),
            title: Text(
              lieu.titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              lieu.sousTitre.isNotEmpty ? lieu.sousTitre : lieu.categoryLabelEn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            onTap: () => _onSelectSearchResult(lieu),
          );
        },
      ),
    );
  }

  Widget _buildItineraryPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
        ],
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec titre et bouton fermer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2158F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions,
                  color: Color(0xFF2158F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Itinéraire',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showItineraryPanel = false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.grey[400] : const Color(0xFF666666),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section Point de départ
          _buildRouteSection(
            title: 'Point de départ',
            icon: Icons.my_location,
            iconColor: const Color(0xFF2158F6),
            controller: _originCtrl,
            isOrigin: true,
          ),

          const SizedBox(height: 16),

          // Ligne de connexion
          Container(
            height: 2,
            margin: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2158F6).withOpacity(0.3),
                  const Color(0xFF2158F6).withOpacity(0.1),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Section Destination
          _buildRouteSection(
            title: 'Destination',
            icon: Icons.place,
            iconColor: Colors.redAccent,
            controller: _destinationCtrl,
            isOrigin: false,
          ),

          const SizedBox(height: 20),

          // Bouton d'action
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2158F6), Color(0xFF1976D2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2158F6).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _continueInGoogleMaps,
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Naviguer avec Google Maps',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildRouteSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required bool isOrigin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    readOnly: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    decoration: InputDecoration(
                      hintText: isOrigin
                          ? 'Ma position actuelle'
                          : 'Destination sélectionnée',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (isOrigin) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _refreshCurrentPosition,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2158F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Color(0xFF2158F6),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInput(
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    bool isDisabled = false,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !isDisabled,
              readOnly: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDisabled ? Colors.grey : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Icon(icon, size: 18, color: const Color(0xFF2158F6)),
        ],
      ),
    );
  }

  Widget _buildFilterList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _filters[index];
          final isSelected = item == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2158F6)
                    : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8EEF5)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  item,
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4D4E7A)),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
