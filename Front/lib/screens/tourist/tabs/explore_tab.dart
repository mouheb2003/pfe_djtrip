import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Importations locales (Assure-toi que ces chemins sont corrects dans ton projet)
import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../place_detail_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  static const LatLng _djerbaCenter = LatLng(33.8076, 10.8451);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _originCtrl = TextEditingController(
    text: "Ma position actuelle",
  );
  final TextEditingController _destinationCtrl = TextEditingController();

  GoogleMapController? _mapController;

  List<LieuModel> _lieux = const <LieuModel>[];
  bool _isLoading = true;
  String _activeFilter = 'All';

  LieuModel? _selectedLieu;
  LatLng? _customPickedLocation;
  bool _showItineraryPanel = false;

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

  Future<void> _loadLieux() async {
    try {
      final lieux = await LieuService.getLieux();
      if (!mounted) return;
      setState(() {
        _lieux = lieux;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE DE SELECTION ---

  void _onMapLongPress(LatLng position) {
    setState(() {
      _customPickedLocation = position;
      _selectedLieu = null;
      _destinationCtrl.text =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      _showItineraryPanel = false;
    });
  }

  void _selectLieu(LieuModel lieu) {
    setState(() {
      _selectedLieu = lieu;
      _customPickedLocation = null;
      _destinationCtrl.text = lieu.titre;
      _showItineraryPanel = false;
    });
  }

  // --- FILTRAGE ET MARQUEURS ---

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

  // --- ACTIONS ---

  Future<void> _recenterToDjerba() async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _djerbaCenter, zoom: 12),
      ),
    );
  }

  Future<void> _continueInGoogleMaps() async {
    double? lat, lng;
    if (_selectedLieu != null) {
      lat = _selectedLieu!.latitude;
      lng = _selectedLieu!.longitude;
    } else if (_customPickedLocation != null) {
      lat = _customPickedLocation!.latitude;
      lng = _customPickedLocation!.longitude;
    }

    if (lat == null || lng == null) return;

    // "origin=My+Location" utilise le GPS natif de Google Maps
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=My+Location&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. CARTE
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _djerbaCenter,
              zoom: 11.5,
            ),
            onMapCreated: (c) => _mapController = c,
            onLongPress: _onMapLongPress,
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
          ),

          // 2. INTERFACE SUPERIEURE (Recherche OU Itinéraire)
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

          // 3. BOUTON ACTIONS (Itinerary / Continue)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((_selectedLieu != null || _customPickedLocation != null) &&
                    !_showItineraryPanel)
                  FloatingActionButton.extended(
                    onPressed: () => setState(() => _showItineraryPanel = true),
                    backgroundColor: const Color(0xFF2158F6),
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text(
                      "Itinerary",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
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

          // 4. BOUTON RECENTRER
          if (!_showItineraryPanel)
            Positioned(
              right: 18,
              bottom: 100,
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

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildSearchBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF245CF7), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search destinations...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
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
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Row(
        children: [
          Column(
            children: [
              const Icon(Icons.circle, size: 12, color: Color(0xFF2D2D44)),
              Container(height: 35, width: 1, color: Colors.grey.shade400),
              const Icon(Icons.location_on, size: 18, color: Colors.red),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              children: [
                _buildRouteInput(_originCtrl, Icons.my_location, "Origin"),
                const SizedBox(height: 10),
                _buildRouteInput(
                  _destinationCtrl,
                  Icons.close,
                  "Destination",
                  isDest: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _showItineraryPanel = false),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_vert, color: Color(0xFF2158F6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInput(
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    bool isDest = false,
  }) {
    return Container(
      height: 40,
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _filters[index];
          final selected = item == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2158F6)
                    : const Color(0xFFE8EEF5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  item,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF4D4E7A),
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
