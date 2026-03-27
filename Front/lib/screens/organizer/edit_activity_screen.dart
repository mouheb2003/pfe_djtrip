import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import 'map_picker_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Duration preset model
// ─────────────────────────────────────────────────────────────────────────────
class _DurPreset {
  final String label;
  final double hours;
  const _DurPreset(this.label, this.hours);
}

const _kEditPresets = [
  _DurPreset('30 min', 0.5),
  _DurPreset('1h', 1),
  _DurPreset('1h 30', 1.5),
  _DurPreset('2h', 2),
  _DurPreset('3h', 3),
  _DurPreset('4h', 4),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
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

  // Existing remote photo URLs (shown as network images)
  late List<String> _existingPhotoUrls;
  // Newly picked local files
  final List<XFile> _newPhotos = [];

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
    final a = widget.activity;

    _titleCtrl = TextEditingController(text: a.titre);
    _category = _categories.contains(a.typeActivite) ? a.typeActivite : null;
    _descCtrl = TextEditingController(text: a.description);
    _priceCtrl = TextEditingController(text: a.prix.toString());
    _capacityCtrl = TextEditingController(text: a.capaciteMax.toString());
    _locationCtrl = TextEditingController(text: a.lieu);

    _startDateTime = a.dateDebut;
    _endDateTime = a.dateFin;
    _existingPhotoUrls = List<String>.from(a.photos);

    // Map duration to preset or custom
    final matchedPreset = _kEditPresets
        .where((p) => (p.hours - a.duree).abs() < 0.01)
        .firstOrNull;
    if (matchedPreset != null) {
      _selectedDuration = matchedPreset.hours;
    } else if (a.duree > 0) {
      _selectedDuration = -1;
      _customHours = a.duree.floor();
      _customMinutes = ((a.duree - _customHours) * 60).round();
      // snap minutes to nearest 5
      _customMinutes = (_customMinutes / 5).round() * 5;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double get _effectiveDuration {
    if (_selectedDuration == -1) return _customHours + _customMinutes / 60.0;
    return _selectedDuration ?? 0;
  }

  String _formatDuration(double h) {
    if (h <= 0) return '—';
    final totalMin = (h * 60).round();
    final hrs = totalMin ~/ 60;
    final mins = totalMin % 60;
    if (hrs == 0) return '${mins} min';
    if (mins == 0) return '${hrs}h';
    return '${hrs}h ${mins}min';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _newPhotos.addAll(picked));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _startDateTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
      initialTime: _startDateTime != null
          ? TimeOfDay.fromDateTime(_startDateTime!)
          : TimeOfDay.now(),
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
    });
  }

  Future<void> _pickEndDateTime() async {
    final minDate = _startDateTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDateTime ?? minDate.add(const Duration(hours: 1)),
      firstDate: minDate,
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
      initialTime: _endDateTime != null
          ? TimeOfDay.fromDateTime(_endDateTime!)
          : TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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
                  // Hours
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
                  // Minutes
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
                      : _formatDuration(tempH + tempM / 60.0),
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
                      _selectedDuration = -1;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDuration == null) {
      _showError('Please select a duration.');
      return;
    }
    if (_effectiveDuration <= 0) {
      _showError('Invalid duration.');
      return;
    }
    if (_startDateTime == null) {
      _showError('Please choose a start date and time.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await ActivityService.updateActivity(
      id: widget.activity.id,
      titre: _titleCtrl.text.trim(),
      typeActivite: _category!,
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: _locationCtrl.text.trim(),
      duree: _effectiveDuration,
      dateDebut: _startDateTime!,
      dateFin: _endDateTime,
      newPhotos: _newPhotos.map((x) => File(x.path)).toList(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showError(result['message'] ?? 'Error updating activity.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          'Edit Activity',
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
          padding: const EdgeInsets.all(16),
          children: [
            // ── Basic Info ──────────────────────────────────────
            _SectionTitle(icon: Icons.info, label: 'Basic Info'),
            const SizedBox(height: 12),

            _FieldLabel('Activity Title'),
            _inputField(
              controller: _titleCtrl,
              hint: 'e.g. Desert Safari in Douz',
              validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
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
              validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
              decoration: _inputDecoration(
                'Tell participants what makes this activity special...',
              ),
            ),
            const SizedBox(height: 24),

            // ── Media ───────────────────────────────────────────
            _SectionTitle(icon: Icons.image, label: 'Media'),
            const SizedBox(height: 12),
            _mediaSection(),
            const SizedBox(height: 24),

            // ── Pricing & Capacity ──────────────────────────────
            _SectionTitle(icon: Icons.payments, label: 'Pricing & Capacity'),
            const SizedBox(height: 12),

            _FieldLabel('Price per person'),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
              decoration: _inputDecoration('0.00').copyWith(
                suffixText: 'TND',
                suffixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Participants'),
            _inputField(
              controller: _capacityCtrl,
              hint: 'e.g. 15',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
            ),
            const SizedBox(height: 24),

            // ── Location ────────────────────────────────────────
            _SectionTitle(icon: Icons.location_on, label: 'Location'),
            const SizedBox(height: 12),
            _inputField(
              controller: _locationCtrl,
              hint: 'Enter activity address',
              prefixIcon: Icons.search,
              validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
            ),
            const SizedBox(height: 10),
            _mapPickerButton(),
            const SizedBox(height: 24),

            // ── Date & Time ─────────────────────────────────────
            _SectionTitle(icon: Icons.calendar_month, label: 'Date & Time'),
            const SizedBox(height: 12),

            _FieldLabel('Start Date & Time'),
            GestureDetector(
              onTap: _pickDateTime,
              child: _dateContainer(
                _startDateTime == null
                    ? 'mm/dd/yyyy, --:-- --'
                    : DateFormat('dd/MM/yyyy, HH:mm').format(_startDateTime!),
                _startDateTime != null,
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('End Date & Time (optional)'),
            GestureDetector(
              onTap: _pickEndDateTime,
              child: _dateContainer(
                _endDateTime == null
                    ? 'mm/dd/yyyy, --:-- --'
                    : DateFormat('dd/MM/yyyy, HH:mm').format(_endDateTime!),
                _endDateTime != null,
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Duration'),
            _durationSection(),
            const SizedBox(height: 40),

            // ── Save button ─────────────────────────────────────
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(
                  _isLoading ? 'Saving...' : 'Save Changes',
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _dateContainer(String text, bool hasValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? AppColors.textDark : Colors.grey[400],
              ),
            ),
          ),
          const Icon(Icons.calendar_today, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _mediaSection() {
    return Column(
      children: [
        // Existing photos
        if (_existingPhotoUrls.isNotEmpty) ...[
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _existingPhotoUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _existingPhotoUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _existingPhotoUrls.removeAt(i)),
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
          const SizedBox(height: 10),
        ],
        // Add new photos button
        GestureDetector(
          onTap: _pickImages,
          child: CustomPaint(
            painter: _EditDashedBorderPainter(
              color: AppColors.primary.withOpacity(0.45),
              radius: 14,
            ),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add more photos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PNG, JPG up to 10MB',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // New local photos preview
        if (_newPhotos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _newPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_newPhotos[i].path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _newPhotos.removeAt(i)),
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

  Widget _durationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._kEditPresets.map((p) {
              final selected = _selectedDuration == p.hours;
              return GestureDetector(
                onTap: () => setState(() => _selectedDuration = p.hours),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              );
            }),
            // Custom chip
            GestureDetector(
              onTap: _showCustomDurationPicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _selectedDuration == -1
                      ? AppColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDuration == -1
                        ? AppColors.primary
                        : AppColors.borderLight,
                    width: _selectedDuration == -1 ? 1.5 : 1,
                  ),
                  boxShadow: _selectedDuration == -1
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  _selectedDuration == -1
                      ? _formatDuration(_customHours + _customMinutes / 60.0)
                      : 'Custom',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedDuration == -1
                        ? Colors.white
                        : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedDuration != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Selected: ${_formatDuration(_effectiveDuration)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mapPickerButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.map_rounded, color: AppColors.primary),
        title: const Text(
          'Pick on Map',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: () async {
          final result = await Navigator.push<MapPickerResult>(
            context,
            MaterialPageRoute(builder: (_) => const MapPickerScreen()),
          );
          if (result != null) {
            setState(() => _locationCtrl.text = result.address);
          }
        },
      ),
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
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(hint).copyWith(
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[400], size: 20)
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderLight, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderLight, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Dashed border painter (same as create screen)
// ─────────────────────────────────────────────────────────────────────────────

class _EditDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _EditDashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );
    double distance = 0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0;
    }
  }

  @override
  bool shouldRepaint(_EditDashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
