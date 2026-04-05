import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/activity_service.dart';
import 'activity_preview_screen.dart';
import 'map_picker_screen.dart';

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
  String _difficultyLevel = 'Moderate';

  // Logistics
  final _priceCtrl = TextEditingController(text: '0.00');
  late final FocusNode _priceFocus = FocusNode();
  final _capacityCtrl = TextEditingController();

  final List<String> _languages = ['English'];
  final _langCtrl = TextEditingController();

  // Media
  final List<XFile> _photos = [];

  // Preparation
  final List<String> _includedEquipment = [];
  final _incCtrl = TextEditingController();

  final List<String> _itemsToBring = [];
  final _bringCtrl = TextEditingController();

  // Location
  final _locationCtrl = TextEditingController();
  LatLng? _pickedLatLng;

  // Availability
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  _DurOption? _selectedDuration;
  int _customHours = 0;
  int _customMinutes = 30;
  bool _isCustomDuration = false;

  bool _isLoading = false;
  final bool _isPublish = true;

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

  void _recalcEndDate() {
    if (_startDateTime != null) {
      final h = _isCustomDuration
          ? (_customHours + _customMinutes / 60.0)
          : (_selectedDuration?.hours ?? 3.0);
      _endDateTime = _startDateTime!.add(Duration(minutes: (h * 60).round()));
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
    }
  }

  void _openCustomDuration() {
    int tempH = _customHours;
    int tempM = _customMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
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
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
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
                                  '$i h',
                                  style: TextStyle(
                                    fontSize: 22,
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
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Minutes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempM ~/ 5,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempM = i * 5),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, i) {
                                final mins = i * 5;
                                return Center(
                                  child: Text(
                                    '${mins.toString().padLeft(2, '0')} min',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: tempM == mins
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: tempM == mins
                                          ? const Color(0xFF4A65E6)
                                          : Colors.grey[500],
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (tempH == 0 && tempM == 0) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _customHours = tempH;
                      _customMinutes = tempM;
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

    setState(() => _isLoading = true);

    final double durationHours = _isCustomDuration
        ? _customHours + (_customMinutes / 60.0)
        : (_selectedDuration?.hours ?? 3.0);

    final endDateTime =
        _endDateTime ?? _startDateTime!.add(const Duration(hours: 3));

    final result = await ActivityService.createActivity(
      titre: _titleCtrl.text.trim(),
      typeActivite: _category ?? 'Other',
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: _locationCtrl.text.trim(),
      duree: durationHours,
      dateDebut: _startDateTime!,
      dateFin: endDateTime,
      photos: _photos.map((x) => File(x.path)).toList(),
      equipementsInclus: List.from(_includedEquipment),
      aApporter: List.from(_itemsToBring),
      languesDisponibles: List.from(_languages),
      niveauDifficulte: _difficultyLevel,
      statut: _isPublish ? 'active' : 'inactive',
      coordonnees: _pickedLatLng != null
          ? {
              'latitude': _pickedLatLng!.latitude,
              'longitude': _pickedLatLng!.longitude,
            }
          : null,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    _buildTopHeader(),
                    const SizedBox(height: 30),
                    _buildCoreIdentity(),
                    const SizedBox(height: 30),
                    _buildMediaGallery(),
                    const SizedBox(height: 30),
                    _buildLogistics(),
                    const SizedBox(height: 30),
                    _buildLocation(),
                    const SizedBox(height: 30),
                    _buildPreparation(),
                    const SizedBox(height: 30),
                    _buildAvailability(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF2E3192),
              size: 18,
            ),
            label: const Text(
              'Activity Details',
              style: TextStyle(
                color: Color(0xFF2E3192),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF2E3192)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ORGANIZER PORTAL',
                style: TextStyle(
                  color: Color(0xFF4A65E6),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4EE),
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
        const Text(
          'Create New Activity',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B2352),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Define your Mediterranean experience. Fields marked with an asterisk are required to publish.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetric('BOOKINGS', '0'),
              Container(width: 1, height: 30, color: Colors.grey[200]),
              _buildMetric(
                'CREATED',
                DateFormat('MMM dd, yyyy').format(DateTime.now()),
              ),
              Container(width: 1, height: 30, color: Colors.grey[200]),
              _buildMetric('STATUS', 'Draft', isDraft: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String val, {bool isDraft = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2352),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2352),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCoreIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Core Identity',
          "The fundamental details that define your activity's brand.",
        ),
        _buildTextField(
          'TITLE (EN/FR) *',
          'e.g. Sunset Kayaking in Blue Grotto',
          _titleCtrl,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'DESCRIPTION *',
          'Describe the magical experience users will have...',
          _descCtrl,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        const Text(
          'ACTIVITY TYPE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F4FE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          hint: const Text(
            'Select category',
            style: TextStyle(color: Colors.grey),
          ),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 16),
        const Text(
          'DIFFICULTY LEVEL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['Easy', 'Moderate', 'Difficult', 'Expert']
              .map(
                (lvl) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _difficultyLevel = lvl),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _difficultyLevel == lvl
                            ? Colors.white
                            : const Color(0xFFF3F4FE),
                        borderRadius: BorderRadius.circular(12),
                        border: _difficultyLevel == lvl
                            ? Border.all(
                                color: const Color(0xFF4A65E6),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: _difficultyLevel == lvl
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4A65E6,
                                  ).withOpacity(0.1),
                                  blurRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        lvl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _difficultyLevel == lvl
                              ? const Color(0xFF4A65E6)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMediaGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Media Gallery',
          'Upload high-quality images to capture the Mediterranean essence.',
        ),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
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
                    color: const Color(0xFFF8F9FE),
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

  Widget _buildLogistics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Logistics',
            'Setting the price, duration, and guest capacity.',
          ),
          _buildTextField(
            'PRICE PER PERSON (TND)',
            '0.00',
            _priceCtrl,
            icon: const Padding(
              padding: EdgeInsets.only(top: 15, left: 15),
              child: Text(
                'TND',
                style: TextStyle(
                  color: Color(0xFF5E6582),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            focus: _priceFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'MAX CAPACITY',
            'e.g. 12',
            _capacityCtrl,
            suffixIcon: const Icon(
              Icons.people_outline,
              color: Color(0xFF5E6582),
              size: 18,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'LANGUAGES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
                    style: const TextStyle(
                      color: Color(0xFF4A65E6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: const Color(0xFFE2E9FF),
                  side: BorderSide.none,
                  onDeleted: () => setState(() => _languages.remove(l)),
                  deleteIconColor: const Color(0xFF4A65E6),
                ),
              ),
              ActionChip(
                label: const Text(
                  '+ ADD',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFFF3F4FE),
                side: BorderSide.none,
                onPressed: _showAddLanguagePrompt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Location',
          'Where the magic happens. Use the map to pin exact coordinates.',
        ),
        _buildTextField('', 'Search address/lieu...', _locationCtrl),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push<MapPickerResult>(
              context,
              MaterialPageRoute(
                builder: (_) => MapPickerScreen(initialPosition: _pickedLatLng),
              ),
            );
            if (result != null)
              setState(() {
                _locationCtrl.text = result.address;
                _pickedLatLng = result.latLng;
              });
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _pickedLatLng == null
                                ? 'Pin location on map'
                                : '${_pickedLatLng!.latitude.toStringAsFixed(4)}, ${_pickedLatLng!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildPreparation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Preparation',
          'What you provide vs. what the guest needs to bring.',
        ),
        _buildPrepList(
          'INCLUDED EQUIPMENT',
          _includedEquipment,
          (v) => _addEquipment(v),
          (v) => setState(() => _includedEquipment.remove(v)),
          _incCtrl,
        ),
        const SizedBox(height: 12),
        _buildPrepList(
          'ITEMS TO BRING (A APPORTER)',
          _itemsToBring,
          (v) => _addItemToBring(v),
          (v) => setState(() => _itemsToBring.remove(v)),
          _bringCtrl,
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
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onRemove(i),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Add item...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
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

  Widget _buildAvailability() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Availability',
          'When is this activity available? Choose the season start and duration.',
        ),
        _buildLabel('START DATE'),
        GestureDetector(
          onTap: _pickStartDate,
          child: _dateContainer(
            _startDateTime != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(_startDateTime!)
                : 'Select Start Date...',
            _startDateTime != null,
            icon: Icons.calendar_month,
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('END DATE (AUTO-CALCULATED)'),
        _dateContainer(
          _startDateTime != null && _endDateTime != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(_endDateTime!)
              : 'Auto calculated after start date...',
          _startDateTime != null,
          disabled: true,
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 16),
        const Text(
          'DURATION (HOURS)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(
                _isCustomDuration
                    ? '$_customHours h ${_customMinutes > 0 ? '$_customMinutes min' : ''}'
                          .trim()
                    : (_selectedDuration?.label ?? 'Select'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2352),
                ),
              ),
              const Spacer(),
              const Icon(Icons.timer, color: Color(0xFF5E6582), size: 18),
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
                              ? const Color(0xFFE2E9FF)
                              : Colors.white,
                          border: Border.all(
                            color: const Color(0xFFF3F4FE),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            color: _selectedDuration == opt
                                ? const Color(0xFF4A65E6)
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
                            ? const Color(0xFFE2E9FF)
                            : Colors.white,
                        border: Border.all(
                          color: const Color(0xFFF3F4FE),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CUSTOM',
                        style: TextStyle(
                          color: _isCustomDuration
                              ? const Color(0xFF4A65E6)
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2352),
          ),
          validator: (v) =>
              label.contains('*') && (v == null || v.trim().isEmpty)
              ? 'Required'
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: const Color(0xFFF3F4FE),
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFF8F9FE)),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
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
                              ? (_customHours + _customMinutes / 60.0)
                              : (_selectedDuration?.hours ?? 3.0),
                          durationLabel: _selectedDuration?.label ?? 'Custom',
                          startDateTime: _startDateTime,
                          endDateTime: _endDateTime,
                          photos: List.from(_photos),
                          requirements: List.from(_includedEquipment),
                          optional: List.from(_itemsToBring),
                          pickedLatLng: _pickedLatLng,
                          difficulty: _difficultyLevel,
                          languages: List.from(_languages),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.remove_red_eye_rounded,
                    color: Color(0xFF4A65E6),
                    size: 18,
                  ),
                  label: const Text(
                    'Preview',
                    style: TextStyle(
                      color: Color(0xFF4A65E6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4FE),
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
                    backgroundColor: const Color(0xFF0F1535),
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
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _dateContainer(
    String text,
    bool hasValue, {
    bool disabled = false,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF1F5F9) : const Color(0xFFF3F4FE),
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
                color: hasValue ? const Color(0xFF1B2352) : Colors.grey[400],
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
