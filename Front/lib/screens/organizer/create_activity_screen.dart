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

//
// Duration option model
//
class _DurOption {
  final String label;
  final double hours;
  const _DurOption(this.label, this.hours);
}

const _kDurOptions = [
  _DurOption('30 min', 0.5),
  _DurOption('1 hour', 1.0),
  _DurOption('1-2 hours', 1.5),
  _DurOption('2-3 hours', 2.5),
  _DurOption('3-4 hours', 3.5),
  _DurOption('Half day (4h)', 4.0),
  _DurOption('Full day (8h)', 8.0),
];

//
// Screen
//
class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _titleCtrl = TextEditingController();
  String? _category;
  final _descCtrl = TextEditingController();

  // Requirements & Equipment
  final List<String> _requirements = [];
  final _reqCtrl = TextEditingController();

  // Media
  final List<XFile> _photos = [];

  // Pricing
  final _priceCtrl = TextEditingController(text: '0.00');
  late final FocusNode _priceFocus = FocusNode();
  final _capacityCtrl = TextEditingController();

  // Location
  final _locationCtrl = TextEditingController();
  LatLng? _pickedLatLng;

  // Date & Time
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  // Duration
  _DurOption? _selectedDuration;
  int _customHours = 0;
  int _customMinutes = 30;
  bool _isCustom = false;

  bool _isLoading = false;

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
    _locationCtrl.dispose();
    _reqCtrl.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  //  Actions

  void _addRequirement() {
    final val = _reqCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() {
      _requirements.add(val);
      _reqCtrl.clear();
    });
  }

  void _removeRequirement(int index) {
    setState(() => _requirements.removeAt(index));
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() => _photos.addAll(picked));
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
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
      // Auto-calculate end date if duration is selected
      if (_selectedDuration != null) {
        _endDateTime = _startDateTime!.add(
          Duration(minutes: (_selectedDuration!.hours * 60).round()),
        );
      }
    });
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDuration == null && !_isCustom) {
      _showError('Please select a duration.');
      return;
    }
    if (_startDateTime == null) {
      _showError('Please choose a start date and time.');
      return;
    }

    setState(() => _isLoading = true);

    final double durationHours = _isCustom
        ? _customHours + (_customMinutes / 60.0)
        : _selectedDuration!.hours;

    final endDateTime =
        _endDateTime ??
        _startDateTime!.add(Duration(minutes: (durationHours * 60).round()));

    final result = await ActivityService.createActivity(
      titre: _titleCtrl.text.trim(),
      typeActivite: _category!,
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: _locationCtrl.text.trim(),
      duree: durationHours,
      dateDebut: _startDateTime!,
      dateFin: endDateTime,
      photos: _photos.map((x) => File(x.path)).toList(),
      equipementsInclus: List.from(_requirements),
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
          content: Text('Activity published successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showError(result['message'] ?? 'Error publishing activity.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showCustomDurationPicker() {
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Custom Duration',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select hours and minutes',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.004,
                            diameterRatio: 1.6,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: tempH,
                            ),
                            onSelectedItemChanged: (i) =>
                                setModal(() => tempH = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 13,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  '$i h',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: tempH == i
                                        ? FontWeight.bold
                                        : FontWeight.w400,
                                    color: tempH == i
                                        ? AppColors.primary
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
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Minutes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.004,
                            diameterRatio: 1.6,
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
                                      fontSize: 20,
                                      fontWeight: tempM == mins
                                          ? FontWeight.bold
                                          : FontWeight.w400,
                                      color: tempM == mins
                                          ? AppColors.primary
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tempH == 0 && tempM == 0
                      ? 'Invalid duration (min. 5 min)'
                      : '${tempH}h ${tempM}m',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (tempH == 0 && tempM == 0) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _customHours = tempH;
                      _customMinutes = tempM;
                      _isCustom = true;
                      _selectedDuration = null;
                      // Auto-calculate end date
                      if (_startDateTime != null) {
                        final totalMinutes = (tempH * 60 + tempM).toDouble();
                        _endDateTime = _startDateTime!.add(
                          Duration(minutes: totalMinutes.round()),
                        );
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create New Activity',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            //  Basic Info
            _SectionTitle(icon: Icons.info, label: 'Basic Info'),
            const SizedBox(height: 14),

            _FieldLabel('Activity Title'),
            _inputField(
              controller: _titleCtrl,
              hint: 'e.g. Desert Safari in Douz',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required field' : null,
            ),
            const SizedBox(height: 14),

            _FieldLabel('Category'),
            _dropdownField(),
            const SizedBox(height: 14),

            _FieldLabel('Description'),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 6,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required field' : null,
              decoration: _inputDecoration(
                'Tell participants what makes this activity special...',
              ),
            ),
            const SizedBox(height: 28),

            //  Requirements & Equipment
            _SectionTitle(
              icon: Icons.build_circle,
              label: 'Requirements & Equipment',
            ),
            const SizedBox(height: 14),

            _FieldLabel('What to bring / Equipment provided'),
            _requirementsSection(),
            const SizedBox(height: 28),

            //  Media
            _SectionTitle(icon: Icons.image, label: 'Media'),
            const SizedBox(height: 14),
            _mediaSection(),
            const SizedBox(height: 28),

            //  Pricing & Capacity
            _SectionTitle(
              icon: Icons.receipt_long,
              label: 'Pricing & Capacity',
            ),
            const SizedBox(height: 14),

            _FieldLabel('Price per person'),
            TextFormField(
              controller: _priceCtrl,
              focusNode: _priceFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required field' : null,
              decoration: _inputDecoration('0.00').copyWith(
                suffixText: 'TND',
                suffixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Max Participants'),
            _inputField(
              controller: _capacityCtrl,
              hint: 'e.g. 15',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required field' : null,
            ),
            const SizedBox(height: 28),

            //  Location
            _SectionTitle(icon: Icons.location_on, label: 'Location'),
            const SizedBox(height: 14),
            _inputField(
              controller: _locationCtrl,
              hint: 'Enter activity address',
              prefixIcon: Icons.search,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required field' : null,
            ),
            const SizedBox(height: 10),
            _mapPickerButton(),
            if (_pickedLatLng != null) ...[
              const SizedBox(height: 12),
              _mapPreview(),
            ],
            const SizedBox(height: 28),

            //  Date & Time
            _SectionTitle(icon: Icons.calendar_month, label: 'Date & Time'),
            const SizedBox(height: 14),

            _FieldLabel('Start Date & Time'),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _startDateTime == null
                            ? 'mm/dd/yyyy, --:-- --'
                            : DateFormat(
                                'MM/dd/yyyy, hh:mm a',
                              ).format(_startDateTime!),
                        style: TextStyle(
                          fontSize: 14,
                          color: _startDateTime == null
                              ? Colors.grey[400]
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Duration'),
            Row(
              children: [
                Expanded(child: _durationDropdown()),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showCustomDurationPicker,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isCustom ? AppColors.primary : Colors.white,
                      border: Border.all(
                        color: _isCustom
                            ? AppColors.primary
                            : AppColors.borderLight,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: _isCustom ? Colors.white : AppColors.textGrey,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedDuration != null || _isCustom) ...[
              const SizedBox(height: 14),
              _FieldLabel('End Date & Time'),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _endDateTime != null
                            ? DateFormat(
                                'MM/dd/yyyy, hh:mm a',
                              ).format(_endDateTime!)
                            : 'Auto-calculated',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Icon(Icons.lock, size: 18, color: Colors.grey[400]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),

            //  Preview + Publish
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityPreviewScreen(
                              title: _titleCtrl.text.trim(),
                              category: _category ?? '',
                              description: _descCtrl.text.trim(),
                              price: double.tryParse(_priceCtrl.text) ?? 0,
                              capacity: int.tryParse(_capacityCtrl.text) ?? 0,
                              location: _locationCtrl.text.trim(),
                              duration: _selectedDuration?.hours ?? 0,
                              durationLabel: _selectedDuration?.label ?? '',
                              startDateTime: _startDateTime,
                              photos: List.from(_photos),
                              requirements: List.from(_requirements),
                              pickedLatLng: _pickedLatLng,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.remove_red_eye,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'Preview',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _publish,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isLoading ? 'Publishing...' : 'Publish Activity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
  }

  //  Section widgets

  Widget _requirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_requirements.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              _requirements.length,
              (i) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _requirements[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeRequirement(i),
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _reqCtrl,
                decoration: _inputDecoration('Add requirement or equipment...'),
                onFieldSubmitted: (_) => _addRequirement(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _addRequirement,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add items like gear, clothing, or safety requirements.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _mediaSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImages,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: AppColors.primary.withOpacity(0.5),
              radius: 14,
            ),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_camera,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Add high-quality photos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PNG, JPG up to 10MB',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photos[i].path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mapPickerButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<MapPickerResult>(
          context,
          MaterialPageRoute(
            builder: (_) => MapPickerScreen(initialPosition: _pickedLatLng),
          ),
        );
        if (result != null) {
          setState(() {
            _locationCtrl.text = result.address;
            _pickedLatLng = result.latLng;
          });
        }
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Pick on Map',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _pickedLatLng!,
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('activity'),
              position: _pickedLatLng!,
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }

  Widget _durationDropdown() {
    return DropdownButtonFormField<_DurOption>(
      value: _selectedDuration,
      decoration: _inputDecoration('Select duration').copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      validator: (v) =>
          v == null && !_isCustom ? 'Please select a duration' : null,
      items: _kDurOptions
          .map(
            (opt) => DropdownMenuItem<_DurOption>(
              value: opt,
              child: Text(opt.label),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedDuration = v;
          _isCustom = false;
          // Auto-calculate end date if start date is set
          if (_startDateTime != null && v != null) {
            _endDateTime = _startDateTime!.add(
              Duration(minutes: (v.hours * 60).round()),
            );
          } else {
            _endDateTime = null;
          }
        });
      },
    );
  }

  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      value: _category,
      decoration: _inputDecoration('Select category'),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      validator: (v) => v == null ? 'Required field' : null,
      items: _categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _category = v),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(hint).copyWith(
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: Colors.grey[400])
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
    );
  }
}

//  Small helpers

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

//  Dashed border painter

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 12,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace;
}
