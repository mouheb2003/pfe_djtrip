import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/ai_text_service.dart';
import '../../widgets/ai_image_generator_widget.dart';
import '../../widgets/place_search_widget.dart';
import '../../widgets/ai_text_widgets.dart';
import 'map_picker_screen.dart';
import 'interactive_djerba_map_screen.dart' as djerba_map;
import 'activity_preview_screen.dart';

class EditActivityScreen extends StatefulWidget {
  final ActivityModel activity;

  const EditActivityScreen({super.key, required this.activity});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late String? _category;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _locationCtrl;

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  double? _selectedDuration;
  int _customHours = 0;
  int _customMinutes = 30;
  LatLng? _pickedLatLng;

  late List<String> _existingPhotoUrls;
  final List<XFile> _newPhotos = [];
  String? _aiGeneratedImageUrl;

  bool _isLoading = false;
  bool _notifyBookedUsers = true;
  bool _notifyFollowers = false;
  bool _isProcessingAi = false;

  // Fixed location and itinerary state
  String? _selectedFixedLocation;
  bool _useFixedLocation = false;
  bool _useItinerary = false;
  final List<String> _itineraryItems = [];
  final List<String> _itineraryTitles = [];
  final List<Map<String, dynamic>> _itineraryLocations = [];
  late final TextEditingController _itineraryCtrl;

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

