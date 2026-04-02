import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lieu_model.dart';
import '../../theme/app_theme.dart';
import 'place_detail_screen.dart';

class LieuxMapScreen extends StatefulWidget {
  final List<LieuModel> lieux;
  final String? initialLieuId;

  const LieuxMapScreen({super.key, required this.lieux, this.initialLieuId});

  @override
  State<LieuxMapScreen> createState() => _LieuxMapScreenState();
}

class _LieuxMapScreenState extends State<LieuxMapScreen> {
  static const LatLng _fallbackCenter = LatLng(33.8076, 10.8451); // Djerba
  GoogleMapController? _controller;
  LieuModel? _selectedLieu;
  LatLng? _longPressedPoint;
  String? _pickerLieuId;

  List<LieuModel> get _mappableLieux => widget.lieux
      .where((l) => l.latitude != null && l.longitude != null)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (widget.initialLieuId != null) {
      final match = _mappableLieux.where((l) => l.id == widget.initialLieuId);
      if (match.isNotEmpty) {
        _selectedLieu = match.first;
        _pickerLieuId = match.first.id;
      }
    }
  }

  LatLng get _initialCenter {
    if (_mappableLieux.isEmpty) return _fallbackCenter;
    if (widget.initialLieuId != null) {
      final match = _mappableLieux.where((l) => l.id == widget.initialLieuId);
      if (match.isNotEmpty) {
        return LatLng(match.first.latitude!, match.first.longitude!);
      }
    }
    final first = _mappableLieux.first;
    return LatLng(first.latitude!, first.longitude!);
  }

  Set<Marker> get _markers {
    final markers = _mappableLieux.map((l) {
      final selected = _selectedLieu?.id == l.id;
      final hue = selected
          ? BitmapDescriptor.hueAzure
          : l.topDestination
          ? BitmapDescriptor.hueOrange
          : BitmapDescriptor.hueRed;
      return Marker(
        markerId: MarkerId(l.id),
        position: LatLng(l.latitude!, l.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: l.titre,
          snippet: l.sousTitre,
          onTap: () => _openDetail(l),
        ),
        onTap: () => _selectLieu(l, animate: false),
      );
    }).toSet();

    if (_longPressedPoint != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('long_press_point'),
          position: _longPressedPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Point selectionne'),
        ),
      );
    }
    return markers;
  }

  Future<void> _selectLieu(LieuModel lieu, {bool animate = true}) async {
    setState(() {
      _selectedLieu = lieu;
      _pickerLieuId = lieu.id;
      _longPressedPoint = null;
    });

    if (!animate || _controller == null) return;
    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lieu.latitude!, lieu.longitude!), 14),
    );
  }

  void _openDetail(LieuModel l) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: {
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
          },
        ),
      ),
    );
  }

  Future<void> _openItineraryToLatLng(LatLng point) async {
    final lat = point.latitude;
    final lng = point.longitude;

    final googleNavigationUri = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final directionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(googleNavigationUri)) {
      await launchUrl(
        googleNavigationUri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(directionsUri)) {
      await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  Future<void> _openDirectionsToSelectedLieu() async {
    final l = _selectedLieu;
    if (l == null || l.latitude == null || l.longitude == null) return;
    await _openItineraryToLatLng(LatLng(l.latitude!, l.longitude!));
  }

  Future<void> _focusOn(LieuModel l) async {
    if (l.latitude == null || l.longitude == null) return;
    await _selectLieu(l);
  }

  Widget _buildPickerCard(ColorScheme cs) {
    if (_mappableLieux.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Picker un lieu',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _pickerLieuId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline),
              ),
            ),
            hint: const Text('Choisir un lieu'),
            items: _mappableLieux
                .map(
                  (l) => DropdownMenuItem<String>(
                    value: l.id,
                    child: Text(
                      l.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              final match = _mappableLieux.where((l) => l.id == value);
              if (match.isNotEmpty) {
                _focusOn(match.first);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Carte des lieux')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: _mappableLieux.isEmpty ? 10 : 12,
            ),
            onMapCreated: (c) => _controller = c,
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapToolbarEnabled: false,
            onTap: (_) => setState(() {
              _selectedLieu = null;
              _pickerLieuId = null;
              _longPressedPoint = null;
            }),
            onLongPress: (point) => setState(() {
              _selectedLieu = null;
              _pickerLieuId = null;
              _longPressedPoint = point;
            }),
            markers: _markers,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(bottom: false, child: _buildPickerCard(cs)),
          ),
          if (_mappableLieux.isEmpty)
            Positioned(
              top: 86,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucun lieu geolocalise disponible.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedLieu != null)
            Positioned(
              left: 12,
              right: 12,
              top: 92,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedLieu!.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _selectedLieu = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedLieu!.categoryLabelFr,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Coordonnees: ${_selectedLieu!.latitude!.toStringAsFixed(6)}, ${_selectedLieu!.longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _openDirectionsToSelectedLieu,
                          icon: const Icon(Icons.alt_route, size: 16),
                          label: const Text('Itinéraire'),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () => _openDetail(_selectedLieu!),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Détails'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_longPressedPoint != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.place,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Point: ${_longPressedPoint!.latitude.toStringAsFixed(6)}, ${_longPressedPoint!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _longPressedPoint = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _openItineraryToLatLng(_longPressedPoint!),
                        icon: const Icon(Icons.alt_route, size: 16),
                        label: const Text('Itinéraire'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_mappableLieux.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (_, i) {
                    final l = _mappableLieux[i];
                    final selected = _selectedLieu?.id == l.id;
                    return GestureDetector(
                      onTap: () => _focusOn(l),
                      onDoubleTap: () => _openDetail(l),
                      child: Container(
                        width: 230,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.08)
                              : cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? AppColors.primary : cs.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: l.displayImage.isEmpty
                                    ? Container(color: Colors.grey.shade300)
                                    : Image.network(
                                        l.displayImage,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l.titre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l.categoryLabelFr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _mappableLieux.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
