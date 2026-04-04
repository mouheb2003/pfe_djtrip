import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

// Imports de ton projet - Vérifie bien que ces chemins existent
import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../place_detail_screen.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
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
    _searchCtrl.addListener(() => setState(() {}));
    _loadLieux();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
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
      _showItineraryPanel =
          true; // On affiche directement le panneau au clic long
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _selectLieu(LieuModel lieu) {
    final point = LatLng(lieu.latitude!, lieu.longitude!);
    setState(() {
      _selectedLieu = lieu;
      _customPickedLocation = null;
      _destinationCtrl.text = _formatCoords(point);
      // On n'affiche pas le panneau tout de suite, on laisse l'utilisateur cliquer sur le bouton bleu
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(point));
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
                  builder: (_) => PlaceDetailScreen(place: _toPlaceMap(l)),
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
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
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
                // Bouton Itinerary (S'affiche quand on sélectionne un point)
                if ((_selectedLieu != null || _customPickedLocation != null) &&
                    !_showItineraryPanel)
                  FloatingActionButton.extended(
                    onPressed: () => setState(() => _showItineraryPanel = true),
                    backgroundColor: const Color(0xFF2158F6),
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text(
                      "Itinerary",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Bouton Continue (S'affiche quand le panneau itinéraire est ouvert)
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
                  ),
              ],
            ),
          ),

          // 4. BOUTON RECENTRER (S'affiche si on n'est pas en mode itinéraire)
          if (!_showItineraryPanel)
            Positioned(
              right: 18,
              bottom: 72,
              child: FloatingActionButton(
                onPressed: _recenterToDjerba,
                mini: true,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Color(0xFF2158F6)),
              ),
            ),
        ],
      ),
    );
  }

  // --- COMPOSANTS DE L'INTERFACE ---

  Widget _buildSearchBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchCtrl,
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

  Widget _buildItineraryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colonne des icônes de chemin (Design de l'image)
          Column(
            children: [
              const Icon(Icons.circle, size: 12, color: Color(0xFF2D2D44)),
              Container(height: 35, width: 1.5, color: Colors.grey.shade300),
              const Icon(Icons.location_on, size: 20, color: Colors.redAccent),
            ],
          ),
          const SizedBox(width: 15),
          // Champs de saisie
          Expanded(
            child: Column(
              children: [
                _buildRouteInput(
                  _originCtrl,
                  Icons.my_location,
                  "Point de départ",
                ),
                const SizedBox(height: 10),
                _buildRouteInput(
                  _destinationCtrl,
                  Icons.location_on,
                  "Destination",
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Bouton pour fermer/revenir
          GestureDetector(
            onTap: () => setState(() => _showItineraryPanel = false),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFF2158F6),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInput(
    TextEditingController ctrl,
    IconData icon,
    String hint,
  ) {
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
              enabled: true,
              readOnly: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF2D3B5F),
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(
                  color: Color(0xFF8A93A8),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Icon(icon, size: 18, color: const Color(0xFF2158F6)),
        ],
      ),
    );
  }

  Widget _buildFilterList() {
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
                    : const Color(0xFFE8EEF5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  item,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF4D4E7A),
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
