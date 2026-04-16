import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../widgets/ai_image_generator_widget.dart';
import 'map_picker_screen.dart';
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

  static const _difficultyLevels = ['Easy', 'Moderate', 'Difficult', 'Expert'];

  final List<String> _languages = [];
  final List<String> _includedEquipment = [];
  final List<String> _itemsToBring = [];
  String _difficultyLevel = 'Intermediate';

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

    _startDateTime = a.dateDebut;
    _endDateTime = a.dateFin;
    _existingPhotoUrls = List<String>.from(a.photos);

    final point = a.coordonnees;
    if (point != null) {
      final lat = point['latitude'] ?? point['lat'];
      final lng = point['longitude'] ?? point['lng'];
      if (lat is num && lng is num) {
        _pickedLatLng = LatLng(lat.toDouble(), lng.toDouble());
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
    cleanList(a.equipementsInclus ?? [], _includedEquipment);
    cleanList(a.aApporter ?? [], _itemsToBring);
    cleanList(a.languesDisponibles ?? [], _languages);
    _difficultyLevel = _difficultyLevels.contains(a.niveauDifficulte)
        ? a.niveauDifficulte
        : 'Intermediate';

    // Duration handling
    final durationPresets = [1.0, 2.0, 3.0, 4.0];
    final preset = durationPresets.firstWhere((p) => (p - a.duree).abs() < 0.01, orElse: () => -1.0);
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
      _existingPhotoUrls.add(imageUrl); // Add to existing photos so it appears in gallery
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
    super.dispose();
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Not set' : DateFormat('MMM dd, yyyy').format(d);
  String _fmtTime(DateTime? d) =>
      d == null ? '--:--' : DateFormat('HH:mm').format(d);
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
    setState(() => _isLoading = true);

    final duree = _currentDurationHours();
    final endDateTime =
        _endDateTime ??
        _startDateTime?.add(const Duration(hours: 1)) ??
        DateTime.now().add(const Duration(hours: 1));

    final result = await ActivityService.updateActivity(
      id: widget.activity.id,
      titre: _titleCtrl.text.trim(),
      typeActivite: _category ?? 'Other',
      description: _descCtrl.text.trim(),
      prix: double.tryParse(_priceCtrl.text) ?? 0,
      capaciteMax: int.tryParse(_capacityCtrl.text) ?? 1,
      lieu: _locationCtrl.text.trim(),
      duree: duree,
      dateDebut: _startDateTime ?? DateTime.now(),
      dateFin: endDateTime,
      newPhotos: _newPhotos.map((x) => File(x.path)).toList(),
      aiGeneratedImageUrl: _aiGeneratedImageUrl,
      existingPhotoUrls: _existingPhotoUrls,
      languesDisponibles: _languages,
      equipementsInclus: _includedEquipment,
      aApporter: _itemsToBring,
      niveauDifficulte: _difficultyLevel,
      statut: widget.activity.statut,
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
                        'Describe the magic...',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('ACTIVITY TYPE'),
                      _buildDropdown(),
                      const SizedBox(height: 20),
                      _buildLabel('DIFFICULTY LEVEL'),
                      _buildDifficultySegment(),
                    ]),
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('PRICE PER PERSON (TND)'),
                                _buildTextField(
                                  _priceCtrl,
                                  '45',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('MAX CAPACITY'),
                                _buildTextField(
                                  _capacityCtrl,
                                  '12',
                                  keyboardType: TextInputType.number,
                                  suffixIcon: Icons.people_outline,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('LANGUAGES SUPPORTED'),
                      _buildLanguageChips(),
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Location',
                      'Where the magic happens. Use the map to pin exact coordinates.',
                    ),
                    _buildCard([
                      _buildTextField(
                        _locationCtrl,
                        'Ranch Yassmina, Houmt Souk, Djerba',
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      _buildMapPreview(),
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
            icon: const Icon(
              Icons.check_circle,
              color: Color(0xFF4F67E8),
            ),
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
    TextInputType keyboardType = TextInputType.text,
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

  Widget _buildDifficultySegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: _difficultyLevels.map((lvl) {
          final isSel = _difficultyLevel == lvl;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _difficultyLevel = lvl),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    lvl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel
                          ? const Color(0xFF3858C8)
                          : const Color(0xFF717BBC),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
                builder: (_) => MapPickerScreen(initialPosition: latLng),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B2452)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) => setModal(() => tempH = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (ctx, i) => Center(
                                child: Text(
                                  '$i h',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: tempH == i ? FontWeight.w800 : FontWeight.w500,
                                    color: tempH == i ? const Color(0xFF3858C8) : Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1B2452))),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Minutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 150,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 44,
                            perspective: 0.005,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) => setModal(() => tempM = i * 5),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (ctx, i) {
                                final m = i * 5;
                                return Center(
                                  child: Text(
                                    '${m.toString().padLeft(2, '0')} min',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: tempM == m ? FontWeight.w800 : FontWeight.w500,
                                      color: tempM == m ? const Color(0xFF3858C8) : Colors.grey[400],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Duration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
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
    return Container(
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
                      color: isSaveDisabled ? Colors.grey[500] : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Save All Changes',
                      style: TextStyle(
                        color: isSaveDisabled ? Colors.grey[600] : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
              difficulty: _difficultyLevel,
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