  Widget _buildAiActionButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return AiActionButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: _isProcessingAi ? null : onPressed,
    );
  }

  bool _isKnownFixedLocation(String? location) {
    final value = location?.trim() ?? '';
    return value.isNotEmpty && _fixedLocations.contains(value);
  }

  void _loadItineraryFromActivity(ActivityModel activity) {
    _itineraryItems.clear();
    _itineraryTitles.clear();
    _itineraryLocations.clear();

    final steps = activity.itineraireSteps ?? const <Map<String, dynamic>>[];
    for (final step in steps) {
      final title = (step['title'] ?? '').toString().trim();
      final description = (step['description'] ?? '').toString().trim();
      final location = <String, dynamic>{};

      final rawLocation = step['location'];
      if (rawLocation is Map) {
        location['address'] = rawLocation['address']?.toString() ?? '';
        location['lat'] = rawLocation['latitude'] ?? rawLocation['lat'];
        location['lng'] = rawLocation['longitude'] ?? rawLocation['lng'];
      } else {
        location['address'] = step['address']?.toString() ?? '';
        location['lat'] = step['lat'];
        location['lng'] = step['lng'];
      }

      _itineraryTitles.add(title);
      _itineraryItems.add(description);
      _itineraryLocations.add(location);
    }

    if (_itineraryItems.isEmpty &&
        (activity.itineraire ?? '').trim().isNotEmpty) {
      final lines = activity.itineraire!
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      for (final line in lines) {
        _itineraryTitles.add('');
        _itineraryItems.add(line);
        _itineraryLocations.add({});
      }
    }
  }

  Future<void> _rewriteFieldText(
    TextEditingController controller,
    String fieldType,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.rewriteText(
        text,
        type: _category,
        title: _titleCtrl.text.trim(),
        description: fieldType == 'description' ? _descCtrl.text.trim() : null,
      );

      if (!mounted) return;

      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        controller.text = result['result'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text rewritten successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to rewrite text'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to rewrite text. Please try again.'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _improveFieldText(
    TextEditingController controller,
    String fieldType,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.improveText(
        text,
        type: _category,
        title: _titleCtrl.text.trim(),
        description: fieldType == 'description' ? _descCtrl.text.trim() : null,
      );

      if (!mounted) return;

      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        controller.text = result['result'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text improved successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to improve text'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to improve text. Please try again.'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _translateFieldText(
    TextEditingController controller,
    String fieldType,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Show language selection dialog
    _showLanguageSelectionDialog(controller, text);
  }

  void _showLanguageSelectionDialog(
    TextEditingController controller,
    String text,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Select Translation Language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B2352),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose the language to translate this text to:',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: AiTextService.supportedLanguages.entries.map((
                        entry,
                      ) {
                        final langCode = entry.key;
                        final langName = entry.value;
                        return ListTile(
                          leading: Icon(
                            Icons.translate,
                            color: const Color(0xFF4B63FF),
                          ),
                          title: Text(langName),
                          onTap: () {
                            Navigator.of(context).pop();
                            _performTranslation(
                              controller,
                              text,
                              langCode,
                              langName,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performTranslation(
    TextEditingController controller,
    String text,
    String langCode,
    String langName,
  ) async {
    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.translateText(text, langCode);

      if (!mounted) return;

      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        controller.text = result['result'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Text translated to $langName'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to translate text'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to translate text. Please try again.'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    }
  }

  // Itinerary management methods
  void _addItineraryItem() {
    setState(() {
      _itineraryTitles.add('');
      _itineraryItems.add('');
      _itineraryLocations.add({});
    });
  }

  void _removeItineraryItem(int index) {
    setState(() {
      _itineraryTitles.removeAt(index);
      _itineraryItems.removeAt(index);
      _itineraryLocations.removeAt(index);
    });
  }

  void _updateItineraryTitle(int index, String value) {
    setState(() {
      _itineraryTitles[index] = value;
    });
  }

  void _updateItineraryItem(int index, String value) {
    setState(() {
      _itineraryItems[index] = value;
    });
  }

  void _updateItineraryLocation(int index, Map<String, dynamic> location) {
    setState(() {
      _itineraryLocations[index] = location;

      // Auto-fill title from location if title is empty
      if (_itineraryTitles[index].isEmpty && location['address'] != null) {
        // Extract place name from address (first part before comma)
        final address = location['address'].toString();
        final placeName = address.split(',').first.trim();
        _itineraryTitles[index] = placeName.isNotEmpty ? placeName : address;
      }
    });
  }

  Future<void> _pickLocationForItinerary(int index) async {
    final result = await Navigator.push<djerba_map.MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => djerba_map.InteractiveDjerbaMapScreen(
          initialPosition: _itineraryLocations[index]['lat'] != null
              ? LatLng(
                  _itineraryLocations[index]['lat'],
                  _itineraryLocations[index]['lng'],
                )
              : null,
        ),
      ),
    );

    if (result != null) {
      _updateItineraryLocation(index, {
        'lat': result.latLng.latitude,
        'lng': result.latLng.longitude,
        'address': result.address.isNotEmpty
            ? result.address
            : 'Location ${index + 1}',
      });
    }
  }

  static const _categories = [
    'Guided Tour',
    'Excursion',
    'Hiking',
    'Adventure',
    'Culture',
    'Gastronomy',
    'Sport',
    'Other',
  ];

  final List<String> _languages = [];
  final List<String> _includedEquipment = [];
  final List<String> _itemsToBring = [];

  @override
  void initState() {
    super.initState();
    final a = widget.activity;

    _titleCtrl = TextEditingController(text: a.titre);
    _category = _categories.contains(a.typeActivite) ? a.typeActivite : 'Other';
    _descCtrl = TextEditingController(text: a.description);
    _priceCtrl = TextEditingController(text: a.prix.toString());
    _capacityCtrl = TextEditingController(text: a.capaciteMax.toString());
    _locationCtrl = TextEditingController(text: a.lieu);
    _itineraryCtrl = TextEditingController(text: a.itineraire ?? '');

    final locationType = a.locationType?.trim().toLowerCase();
    final hasItineraryData =
        (a.itineraireSteps?.isNotEmpty ?? false) ||
        (a.itineraire ?? '').trim().isNotEmpty;

    if (locationType == 'itinerary' || hasItineraryData) {
      _useItinerary = true;
      _useFixedLocation = false;
      _selectedFixedLocation = null;
      _loadItineraryFromActivity(a);
      print('🔍 DEBUG EDIT INIT: Set to itinerary based on activity data');
    } else if (locationType == 'fixed' || _isKnownFixedLocation(a.lieu)) {
      _useFixedLocation = true;
      _useItinerary = false;
      _selectedFixedLocation = _isKnownFixedLocation(a.lieu) ? a.lieu : null;
      print('🔍 DEBUG EDIT INIT: Set to fixed location: ${a.lieu}');
    } else {
      _useFixedLocation = false;
      _useItinerary = false;
      _selectedFixedLocation = null;
      print('🔍 DEBUG EDIT INIT: Set to custom location (default)');
    }

    if (_useFixedLocation || !(_useFixedLocation || _useItinerary)) {
      if (a.coordonnees != null) {
        final point = a.coordonnees;
        final lat = point?['latitude'] ?? point?['lat'];
        final lng = point?['longitude'] ?? point?['lng'];
        if (lat is num && lng is num) {
          _pickedLatLng = LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    }

    _startDateTime = a.dateDebut;
    _endDateTime = a.dateFin;
    _existingPhotoUrls = List<String>.from(a.photos);

    if (!_useItinerary && !_useFixedLocation) {
      final point = a.coordonnees;
      if (point != null) {
        final lat = point['latitude'] ?? point['lat'];
        final lng = point['longitude'] ?? point['lng'];
        if (lat is num && lng is num) {
          _pickedLatLng = LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    }

    // Clean up stringified JSON for lists
    void cleanList(List<String> source, List<String> target) {
      for (var item in source) {
        if (item.startsWith('[') || item.startsWith('{')) {
          try {
            final parsed = item.replaceAll(RegExp(r"[\[\]']"), '').split(',');
            for (var p in parsed) {
              if (p.trim().isNotEmpty) target.add(p.trim());
            }
          } catch (_) {}
        } else {
          target.add(item);
        }
      }
    }

    cleanList(a.equipementsInclus, _includedEquipment);
    cleanList(a.aApporter, _itemsToBring);
    cleanList(a.languesDisponibles, _languages);

    // Duration handling
    final durationPresets = [1.0, 2.0, 3.0, 4.0];
    final preset = durationPresets.firstWhere(
      (p) => (p - a.duree).abs() < 0.01,
      orElse: () => -1.0,
    );
    if (preset != -1.0) {
      _selectedDuration = preset;
    } else {
      _selectedDuration = -1.0; // Custom
      _customHours = a.duree.floor();
      _customMinutes = ((a.duree - _customHours) * 60).round();
    }

    _recalcEndDate();
  }

  void _onAIImageGenerated(String imageUrl) {
    setState(() {
      _aiGeneratedImageUrl = imageUrl;
      _existingPhotoUrls.add(
        imageUrl,
      ); // Add to existing photos so it appears in gallery
      print('🤖 AI image generated in edit screen: $imageUrl');
      print('🤖 _existingPhotoUrls after adding: $_existingPhotoUrls');
    });
  }

  void _onImageDeleted(String imageUrl) {
    setState(() {
      _existingPhotoUrls.remove(imageUrl);
      // Also clear _aiGeneratedImageUrl if the deleted image matches
      if (_aiGeneratedImageUrl == imageUrl) {
        _aiGeneratedImageUrl = null;
      }
      print('🗑️ Image deleted: $imageUrl');
      print('🗑️ _existingPhotoUrls after delete: $_existingPhotoUrls');
      print('🗑️ _aiGeneratedImageUrl after delete: $_aiGeneratedImageUrl');
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _locationCtrl.dispose();
    _itineraryCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Not set' : DateFormat('MMM dd, yyyy').format(d);
  String _fmtFullDate(DateTime? d) =>
      d == null ? 'Not set' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  double _currentDurationHours() {
    if (_selectedDuration == -1.0) {
      return _customHours + _customMinutes / 60.0;
    }
    return _selectedDuration ?? 1.0;
  }

  void _recalcEndDate() {
    if (_startDateTime == null) return;
    final durationHours = _currentDurationHours();
    _endDateTime = _startDateTime!.add(
      Duration(minutes: (durationHours * 60).round()),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _newPhotos.addAll(picked));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _recalcEndDate();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate dates
    final creationDate = widget.activity.createdAt ?? DateTime.now();

    // Start date must be >= creation date
    if (_startDateTime != null && _startDateTime!.isBefore(creationDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity start date must be after the creation date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // End date must be > start date
    if (_startDateTime != null && _endDateTime != null) {
      if (_endDateTime!.isAtSameMomentAs(_startDateTime!) ||
          _endDateTime!.isBefore(_startDateTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity end date must be after the start date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final duree = _currentDurationHours();

    // Validate duration - must be at least 1 hour
    if (duree <= 0 || duree < 1) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity duration must be at least 1 hour'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final endDateTime =
        _endDateTime ??
        _startDateTime?.add(const Duration(hours: 1)) ??
        DateTime.now().add(const Duration(hours: 1));

    // Build location/itinerary data based on selection
    String lieu;
    List<Map<String, dynamic>>? itineraire;
    Map<String, dynamic>? coordonnees;

    // Declare itinerarySteps outside the if block so it's accessible later
    final itinerarySteps = <Map<String, dynamic>>[];

    if (_useItinerary) {
      // For itinerary, build structured itinerary data
      if (_itineraryItems.isNotEmpty) {
        for (int i = 0; i < _itineraryItems.length; i++) {
          final title = _itineraryTitles[i];
          final item = _itineraryItems[i];
          final location = _itineraryLocations[i];

          if (item.trim().isNotEmpty || title.trim().isNotEmpty) {
            final step = <String, dynamic>{
              'step': i + 1,
              'title': title.trim(),
              'description': item.trim(),
            };

            // Add location data if available
            if (location['address'] != null) {
              step['location'] = {
                'address': location['address'],
                'latitude': location['lat'],
                'longitude': location['lng'],
              };
            }

            itinerarySteps.add(step);
          }
        }

        if (itinerarySteps.isNotEmpty) {
          // Convert itinerary steps to formatted string
          itineraire = itinerarySteps.map((step) {
            return {
              'title': step['title'] ?? 'Step ${step['step']}',
              'description': step['description'] ?? '',
              'address': step['location']?['address'] ?? '',
              'lat': step['location']?['latitude'] ?? 0.0,
              'lng': step['location']?['longitude'] ?? 0.0,
              'order': step['step'] ?? 0,
            };
          }).toList();

          // Set lieu to a more descriptive text for multi-location itinerary
          if (itinerarySteps.first['location'] != null) {
            // Create a descriptive lieu that indicates multiple locations
            final firstLocation = itinerarySteps.first['location']['address'];
            final lastLocation =
                itinerarySteps.last['location']?['address'] ?? firstLocation;

            if (itinerarySteps.length > 1) {
              lieu = 'Multi-location tour: $firstLocation to $lastLocation';
            } else {
              lieu = firstLocation;
            }

            // Use first location for coordinates
            coordonnees = {
              'latitude': itinerarySteps.first['location']['latitude'],
              'longitude': itinerarySteps.first['location']['longitude'],
            };
          } else {
            lieu = 'Multi-location itinerary';
          }
        } else {
          // No itinerary items, use default
          lieu = 'Multi-location itinerary';
        }
      } else {
        // No itinerary items, use default
        lieu = 'Multi-location itinerary';
      }
    } else {
      // For fixed or custom location
      lieu = _locationCtrl.text.trim().isNotEmpty
          ? _locationCtrl.text.trim()
          : 'Location to be specified';
      coordonnees = _pickedLatLng != null
          ? {
              'latitude': _pickedLatLng!.latitude,
              'longitude': _pickedLatLng!.longitude,
            }
          : null;
    }

    // Build itineraire_coords from itinerarySteps if using itinerary
    List<Map<String, dynamic>>? itineraireCoords;
    if (_useItinerary && itinerarySteps.isNotEmpty) {
      itineraireCoords = itinerarySteps
          .where((step) => step['location'] != null)
          .map(
            (step) => {
              'lat': step['location']['latitude'],
              'lng': step['location']['longitude'],
              'address': step['location']['address'],
            },
          )
          .toList();
    }

    // Determine location type
    String locationType = 'fixed';
    print(
      '🔍 DEBUG EDIT: _useItinerary=$_useItinerary, _useFixedLocation=$_useFixedLocation',
    );
    if (_useItinerary) {
      locationType = 'itinerary';
      print('🔍 DEBUG EDIT: Set locationType to itinerary');
    } else if (!_useFixedLocation) {
      locationType = 'custom';
      print('🔍 DEBUG EDIT: Set locationType to custom');
    } else {
      print('🔍 DEBUG EDIT: Keeping locationType as fixed (default)');
    }
    print('🔍 DEBUG EDIT: FINAL Location type: $locationType');

    final result = await ActivityService.updateActivity(
      id: widget.activity.id,
      titre: _titleCtrl.text.trim(),
      typeActivite: _category ?? 'Other',
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: lieu,
      itineraire: itineraire,
      duree: duree,
      dateDebut: _startDateTime ?? DateTime.now(),
      dateFin: endDateTime,
      newPhotos: _newPhotos.map((x) => File(x.path)).toList(),
      aiGeneratedImageUrl: _aiGeneratedImageUrl,
      existingPhotoUrls: _existingPhotoUrls,
      languesDisponibles: _languages,
      equipementsInclus: _includedEquipment,
      aApporter: _itemsToBring,
      locationType: locationType,
      itineraireCoords: itineraireCoords,
      statut: widget.activity.statut,
      notifyBookedUsers: _notifyBookedUsers,
      notifyFollowers: _notifyFollowers,
      coordonnees: coordonnees,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity updated!')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error')));
      }
    }
  }

  Widget _buildLocationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4B63FF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4B63FF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF4B63FF)
                  : const Color(0xFF6B7280),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF4B63FF)
                          : const Color(0xFF131E32),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF4B63FF)
                          : const Color(0xFF717BBC),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4B63FF),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E9FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Itinerary Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF131E32),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add each step of your journey with location and description',
                style: TextStyle(fontSize: 12, color: Color(0xFF717BBC)),
              ),
              const SizedBox(height: 16),

              // Itinerary Items List
              ..._itineraryItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final title = _itineraryTitles[index];
                return _buildItineraryItem(index, title, item);
              }).toList(),

              // Add Item Button
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _addItineraryItem,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E9FF)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFF4B63FF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add Itinerary Item',
                        style: TextStyle(
                          color: Color(0xFF4B63FF),
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildItineraryItem(int index, String title, String item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E9FF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF4B63FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stop ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF131E32),
                  ),
                ),
              ),
              if (_itineraryItems.length > 1)
                GestureDetector(
                  onTap: () => _removeItineraryItem(index),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFFF4757),
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Location Title (auto-filled from place name)
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF131E32),
                    ),
                  ),
                  if (_itineraryLocations[index]['address'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _itineraryLocations[index]['address'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF717BBC),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

          // Description Field
          TextField(
            controller: TextEditingController(text: item),
            onChanged: (value) => _updateItineraryItem(index, value),
            decoration: InputDecoration(
              hintText: 'Describe this stop...',
              hintStyle: const TextStyle(color: Color(0xFF717BBC)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E9FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4B63FF)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF131E32)),
          ),
          const SizedBox(height: 8),

          // Location Picker
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickLocationForItinerary(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E9FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.map,
                          color: Color(0xFF4B63FF),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _itineraryLocations[index]['address'] ??
                                'Pick location on map',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _itineraryLocations[index]['address'] != null
                                  ? const Color(0xFF131E32)
                                  : const Color(0xFF717BBC),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Custom Header ──────────────────────────────────────
              _buildHeader(),
              // ── Main Content ────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    _buildTopInfo(),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Core Identity',
                      'The fundamental details that define your activity brand.',
                    ),
                    _buildCard([
                      _buildLabel('TITLE ENTREE *'),
                      _buildTextField(
                        _titleCtrl,
                        'Sunset Camel Trek in Djerba',
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('DESCRIPTION *'),
                      _buildTextField(
                        _descCtrl,
                        'Describe the magical experience users will have...',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 8),
                      // AI Action Buttons - only show when type and title exist
                      if (_category != null &&
                          _titleCtrl.text.trim().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Color(0xFF4A65E6),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'AI Assistant',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4A65E6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E9FF),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildAiActionButton(
                                    Icons.auto_fix_high,
                                    'Rewrite',
                                    () => _rewriteFieldText(
                                      _descCtrl,
                                      'description',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAiActionButton(
                                    Icons.spellcheck,
                                    'Improve',
                                    () => _improveFieldText(
                                      _descCtrl,
                                      'description',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAiActionButton(
                                    Icons.translate,
                                    'Translate',
                                    () => _translateFieldText(
                                      _descCtrl,
                                      'description',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'AI will use activity type and title to create the perfect description',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _buildLabel('ACTIVITY TYPE'),
                      _buildDropdown(),
                      // Difficulty level removed as requested
                    ]),
                    const SizedBox(height: 32),
                    const SizedBox(height: 20),
                    AIImageGeneratorWidget(
                      titleController: _titleCtrl,
                      descriptionController: _descCtrl,
                      onImageGenerated: _onAIImageGenerated,
                      onImageDeleted: _onImageDeleted,
                      existingImageUrls: _existingPhotoUrls,
                      category: _category,
                      showDebugInfo: false,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Media Gallery',
                      'Upload high-quality images to capture the Mediterranean essence.',
                    ),
                    _buildCard([_buildGallery()]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Logistics',
                      'Define the price, duration, and guest capacity.',
                    ),
                    _buildCard([
                      // Price and Capacity stacked vertically instead of side by side
                      _buildLabel('PRICE PER PERSON (TND)'),
                      _buildTextField(
                        _priceCtrl,
                        '45',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('MAX CAPACITY'),
                      _buildTextField(
                        _capacityCtrl,
                        '12',
                        keyboardType: TextInputType.number,
                        suffixIcon: Icons.people_outline,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Recommended: 1-50 people',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('LANGUAGES SUPPORTED'),
                      _buildLanguageChips(),
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Location & Itinerary',
                      'Choose between fixed location, custom location with map, or detailed itinerary.',
                    ),
                    _buildCard([
                      // Location Type Selection
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E9FF)),
                        ),
                        child: Column(
                          children: [
                            // Fixed Location Option
                            _buildLocationOption(
                              title: 'Fixed Location',
                              subtitle: 'Choose from predefined locations',
                              icon: Icons.location_on,
                              isSelected: _useFixedLocation && !_useItinerary,
                              onTap: () {
                                setState(() {
                                  _useFixedLocation = true;
                                  _useItinerary = false;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // Custom Location Option
                            _buildLocationOption(
                              title: 'Custom Location',
                              subtitle: 'Pick any location on the map',
                              icon: Icons.map,
                              isSelected: !_useFixedLocation && !_useItinerary,
                              onTap: () {
                                print(
                                  '🔍 DEBUG EDIT: Custom Location tapped - before: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary',
                                );
                                setState(() {
                                  _useFixedLocation = false;
                                  _useItinerary = false;
                                });
                                print(
                                  '🔍 DEBUG EDIT: Custom Location tapped - after: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary',
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Itinerary Option
                            _buildLocationOption(
                              title: 'Itinerary',
                              subtitle: 'Multi-location journey with waypoints',
                              icon: Icons.route,
                              isSelected: _useItinerary,
                              onTap: () {
                                setState(() {
                                  _useFixedLocation = false;
                                  _useItinerary = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Fixed Location Content
                      if (_useFixedLocation && !_useItinerary) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E9FF)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFixedLocation,
                              isExpanded: true,
                              hint: const Text(
                                'Select a fixed location',
                                style: TextStyle(color: Color(0xFF717BBC)),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Djerba Explore Park',
                                  child: Text('Djerba Explore Park'),
                                ),
                                DropdownMenuItem(
                                  value: 'Houmt Souk Medina',
                                  child: Text('Houmt Souk Medina'),
                                ),
                                DropdownMenuItem(
                                  value: 'Guellala Museum',
                                  child: Text('Guellala Museum'),
                                ),
                                DropdownMenuItem(
                                  value: 'Djerba Heritage Museum',
                                  child: Text('Djerba Heritage Museum'),
                                ),
                                DropdownMenuItem(
                                  value: 'Borj Ghazi Mustapha Fort',
                                  child: Text('Borj Ghazi Mustapha Fort'),
                                ),
                                DropdownMenuItem(
                                  value: 'Midoun Beach',
                                  child: Text('Midoun Beach'),
                                ),
                                DropdownMenuItem(
                                  value: 'Sidi Mahrsi Beach',
                                  child: Text('Sidi Mahrsi Beach'),
                                ),
                                DropdownMenuItem(
                                  value: 'Djerba Golf Club',
                                  child: Text('Djerba Golf Club'),
                                ),
                                DropdownMenuItem(
                                  value: 'Crocodile Farm',
                                  child: Text('Crocodile Farm'),
                                ),
                                DropdownMenuItem(
                                  value: 'Djerba Aqua Park',
                                  child: Text('Djerba Aqua Park'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedFixedLocation = value;
                                  _locationCtrl.text = value ?? '';
                                });
                              },
                            ),
                          ),
                        ),
                      ] else if (!_useFixedLocation && !_useItinerary) ...[
                        // Custom Location Content
                        PlaceSearchWidget(
                          controller: _locationCtrl,
                          hintText: 'Search for a place...',
                          onPlaceSelected: (place) {
                            setState(() {
                              if (place.latitude != null &&
                                  place.longitude != null) {
                                _pickedLatLng = LatLng(
                                  place.latitude!,
                                  place.longitude!,
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMapPreview(),
                      ] else if (_useItinerary) ...[
                        // Itinerary Content
                        _buildItinerarySection(),
                      ],
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Preparation',
                      'What you provide vs. what the guest needs to bring.',
                    ),
                    _buildCard([
                      _buildLabel('INCLUDED EQUIPMENT'),
                      _buildAddableList(
                        _includedEquipment,
                        'Add item...',
                        Icons.verified_rounded,
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('ITEMS TO BRING'),
                      _buildAddableList(
                        _itemsToBring,
                        'Add item...',
                        Icons.list_alt_rounded,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Availability',
                      'When is this activity available? Control the season start and end.',
                    ),
                    _buildCard([
                      _buildLabel('SEASON START DATE'),
                      _buildDatePicker(
                        _fmtFullDate(_startDateTime),
                        _pickDateTime,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('SEASON END DATE (AUTO-CALCULATED)'),
                      _buildDatePicker(
                        _fmtFullDate(_endDateTime),
                        null,
                        isDisabled: true,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('DURATION (HOURS)'),
                      _buildDurationChips(),
                    ]),
                    const SizedBox(height: 40),
                    _buildSaveButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildPreviewFab(),
    );
  }

  // ── Header Dashboard ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2452)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Text(
            'Edit Activity',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1B2452),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Color(0xFF4F67E8)),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildBadge(
              'ORGANIZER PORTAL',
              const Color(0xFFE0E7FF),
              const Color(0xFF3858C8),
            ),
            const SizedBox(width: 8),
            _buildBadge(
              'ACTIVE EXPERIENCE',
              const Color(0xFFFCE7F3),
              const Color(0xFFBE185D),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Edit Activity',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B2452),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Update your Mediterranean experience details. All changes will be updated instantly for future bookings.',
          style: TextStyle(fontSize: 14, color: Color(0xFF717BBC), height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('BOOKINGS', '${widget.activity.nombreReservations}'),
              _buildStat('LAST UPDATE', _fmtDate(widget.activity.updatedAt)),
              _buildStat(
                'STATUS',
                widget.activity.timelineStatus,
                isStatus: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, {bool isStatus = false}) {
    Color valColor = const Color(0xFF1B2452);
    if (isStatus) {
      final s = value.toLowerCase();
      if (s.contains('live') ||
          s.contains('available') ||
          s.contains('ongoing')) {
        valColor = const Color(0xFF10B981);
      } else if (s.contains('upcoming')) {
        valColor = const Color(0xFFF59E0B);
      } else if (s.contains('past') ||
          s.contains('completed') ||
          s.contains('archive')) {
        valColor = const Color(0xFF94A3B8);
      } else {
        valColor = const Color(0xFF717BBC);
      }
    }
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9EACCB),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStatus)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: valColor,
                  shape: BoxShape.circle,
                ),
              ),
            if (isStatus) const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: valColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Form Components ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2452),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF717BBC)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9EACCB),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? suffixIcon,
    IconData? prefixIcon,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9EACCB), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF3F3FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: const Color(0xFF717BBC))
            : null,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: const Color(0xFF3858C8))
            : null,
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          items: _categories
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _category = v),
        ),
      ),
    );
  }

  // ── Gallery ───────────────────────────────────────────────────────────────

  Widget _buildGallery() {
    final allImagesCount = _existingPhotoUrls.length + _newPhotos.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allImagesCount + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        if (i == allImagesCount) {
          return _buildUploadCard();
        }
        final isRemote = i < _existingPhotoUrls.length;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isRemote
                  ? Image.network(_existingPhotoUrls[i], fit: BoxFit.cover)
                  : Image.file(
                      File(_newPhotos[i - _existingPhotoUrls.length].path),
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() {
                  if (isRemote)
                    _existingPhotoUrls.removeAt(i);
                  else
                    _newPhotos.removeAt(i - _existingPhotoUrls.length);
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE0E7FF),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: Color(0xFF4F67E8),
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              'UPLOAD PHOTO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F67E8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Languages ──────────────────────────────────────────────────────────────

  Widget _buildLanguageChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._languages.map(
          (l) =>
              _buildChip(l, true, () => setState(() => _languages.remove(l))),
        ),
        _buildChip('+ Add', false, _showAddLanguage),
      ],
    );
  }

  Widget _buildChip(String label, bool isSel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFE0E7FF) : const Color(0xFFF3F3FF),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSel
                    ? const Color(0xFF3858C8)
                    : const Color(0xFF717BBC),
              ),
            ),
            if (isSel) const SizedBox(width: 4),
            if (isSel)
              const Icon(Icons.close, size: 14, color: Color(0xFF3858C8)),
          ],
        ),
      ),
    );
  }

  void _showAddLanguage() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Language'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'e.g. English'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final l = ctrl.text.trim();
              if (l.isNotEmpty && !_languages.contains(l)) {
                setState(() => _languages.add(l));
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Preparation ────────────────────────────────────────────────────────────

  Widget _buildAddableList(List<String> list, String hint, IconData icon) {
    final ctrl = TextEditingController();
    return Column(
      children: [
        ...list.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF3858C8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B2452),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => list.remove(item)),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: const Color(0xFF3858C8),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Add Item'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Water bottle',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (ctrl.text.trim().isNotEmpty)
                            setState(() => list.add(ctrl.text.trim()));
                          Navigator.pop(context);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Add item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3858C8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Map Preview ────────────────────────────────────────────────────────────

  Widget _buildMapPreview() {
    final latLng = _pickedLatLng;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFFF3F3FF),
            child: latLng != null
                ? Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: latLng,
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('m'),
                            position: latLng,
                          ),
                        },
                        liteModeEnabled: true,
                        zoomControlsEnabled: false,
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF717BBC),
                                ),
                              ),
                              const Text(
                                'Preview',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F67E8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Icon(
                      Icons.map_outlined,
                      color: Color(0xFF9EACCB),
                      size: 32,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            final dynamic result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => djerba_map.InteractiveDjerbaMapScreen(initialPosition: latLng),
              ),
            );

            if (result is MapPickerResult && mounted) {
              setState(() {
                _locationCtrl.text = result.address;
                _pickedLatLng = result.latLng;
              });
            }
          },
          icon: const Icon(Icons.map, size: 18),
          label: const Text(
            'Change Location on Map',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Date & Duration ───────────────────────────────────────────────────────

  Widget _buildDatePicker(
    String text,
    VoidCallback? onTap, {
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFF9FAFF) : const Color(0xFFF3F3FF),
          borderRadius: BorderRadius.circular(16),
          border: isDisabled
              ? Border.all(color: const Color(0xFFE2E9FF))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? const Color(0xFF9EACCB)
                    : const Color(0xFF1B2452),
              ),
            ),
            Icon(
              isDisabled
                  ? Icons.lock_outline_rounded
                  : Icons.calendar_today_outlined,
              size: 18,
              color: const Color(0xFF717BBC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChips() {
    final presets = [
      {'label': '2h', 'val': 2.0},
      {'label': 'Half Day', 'val': 4.0},
      {'label': 'Full Day', 'val': 8.0},
    ];
    return Column(
      children: [
        _buildTextField(
          TextEditingController(
            text:
                '${_selectedDuration == -1.0 ? _customHours : _selectedDuration} hours',
          ),
          'Duration',
          suffixIcon: Icons.schedule,
          readOnly: true,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((p) {
              final isSel = _selectedDuration == p['val'];
              return _buildChip(
                p['label'] as String,
                isSel,
                () => setState(() {
                  _selectedDuration = p['val'] as double;
                  _recalcEndDate();
                }),
              );
            }),
            _buildChip(
              '+ Custom',
              _selectedDuration == -1.0,
              _showCustomDurationPicker,
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomDurationPicker() {
    int tempH = _customHours == 0 && _customMinutes == 0 ? 2 : _customHours;
    int tempM = _customMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Set Custom Duration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2452),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempH = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  '$i h',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: tempH == i
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: tempH == i
                                        ? const Color(0xFF3858C8)
                                        : Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2452),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Minutes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempM = i * 5),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, i) {
                                final m = i * 5;
                                return Center(
                                  child: Text(
                                    '${m.toString().padLeft(2, '0')} min',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: tempM == m
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: tempM == m
                                          ? const Color(0xFF3858C8)
                                          : Colors.grey[400],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (tempH == 0 && tempM == 0) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedDuration = -1.0;
                      _customHours = tempH;
                      _customMinutes = tempM;
                      _recalcEndDate();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2452),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm Duration',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save Button ──────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    final bool isSaveDisabled = _isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notify booked users toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SwitchListTile(
            title: const Text(
              'Notify Booked Users',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B2352),
              ),
            ),
            subtitle: const Text(
              'Send notification to users who booked this activity',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            value: _notifyBookedUsers,
            onChanged: (value) {
              setState(() {
                _notifyBookedUsers = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ),
        // Notify followers toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SwitchListTile(
            title: const Text(
              'Notify Followers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B2352),
              ),
            ),
            subtitle: const Text(
              'Send notification to your followers about this activity update',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            value: _notifyFollowers,
            onChanged: (value) {
              setState(() {
                _notifyFollowers = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: isSaveDisabled ? Colors.grey[300] : const Color(0xFF1B2452),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSaveDisabled
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF1B2452).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: isSaveDisabled ? null : _save,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.save_outlined,
                          color: isSaveDisabled
                              ? Colors.grey[500]
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Save All Changes',
                          style: TextStyle(
                            color: isSaveDisabled
                                ? Colors.grey[600]
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewFab() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityPreviewScreen(
              title: _titleCtrl.text,
              category: _category ?? 'Other',
              description: _descCtrl.text,
              price: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
              capacity: int.tryParse(_capacityCtrl.text) ?? 1,
              location: _locationCtrl.text,
              duration: _currentDurationHours(),
              existingPhotos: _existingPhotoUrls,
              photos: _newPhotos,
              requirements: _includedEquipment,
              optional: _itemsToBring,
              startDateTime: _startDateTime,
              endDateTime: _endDateTime,
              pickedLatLng: _pickedLatLng,
              languages: _languages,
              durationLabel: _selectedDuration == -1.0
                  ? '${_customHours}h${_customMinutes > 0 ? ' ${_customMinutes}min' : ''}'
                  : '${_selectedDuration.toString().replaceAll('.0', '')}h',
            ),
          ),
        );
      },
      backgroundColor: const Color(0xFF3858C8),
      child: const Icon(Icons.visibility, color: Colors.white),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: textCol,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
