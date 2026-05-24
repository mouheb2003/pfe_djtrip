import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_text_service.dart';
import '../../widgets/ai_image_generator_widget.dart';
import '../../widgets/place_search_widget.dart';
import '../../widgets/ai_text_widgets.dart';
import 'activity_preview_screen.dart';
import 'map_picker_screen.dart';
import 'interactive_djerba_map_screen.dart' as djerba_map;
import '../../theme/app_theme.dart';

class _DurOption {
  final String label;
  final double hours;
  const _DurOption(this.label, this.hours);
}

const _kDurOptions = [
  _DurOption('2 HOURS', 2.0),
  _DurOption('4 HOURS', 4.0),
  _DurOption('HALF DAY', 4.0),
  _DurOption('FULL DAY', 8.0),
];

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core Identity
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _category;

  // Logistics
  final _priceCtrl = TextEditingController(text: '0.00');
  late final FocusNode _priceFocus = FocusNode();
  final _capacityCtrl = TextEditingController(text: '1');

  final List<String> _languages = ['English'];
  final _langCtrl = TextEditingController();

  // Media
  final List<XFile> _photos = [];
  String? _aiGeneratedImageUrl;

  // Preparation
  final List<String> _includedEquipment = [];
  final _incCtrl = TextEditingController();

  final List<String> _itemsToBring = [];
  final _bringCtrl = TextEditingController();

  // Location
  final _locationCtrl = TextEditingController();
  LatLng? _pickedLatLng;
  String? _selectedFixedLocation;
  final _itineraryCtrl = TextEditingController();
  bool _useFixedLocation = false;

  // Availability
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  _DurOption? _selectedDuration;
  int _customDays = 0;
  int _customHours = 0;
  int _customMinutes = 30;
  int _customSeconds = 0;
  bool _isCustomDuration = false;

  bool _isLoading = false;
  final bool _isPublish = true;
  bool _notifyFollowers = true;
  bool _isProcessingAi = false;

  // Location and itinerary state
  bool _useItinerary = false;
  final List<String> _itineraryItems = [];
  final List<Map<String, dynamic>> _itineraryLocations = [];

  Widget _buildAiActionButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return AiActionButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: _isProcessingAi ? null : onPressed,
    );
  }

  Future<void> _rewriteFieldText(TextEditingController controller, String fieldType) async {
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
        _showAiPreview(controller, text, result['result'], 'rewrite');
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

  Future<void> _improveFieldText(TextEditingController controller, String fieldType) async {
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
        _showAiPreview(controller, text, result['result'], 'improve');
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

  void _showAiPreview(TextEditingController controller, String original, String processed, String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AiTextPreviewDialog(
        originalText: original,
        processedText: processed,
        action: action,
        onAccept: () {
          Navigator.pop(context);
          setState(() {
            controller.text = processed;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'rewrite' ? 'Text rewritten' : 'Text improved',
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _translateFieldText(TextEditingController controller, String fieldType) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Show language selection dialog
    _showLanguageSelectionDialog(controller, text);
  }

  void _showLanguageSelectionDialog(TextEditingController controller, String text) {
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: AiTextService.supportedLanguages.entries.map((entry) {
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
                            _performTranslation(controller, text, langCode, langName);
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
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performTranslation(TextEditingController controller, String text, String langCode, String langName) async {
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
      // Auto-select itinerary option when adding items
      if (!_useItinerary) {
        _useItinerary = true;
        _useFixedLocation = false;
      }
      _itineraryItems.add('');
      _itineraryLocations.add({});
    });
  }

  void _removeItineraryItem(int index) {
    setState(() {
      _itineraryItems.removeAt(index);
      _itineraryLocations.removeAt(index);
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
    });
  }

  Future<void> _pickLocationForItinerary(int index) async {
    final result = await Navigator.push<djerba_map.MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => djerba_map.InteractiveDjerbaMapScreen(
          initialPosition: _itineraryLocations[index]['lat'] != null 
              ? LatLng(_itineraryLocations[index]['lat'], _itineraryLocations[index]['lng'])
              : null,
        ),
      ),
    );
    
    if (result is djerba_map.MapPickerResult) {
      _updateItineraryLocation(index, {
        'lat': result.latLng.latitude,
        'lng': result.latLng.longitude,
        'address': result.placeName.isNotEmpty ? result.placeName : result.address,
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

  static const Map<String, LatLng> _fixedLocationCoords = {
    'Djerba Explore Park': LatLng(33.8217, 11.0456),
    'Houmt Souk Medina': LatLng(33.8767, 10.8583),
    'Guellala Museum': LatLng(33.7317, 10.8583),
    'Djerba Heritage Museum': LatLng(33.8753, 10.8547),
    'Borj Ghazi Mustapha Fort': LatLng(33.8828, 10.8597),
    'Midoun Beach': LatLng(33.8167, 11.0167),
    'Sidi Mahrsi Beach': LatLng(33.8344, 10.9886),
    'Djerba Golf Club': LatLng(33.8239, 11.0261),
    'Crocodile Farm': LatLng(33.8217, 11.0456),
    'Djerba Aqua Park': LatLng(33.8258, 11.0381),
  };

  @override
  void initState() {
    super.initState();
    _priceFocus.addListener(() {
      if (_priceFocus.hasFocus && _priceCtrl.text == '0.00') {
        _priceCtrl.clear();
      } else if (!_priceFocus.hasFocus && _priceCtrl.text.isEmpty) {
        _priceCtrl.text = '0.00';
      }
    });
    
    // Initialize with no selection - user must explicitly choose
    print('🔍 DEBUG CREATE INIT: No location type selected initially');
    _useFixedLocation = false;
    _useItinerary = false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _langCtrl.dispose();
    _incCtrl.dispose();
    _bringCtrl.dispose();
    _locationCtrl.dispose();
    _itineraryCtrl.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _addLanguage(String l) {
    if (l.isEmpty || _languages.contains(l)) return;
    setState(() {
      _languages.add(l);
      _langCtrl.clear();
    });
  }

  Future<void> _showAddLanguagePrompt() async {
    final ctrl = TextEditingController();
    final lang = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Language'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'e.g. Spanish'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (lang != null && lang.isNotEmpty) {
      _addLanguage(lang);
    }
  }

  void _addEquipment(String eq) {
    if (eq.isEmpty) return;
    setState(() {
      _includedEquipment.add(eq);
      _incCtrl.clear();
    });
  }

  void _addItemToBring(String item) {
    if (item.isEmpty) return;
    setState(() {
      _itemsToBring.add(item);
      _bringCtrl.clear();
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked));
    }
  }

  void _onAIImageGenerated(String imageUrl) {
    setState(() {
      _aiGeneratedImageUrl = imageUrl;
      print('🤖 AI image generated in create screen: $imageUrl');
      // Add AI image to photos list so it's saved with the activity
      // Note: Since AI images are URLs, not local files, they'll be handled separately by the backend
    });
  }

  void _recalcEndDate() {
    if (_startDateTime != null) {
      if (_isCustomDuration) {
        // Custom duration with days, hours, minutes, seconds
        _endDateTime = _startDateTime!.add(Duration(
          days: _customDays,
          hours: _customHours,
          minutes: _customMinutes,
          seconds: _customSeconds,
        ));
      } else {
        final h = _selectedDuration?.hours ?? 3.0;
        _endDateTime = _startDateTime!.add(Duration(minutes: (h * 60).round()));
      }
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _startDateTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _startDateTime != null
            ? TimeOfDay.fromDateTime(_startDateTime!)
            : TimeOfDay.now(),
      );
      if (time != null) {
        final selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // Validate: activity start date must be >= creation date (current time)
        final now = DateTime.now();

        if (selectedDateTime.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Activity start date must be after the creation date'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _startDateTime = selectedDateTime;
          _recalcEndDate();
        });
      }
    }
  }

  void _openCustomDuration() {
    int tempD = _customDays;
    int tempH = _customHours;
    int tempM = _customMinutes;
    int tempS = _customSeconds;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Custom Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2352),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Format: days dd:hh:mm:ss',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Days
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempD,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempD = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 30, // Up to 29 days
                              builder: (ctx, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: tempD == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: tempD == i
                                        ? const Color(0xFF4A65E6)
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  // Hours
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Hrs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempH,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempH = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: tempH == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: tempH == i
                                        ? const Color(0xFF4A65E6)
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  // Minutes
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempM,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempM = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 60,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: tempM == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: tempM == i
                                        ? const Color(0xFF4A65E6)
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  // Seconds
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Sec',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempS,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempS = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 60,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: tempS == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: tempS == i
                                        ? const Color(0xFF4A65E6)
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
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
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (tempD == 0 && tempH == 0 && tempM == 0 && tempS == 0) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _customDays = tempD;
                      _customHours = tempH;
                      _customMinutes = tempM;
                      _customSeconds = tempS;
                      _isCustomDuration = true;
                      _selectedDuration = null;
                      _recalcEndDate();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A65E6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Season Start Date is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate dates
    final now = DateTime.now();
    
    // Start date must be >= creation date
    if (_startDateTime!.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity start date must be after the creation date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // End date must be > start date
    final endDateTime = _endDateTime ?? _startDateTime!.add(const Duration(hours: 3));
    if (endDateTime.isAtSameMomentAs(_startDateTime!) || endDateTime.isBefore(_startDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity end date must be after the start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final double durationHours = _isCustomDuration
        ? (_customDays * 24) + _customHours + (_customMinutes / 60.0) + (_customSeconds / 3600.0)
        : (_selectedDuration?.hours ?? 3.0);

    // Validate duration - must be at least 1 hour
    if (durationHours <= 0 || durationHours < 1) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity duration must be at least 1 hour'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Smart validation based on actual data state
    final hasItineraryItems = _itineraryItems.isNotEmpty;
    final hasCustomLocation = _pickedLatLng != null || _locationCtrl.text.trim().isNotEmpty;
    final hasFixedLocation = _selectedFixedLocation != null;
    
    print('🔍 VALIDATION DEBUG: hasItineraryItems=$hasItineraryItems, hasCustomLocation=$hasCustomLocation, hasFixedLocation=$hasFixedLocation');
    
    // If user has itinerary items, validate itinerary requirements
    if (hasItineraryItems) {
      bool hasValidLocations = true;
      for (int i = 0; i < _itineraryItems.length; i++) {
        if (_itineraryItems[i].trim().isEmpty) {
          hasValidLocations = false;
          break;
        }
      }
      
      if (!hasValidLocations) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all itinerary step descriptions'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    // If no itinerary items, require either fixed or custom location
    else if (!hasCustomLocation && !hasFixedLocation) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide location details (fixed, custom, or itinerary)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Additional validation for specific types
    if (_useFixedLocation && _selectedFixedLocation == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a fixed location from the dropdown'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_useFixedLocation && !hasItineraryItems && _pickedLatLng == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a location on the map for custom location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Build location/itinerary data based on selection
    String lieu;
    List<Map<String, dynamic>>? itineraire;
    Map<String, dynamic>? coordonnees;
    
    // DEBUG: Print itinerary state
    print('🔍 [CREATE ACTIVITY] DEBUG INFO:');
    print('🔍 _useItinerary: $_useItinerary');
    print('🔍 _itineraryItems.length: ${_itineraryItems.length}');
    print('🔍 _itineraryItems: $_itineraryItems');
    print('🔍 _itineraryLocations.length: ${_itineraryLocations.length}');
    print('🔍 _itineraryLocations: $_itineraryLocations');
    
    // Declare itinerarySteps outside the if block so it's accessible later
    final itinerarySteps = <Map<String, dynamic>>[];
    
    // Only process itinerary if explicitly selected OR if we have items (auto-detect)
    if (_useItinerary || _itineraryItems.isNotEmpty) {
      // For itinerary, build structured itinerary data
      if (_itineraryItems.isNotEmpty) {
        for (int i = 0; i < _itineraryItems.length; i++) {
          final item = _itineraryItems[i];
          final location = _itineraryLocations[i];
          
          print('🔍 Processing item $i: "$item"');
          print('🔍 Processing location $i: $location');
          
                    
          if (item.trim().isNotEmpty) {
            final step = <String, dynamic>{
              'step': i + 1,
              'description': item.trim(),
            };
            
            // Add location data if available
            if (location['address'] != null) {
              step['location'] = {
                'address': location['address'],
                'latitude': location['lat'],
                'longitude': location['lng'],
              };
              print('🔍 Added location to step: ${step['location']}');
            }
            
            itinerarySteps.add(step);
            print('🔍 Added step: $step');
          } else {
            print('🔍 Skipped empty item: "$item"');
          }
        }
        
        print('🔍 Total itinerarySteps: ${itinerarySteps.length}');
        
        if (itinerarySteps.isNotEmpty) {
          // Convert itinerary items to structured array
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
          
          print('🔍 Generated structured itineraire: $itineraire');
          
          // Set lieu to a more descriptive text for multi-location itinerary
          if (itinerarySteps.first['location'] != null) {
            // Create a descriptive lieu that indicates multiple locations
            final firstLocation = itinerarySteps.first['location']['address'];
            final lastLocation = itinerarySteps.last['location']?['address'] ?? firstLocation;
            
            if (itinerarySteps.length > 1) {
              lieu = 'Multi-location tour: $firstLocation to $lastLocation';
            } else {
              lieu = firstLocation;
            }
            
            // Don't set coordonnees for itinerary - let backend handle it
            coordonnees = null;
            print('🔍 Set lieu for multi-location: "$lieu"');
          } else {
            lieu = 'Multi-location itinerary';
            print('🔍 Set lieu to default: "$lieu"');
          }
        } else {
          // No itinerary items, use default
          lieu = 'Multi-location itinerary';
          print('🔍 No valid steps, set lieu to default: "$lieu"');
        }
      } else {
        // No itinerary items, use default
        lieu = 'Multi-location itinerary';
        print('🔍 No itinerary items, set lieu to default: "$lieu"');
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
      print('🔍 Not using itinerary, set lieu: "$lieu"');
    }
    
    print('🔍 FINAL VALUES - lieu: "$lieu", itineraire: "$itineraire"');

    // Remove itineraire_coords - now handled by backend
    // The backend will process the structured itineraire array
    print('🔍 Backend will handle itineraire_coords from structured itineraire');

    // Determine location type - SMART detection based on actual data
    String locationType;
    print('🔍 DEBUG: _useItinerary=$_useItinerary, _useFixedLocation=$_useFixedLocation');
    print('🔍 DEBUG: _itineraryItems.length=${_itineraryItems.length}');
    
    // Priority 1: If user explicitly selected itinerary mode
    if (_useItinerary) {
      locationType = 'itinerary';
      print('🔍 DEBUG: Set locationType to itinerary (explicit selection)');
    }
    // Priority 2: If user selected fixed location
    else if (_useFixedLocation) {
      locationType = 'fixed';
      print('🔍 DEBUG: Set locationType to fixed (explicit selection)');
    }
    // Priority 3: Default to custom if nothing else selected
    else {
      locationType = 'custom';
      print('🔍 DEBUG: Set locationType to custom (default)');
    }
    print('🔍 FINAL Location type: $locationType');

    final result = await ActivityService.createActivity(
      titre: _titleCtrl.text.trim(),
      typeActivite: _category ?? 'Other',
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: lieu,
      locationType: locationType,
      itineraire: itineraire,
      duree: durationHours,
      dateDebut: _startDateTime!,
      dateFin: endDateTime,
      photos: _photos.map((x) => File(x.path)).toList(),
      aiGeneratedImageUrl: _aiGeneratedImageUrl,
      equipementsInclus: List.from(_includedEquipment),
      aApporter: List.from(_itemsToBring),
      languesDisponibles: List.from(_languages),
      statut: _isPublish ? 'active' : 'inactive',
      coordonnees: coordonnees,
      notifyFollowers: _notifyFollowers,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAppBar(isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    _buildTopHeader(isDark),
                    const SizedBox(height: 30),
                    _buildAvailability(isDark),
                    const SizedBox(height: 30),
                    _buildCoreIdentity(isDark),
                    const SizedBox(height: 30),
                    _buildMediaGallery(isDark),
                    const SizedBox(height: 30),
                    _buildLogistics(isDark),
                    const SizedBox(height: 30),
                    _buildLocation(isDark),
                    const SizedBox(height: 30),
                    _buildPreparation(isDark),
                    const SizedBox(height: 100), // Padding for bottom bar buttons only
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildBottomBar(isDark),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : const Color(0xFF2E3192),
              size: 18,
            ),
            label: Text(
              'Activity Details',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF2E3192),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Info button removed as requested
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2E5E) : const Color(0xFFE2E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ORGANIZER PORTAL',
                style: TextStyle(
                  color: isDark ? const Color(0xFF1A7FFF) : const Color(0xFF4A65E6),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF5E1E3F) : const Color(0xFFFFE4EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NEW ACTIVITY',
                style: TextStyle(
                  color: Color(0xFFE04987),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Create New Activity',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1B2352),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Define your Mediterranean experience. Fields marked with an asterisk are required to publish.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[450] : const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetric(
                'CREATED',
                DateFormat('MMM dd, yyyy').format(DateTime.now()),
                isDark,
              ),
              Container(width: 1, height: 30, color: isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]),
              _buildMetric('STATUS', 'Draft', isDark, isDraft: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String val, bool isDark, {bool isDraft = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[500] : Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (isDraft)
              Container(
                margin: const EdgeInsets.only(right: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              ),
            Text(
              val,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1B2352),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B2352),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCoreIdentity(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Core Identity',
          "The fundamental details that define your activity's brand.",
          isDark,
        ),
        _buildTextField(
          'TITLE (EN/FR) *',
          'e.g. Sunset Kayaking in Blue Grotto',
          _titleCtrl,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'DESCRIPTION *',
          'Describe the magical experience users will have...',
          _descCtrl,
          maxLines: 5,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        // AI Action Buttons - only show when type and title exist
        if (_category != null && _titleCtrl.text.trim().isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4A65E6)),
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
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E9FF)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildAiActionButton(Icons.auto_fix_high, 'Rewrite', () => _rewriteFieldText(_descCtrl, 'description')),
                    const SizedBox(width: 8),
                    _buildAiActionButton(Icons.spellcheck, 'Improve', () => _improveFieldText(_descCtrl, 'description')),
                    const SizedBox(width: 8),
                    _buildAiActionButton(Icons.translate, 'Translate', () => _translateFieldText(_descCtrl, 'description')),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI will use activity type and title to create the perfect description',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'ACTIVITY TYPE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _category,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1B2352),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          hint: Text(
            'Select category',
            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
          ),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v),
        ),
        // Difficulty level removed as requested
        const SizedBox(height: 20),
        AIImageGeneratorWidget(
          titleController: _titleCtrl,
          descriptionController: _descCtrl,
          onImageGenerated: _onAIImageGenerated,
          existingPhotos: _photos,
          category: _category,
          showDebugInfo: false, // Set to true for development/debugging
        ),
      ],
    );
  }

  Widget _buildMediaGallery(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Media Gallery',
          'Upload high-quality images to capture the Mediterranean essence.',
          isDark,
        ),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Display AI generated image if available
              if (_aiGeneratedImageUrl != null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4A65E6),
                      width: 3,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(_aiGeneratedImageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A65E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => setState(() => _aiGeneratedImageUrl = null),
                        ),
                      ),
                    ],
                  ),
                ),
              ..._photos.map(
                (p) => Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(p.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _photos.remove(p)),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1.5,
                      style: BorderStyle.none,
                    ),
                  ), // Placeholder for dotted
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.blue,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UPLOAD PHOTO',
                        style: TextStyle(
                          color: Colors.blue[300],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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

  Widget _buildLogistics(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Logistics',
            'Setting the price, duration, and guest capacity.',
            isDark,
          ),
          _buildTextField(
            'PRICE PER PERSON (TND)',
            '0.00',
            _priceCtrl,
            icon: Padding(
              padding: const EdgeInsets.only(top: 15, left: 15),
              child: Text(
                'TND',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : const Color(0xFF5E6582),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            focus: _priceFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                'MAX CAPACITY',
                'e.g. 12',
                _capacityCtrl,
                suffixIcon: Icon(
                  Icons.people_outline,
                  color: isDark ? Colors.grey[400] : const Color(0xFF5E6582),
                  size: 18,
                ),
                keyboardType: TextInputType.number,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              Text(
                'Recommended: 1-50 people for optimal experience',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'LANGUAGES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._languages.map(
                (l) => Chip(
                  label: Text(
                    l,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF4A65E6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E2E5E) : const Color(0xFFE2E9FF),
                  side: BorderSide.none,
                  onDeleted: () => setState(() => _languages.remove(l)),
                  deleteIconColor: isDark ? Colors.white : const Color(0xFF4A65E6),
                ),
              ),
              ActionChip(
                label: Text(
                  '+ ADD',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4FE),
                side: BorderSide.none,
                onPressed: _showAddLanguagePrompt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Location & Itinerary',
          'Choose between fixed location, custom location with map, or detailed itinerary.',
          isDark,
        ),
        
        // Location Type Selection - MANDATORY
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E9FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location Type *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF131E32),
                ),
              ),
              const SizedBox(height: 12),
              // Fixed Location Option
              _buildLocationOption(
                title: 'Fixed Location',
                subtitle: 'Choose from predefined locations (beach, museum, etc.)',
                icon: Icons.location_on,
                isSelected: _useFixedLocation && !_useItinerary,
                onTap: () {
                  print('🔍 DEBUG: Fixed Location tapped - before: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                  setState(() {
                    _useFixedLocation = true;
                    _useItinerary = false;
                  });
                  print('🔍 DEBUG: Fixed Location tapped - after: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                },
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              // Custom Location Option
              _buildLocationOption(
                title: 'Custom Location',
                subtitle: 'Pick any location on the map (your choice)',
                icon: Icons.map,
                isSelected: !_useFixedLocation && !_useItinerary,
                onTap: () {
                  print('🔍 DEBUG: Custom Location tapped - before: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                  setState(() {
                    _useFixedLocation = false;
                    _useItinerary = false;
                  });
                  print('🔍 DEBUG: Custom Location tapped - after: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                },
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              // Itinerary Option
              _buildLocationOption(
                title: 'Itinerary',
                subtitle: 'Multi-location journey with waypoints (2+ locations)',
                icon: Icons.route,
                isSelected: _useItinerary,
                onTap: () {
                  print('🔍 DEBUG: Itinerary tapped - before: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                  setState(() {
                    _useFixedLocation = false;
                    _useItinerary = true;
                  });
                  print('🔍 DEBUG: Itinerary tapped - after: _useFixedLocation=$_useFixedLocation, _useItinerary=$_useItinerary');
                },
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              // Selection Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2E5E) : const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD1D5DB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getSelectionStatus(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E9FF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFixedLocation,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1B2352),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      hint: Text(
                        'Select a fixed location',
                        style: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF717BBC)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Djerba Explore Park', child: Text('Djerba Explore Park')),
                        DropdownMenuItem(value: 'Houmt Souk Medina', child: Text('Houmt Souk Medina')),
                        DropdownMenuItem(value: 'Guellala Museum', child: Text('Guellala Museum')),
                        DropdownMenuItem(value: 'Djerba Heritage Museum', child: Text('Djerba Heritage Museum')),
                        DropdownMenuItem(value: 'Borj Ghazi Mustapha Fort', child: Text('Borj Ghazi Mustapha Fort')),
                        DropdownMenuItem(value: 'Midoun Beach', child: Text('Midoun Beach')),
                        DropdownMenuItem(value: 'Sidi Mahrsi Beach', child: Text('Sidi Mahrsi Beach')),
                        DropdownMenuItem(value: 'Djerba Golf Club', child: Text('Djerba Golf Club')),
                        DropdownMenuItem(value: 'Crocodile Farm', child: Text('Crocodile Farm')),
                        DropdownMenuItem(value: 'Djerba Aqua Park', child: Text('Djerba Aqua Park')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedFixedLocation = value;
                          _locationCtrl.text = value ?? '';
                          if (value != null && _fixedLocationCoords.containsKey(value)) {
                            _pickedLatLng = _fixedLocationCoords[value];
                            print('📍 Set coordinates for fixed location: $value -> $_pickedLatLng');
                          }
                        });
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.map_outlined, color: AppColors.primary),
                  onPressed: () async {
                    final result = await Navigator.push<djerba_map.MapPickerResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => djerba_map.InteractiveDjerbaMapScreen(
                          initialPosition: _pickedLatLng,
                        ),
                      ),
                    );
                    if (result is djerba_map.MapPickerResult && mounted) {
                      setState(() {
                        _locationCtrl.text = result.placeName;
                        _pickedLatLng = result.latLng;
                        if (_fixedLocations.contains(result.placeName)) {
                          _selectedFixedLocation = result.placeName;
                        } else {
                          // If picked from map and not in fixed, switch to custom? 
                          // Or just set it. 
                          _selectedFixedLocation = null;
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
        
        // Custom Location Content
        if (!_useFixedLocation && !_useItinerary) ...[
          PlaceSearchWidget(
            controller: _locationCtrl,
            hintText: 'Search for a place...',
            onPlaceSelected: (place) {
              setState(() {
                if (place.latitude != null && place.longitude != null) {
                  _pickedLatLng = LatLng(
                    place.latitude!,
                    place.longitude!,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push<djerba_map.MapPickerResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => djerba_map.InteractiveDjerbaMapScreen(initialPosition: _pickedLatLng),
                ),
              );
              if (result is djerba_map.MapPickerResult && mounted) {
                setState(() {
                  _locationCtrl.text = result.placeName;
                  _pickedLatLng = result.latLng;
                });
              }
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF131E32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  if (_pickedLatLng != null)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _pickedLatLng!,
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('m'),
                          position: _pickedLatLng!,
                        ),
                      },
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      mapType: MapType.normal,
                    ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pickedLatLng == null
                                  ? 'Pin location on map'
                                  : '${_pickedLatLng!.latitude.toStringAsFixed(4)}, ${_pickedLatLng!.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          const Text(
                            'PIN CHECK',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        
        // Itinerary Content
        if (_useItinerary) ...[
          _buildItinerarySection(isDark),
        ],
      ],
    );
  }

  Widget _buildLocationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4B63FF).withOpacity(0.1) : Colors.transparent,
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
              color: isSelected ? const Color(0xFF4B63FF) : (isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
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
                      color: isSelected ? const Color(0xFF4B63FF) : (isDark ? Colors.white : const Color(0xFF131E32)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF4B63FF) : (isDark ? Colors.grey[400] : const Color(0xFF717BBC)),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4B63FF),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to get selection status text
  String _getSelectionStatus() {
    if (_useItinerary) {
      return ' Itinerary selected - Multi-location journey will be created';
    } else if (_useFixedLocation) {
      return ' Fixed location selected - Predefined location will be used';
    } else if (!_useFixedLocation && !_useItinerary) {
      return ' Custom location selected - Map location will be used';
    } else {
      return ' Please select a location type above';
    }
  }

  Widget _buildItinerarySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E9FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Itinerary Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF131E32),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add each step of your journey with location and description',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[450] : const Color(0xFF717BBC),
                ),
              ),
              const SizedBox(height: 16),
              
              // Itinerary Items List
              ..._itineraryItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItineraryItem(index, item, isDark);
              }).toList(),
              
              // Add Item Button
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _addItineraryItem,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E9FF)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        color: Color(0xFF4B63FF),
                        size: 20,
                      ),
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

  Widget _buildItineraryItem(int index, String item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E9FF)),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stop ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF131E32),
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
          
          // Description Field
          TextField(
            onChanged: (value) => _updateItineraryItem(index, value),
            decoration: InputDecoration(
              hintText: 'Describe this stop...',
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF717BBC)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E9FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4B63FF)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF131E32),
            ),
          ),
          const SizedBox(height: 8),
          
          // Location Picker
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _pickLocationForItinerary(index),
                  decoration: InputDecoration(
                    hintText: _itineraryLocations[index]['address'] ?? 'Pick location on map',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF717BBC)),
                    prefixIcon: const Icon(
                      Icons.map,
                      color: Color(0xFF4B63FF),
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E9FF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4B63FF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF131E32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreparation(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Preparation',
          'What you provide vs. what the guest needs to bring.',
          isDark,
        ),
        _buildPrepList(
          'INCLUDED EQUIPMENT',
          _includedEquipment,
          (v) => _addEquipment(v),
          (v) => setState(() => _includedEquipment.remove(v)),
          _incCtrl,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildPrepList(
          'ITEMS TO BRING (A APPORTER)',
          _itemsToBring,
          (v) => _addItemToBring(v),
          (v) => setState(() => _itemsToBring.remove(v)),
          _bringCtrl,
          isDark,
        ),
      ],
    );
  }

  Widget _buildPrepList(
    String title,
    List<String> items,
    Function(String) onAdd,
    Function(String) onRemove,
    TextEditingController ctrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFF4A65E6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemove(i),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey,
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
                color: isDark ? Colors.grey[400] : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add item...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey),
                  ),
                  onSubmitted: onAdd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Availability',
          'When is this activity available? Choose the season start and duration.',
          isDark,
        ),
        _buildLabel('START DATE', isDark),
        GestureDetector(
          onTap: _pickStartDate,
          child: _dateContainer(
            _startDateTime != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(_startDateTime!)
                : 'Select Start Date...',
            _startDateTime != null,
            isDark,
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('END DATE (AUTO-CALCULATED)', isDark),
        _dateContainer(
          _startDateTime != null && _endDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(_endDateTime!)
              : 'Auto calculated after start date...',
          _startDateTime != null,
          isDark,
          disabled: true,
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 16),
        Text(
          'DURATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[450] : Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(
                _isCustomDuration
                    ? '${_customDays > 0 ? '${_customDays}d ' : ''}${_customHours.toString().padLeft(2, '0')}:${_customMinutes.toString().padLeft(2, '0')}:${_customSeconds.toString().padLeft(2, '0')}'
                    : (_selectedDuration?.label ?? 'Select'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B2352),
                ),
              ),
              const Spacer(),
              Icon(Icons.timer, color: isDark ? Colors.grey[400] : const Color(0xFF5E6582), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _kDurOptions
                  .map(
                    (opt) => GestureDetector(
                      onTap: () => setState(() {
                        _selectedDuration = opt;
                        _isCustomDuration = false;
                        _recalcEndDate();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedDuration == opt
                              ? (isDark ? const Color(0xFF1E2E5E) : const Color(0xFFE2E9FF))
                              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4FE),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            color: _selectedDuration == opt
                                ? (isDark ? Colors.white : const Color(0xFF4A65E6))
                                : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList()
                ..add(
                  GestureDetector(
                    onTap: _openCustomDuration,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isCustomDuration
                            ? (isDark ? const Color(0xFF1E2E5E) : const Color(0xFFE2E9FF))
                            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4FE),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CUSTOM',
                        style: TextStyle(
                          color: _isCustomDuration
                              ? (isDark ? Colors.white : const Color(0xFF4A65E6))
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        // Notify followers section moved here (under Duration)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4FE), width: 2),
          ),
          child: SwitchListTile(
            title: Text(
              'Notify Followers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1B2352),
              ),
            ),
            subtitle: Text(
              'Send notification to your followers about this new activity',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey),
            ),
            value: _notifyFollowers,
            onChanged: (value) {
              setState(() {
                _notifyFollowers = value;
              });
            },
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF4A65E6),
          ),
        ),
      ],
    );
  }

  
  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController? ctrl, {
    int maxLines = 1,
    Widget? icon,
    Widget? suffixIcon,
    FocusNode? focus,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          focusNode: focus,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1B2352),
          ),
          validator: (v) =>
              label.contains('*') && (v == null || v.trim().isEmpty)
              ? 'Required'
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4FE),
            prefixIcon: icon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityPreviewScreen(
                              title: _titleCtrl.text.trim(),
                              category: _category ?? 'Other',
                              description: _descCtrl.text.trim(),
                              price: double.tryParse(_priceCtrl.text) ?? 0,
                              capacity: int.tryParse(_capacityCtrl.text) ?? 0,
                              location: _locationCtrl.text.trim(),
                              duration: _isCustomDuration
                                  ? (_customDays * 24) + _customHours + (_customMinutes / 60.0) + (_customSeconds / 3600.0)
                                  : (_selectedDuration?.hours ?? 3.0),
                              durationLabel: _selectedDuration?.label ?? 'Custom',
                              startDateTime: _startDateTime,
                              endDateTime: _endDateTime,
                              photos: List.from(_photos),
                              existingPhotos: _aiGeneratedImageUrl != null ? [_aiGeneratedImageUrl!] : const [],
                              requirements: List.from(_includedEquipment),
                              optional: List.from(_itemsToBring),
                              pickedLatLng: _pickedLatLng,
                              languages: List.from(_languages),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.remove_red_eye_rounded,
                        color: isDark ? Colors.white : const Color(0xFF4A65E6),
                        size: 18,
                      ),
                      label: Text(
                        'Preview',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF4A65E6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4FE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, color: Colors.white, size: 18),
                      label: const Text(
                        'Publish',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF4A65E6) : const Color(0xFF0F1535),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
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

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _dateContainer(
    String text,
    bool hasValue,
    bool isDark, {
    bool disabled = false,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: disabled 
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9)) 
            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4FE)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue && !disabled
              ? const Color(0xFF4A65E6).withOpacity(0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue 
                    ? (isDark ? Colors.white : const Color(0xFF1B2352)) 
                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
              ),
            ),
          ),
          Icon(
            icon ?? Icons.calendar_today_outlined,
            size: 18,
            color: hasValue && !disabled
                ? const Color(0xFF4A65E6)
                : Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
