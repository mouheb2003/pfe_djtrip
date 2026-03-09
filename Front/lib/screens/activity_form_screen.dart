import 'dart:io';
import 'package:flutter/material.dart';
import '../models/activite.dart';
import '../models/user.dart';
import '../services/activity_service.dart';
import '../utils/notification_helper.dart';
import '../widgets/location_picker.dart';
import '../widgets/image_picker_widget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActivityFormScreen extends StatefulWidget {
  final User user;
  final Activite? activity; // null for create, non-null for edit

  const ActivityFormScreen({super.key, required this.user, this.activity});

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form fields
  late TextEditingController _titreController;
  late TextEditingController _descriptionController;
  late TextEditingController _lieuController;
  late TextEditingController _prixController;
  late TextEditingController _capaciteController;
  late TextEditingController _dureeController;

  String _typeActivite = 'Visite guidée';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  TimeOfDay? _heureDebut;
  TimeOfDay? _heureFin;
  bool _isDurationValid = true;
  String _durationErrorMessage = '';

  // Location selection
  String _locationMode = 'list'; // 'list' or 'map'
  double? _selectedLatitude;
  double? _selectedLongitude;

  // Image selection
  List<File> _selectedImages = [];

  // Predefined locations (à venir - pour l'instant quelques exemples)
  final List<String> _predefinedLocations = [
    'Tunis, Tunisia',
    'Carthage, Tunisia',
    'Sidi Bou Said, Tunisia',
    'Hammamet, Tunisia',
    'Sousse, Tunisia',
    'Djerba, Tunisia',
    'Tozeur, Tunisia',
    'Kairouan, Tunisia',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data if editing
    _titreController = TextEditingController(
      text: widget.activity?.titre ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.activity?.description ?? '',
    );
    _lieuController = TextEditingController(text: widget.activity?.lieu ?? '');
    _prixController = TextEditingController(
      text: widget.activity?.prix.toString() ?? '',
    );
    _capaciteController = TextEditingController(
      text: widget.activity?.capaciteMax.toString() ?? '',
    );
    _dureeController = TextEditingController(
      text: widget.activity?.duree.toString() ?? '',
    );

    if (widget.activity != null) {
      _typeActivite = widget.activity!.typeActivite;
      _dateDebut = widget.activity!.dateDebut;
      _dateFin = widget.activity!.dateFin;

      // Extract time from existing dates
      _heureDebut = TimeOfDay.fromDateTime(widget.activity!.dateDebut);
      _heureFin = TimeOfDay.fromDateTime(widget.activity!.dateFin);

      // Load coordinates if available
      if (widget.activity!.coordonnees != null) {
        _selectedLatitude = widget.activity!.coordonnees!.latitude;
        _selectedLongitude = widget.activity!.coordonnees!.longitude;
        _locationMode = 'map';
      }

      // Calculate duration from dates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateDuration();
      });
    }
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _lieuController.dispose();
    _prixController.dispose();
    _capaciteController.dispose();
    _dureeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateDebut == null || _dateFin == null) {
      NotificationHelper.showError(
        context,
        'Please select start and end dates',
      );
      return;
    }

    if (_heureDebut == null || _heureFin == null) {
      NotificationHelper.showError(context, 'Please select start and end time');
      return;
    }

    // Check if duration is valid
    if (!_isDurationValid) {
      NotificationHelper.showError(
        context,
        _durationErrorMessage.isEmpty
            ? 'Please fix the duration issues before submitting'
            : _durationErrorMessage.replaceAll('⚠️ ', ''),
      );
      return;
    }

    // Combine date and time
    final dateTimeDebut = DateTime(
      _dateDebut!.year,
      _dateDebut!.month,
      _dateDebut!.day,
      _heureDebut!.hour,
      _heureDebut!.minute,
    );

    final dateTimeFin = DateTime(
      _dateFin!.year,
      _dateFin!.month,
      _dateFin!.day,
      _heureFin!.hour,
      _heureFin!.minute,
    );

    // Validate that start date-time is in the future (only for new activities)
    final now = DateTime.now();
    if (widget.activity == null && dateTimeDebut.isBefore(now)) {
      NotificationHelper.showError(
        context,
        'Start date and time must be in the future',
      );
      return;
    }

    // Validate that end date-time is after start date-time
    if (dateTimeFin.isBefore(dateTimeDebut) ||
        dateTimeFin.isAtSameMomentAs(dateTimeDebut)) {
      NotificationHelper.showError(
        context,
        'End date and time must be after start date and time',
      );
      return;
    }

    // Validate minimum duration (6 minutes = 0.1 hours)
    final duration = dateTimeFin.difference(dateTimeDebut).inMinutes / 60;
    if (duration < 0.1) {
      NotificationHelper.showError(
        context,
        'Activity duration must be at least 6 minutes',
      );
      return;
    }

    setState(() => _isLoading = true);

    // Log dates for debugging timezone issues
    print('🕐 Local dateTimeDebut: $dateTimeDebut');
    print('🕐 Local dateTimeFin: $dateTimeFin');
    print('🕐 UTC dateTimeDebut: ${dateTimeDebut.toUtc()}');
    print('🕐 UTC dateTimeFin: ${dateTimeFin.toUtc()}');
    print('🕐 Current time: ${DateTime.now()}');
    print('🕐 Current time UTC: ${DateTime.now().toUtc()}');

    final activityData = {
      'titre': _titreController.text,
      'description': _descriptionController.text,
      'typeActivite': _typeActivite,
      'lieu': _lieuController.text,
      'duree': double.parse(_dureeController.text),
      'prix': double.parse(_prixController.text),
      'capaciteMax': int.parse(_capaciteController.text),
      'dateDebut': dateTimeDebut.toUtc().toIso8601String(),
      'dateFin': dateTimeFin.toUtc().toIso8601String(),
      'statut': 'active',
    };

    // Add coordinates if available
    if (_selectedLatitude != null && _selectedLongitude != null) {
      activityData['coordonnees'] = {
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
      };
    }

    // Prepare image paths
    final imagePaths = _selectedImages.isNotEmpty
        ? _selectedImages.map((f) => f.path).toList()
        : null;

    final result = widget.activity == null
        ? await ActivityService.createActivity(
            activityData,
            imagePaths: imagePaths,
          )
        : await ActivityService.updateActivity(
            widget.activity!.id,
            activityData,
            imagePaths: imagePaths,
          );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      final activity = result['activity'] as Activite?;
      final isActivityEnded =
          activity != null && activity.dateFin.isBefore(DateTime.now());

      NotificationHelper.showSuccess(
        context,
        widget.activity == null
            ? 'Activity created successfully'
            : 'Activity updated successfully',
      );

      // Notify user if activity was created but is already ended
      if (widget.activity == null && isActivityEnded) {
        await Future.delayed(const Duration(milliseconds: 600));
        NotificationHelper.showInfo(
          context,
          'Note: This activity is already ended and will appear in Archives',
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true);
    } else {
      NotificationHelper.showError(context, result['message']);
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_dateDebut ?? DateTime.now())
          : (_dateFin ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2D5016)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateDebut = picked;
          // Auto-adjust end date if it's before start date
          if (_dateFin != null && _dateFin!.isBefore(_dateDebut!)) {
            _dateFin = _dateDebut!.add(const Duration(days: 1));
          }
        } else {
          _dateFin = picked;
        }
        _updateDuration();
      });
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_heureDebut ?? TimeOfDay.now())
          : (_heureFin ?? TimeOfDay(hour: TimeOfDay.now().hour + 2, minute: 0)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2D5016)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _heureDebut = picked;
        } else {
          _heureFin = picked;
        }
        _updateDuration();
      });
    }
  }

  void _updateDuration() {
    if (_dateDebut != null &&
        _dateFin != null &&
        _heureDebut != null &&
        _heureFin != null) {
      final startDateTime = DateTime(
        _dateDebut!.year,
        _dateDebut!.month,
        _dateDebut!.day,
        _heureDebut!.hour,
        _heureDebut!.minute,
      );
      final endDateTime = DateTime(
        _dateFin!.year,
        _dateFin!.month,
        _dateFin!.day,
        _heureFin!.hour,
        _heureFin!.minute,
      );

      final now = DateTime.now();
      final difference = endDateTime.difference(startDateTime);
      final hours = difference.inMinutes / 60;
      _dureeController.text = hours.toStringAsFixed(1);

      // Check if start date is in the past (only for new activities)
      if (widget.activity == null && startDateTime.isBefore(now)) {
        setState(() {
          _isDurationValid = false;
          _durationErrorMessage =
              '⚠️ Start date/time is in the past. Activity will be archived immediately!';
        });
        NotificationHelper.showError(context, 'Start date/time is in the past');
      }
      // Validate minimum duration
      else if (hours < 0.5) {
        setState(() {
          _isDurationValid = false;
          _durationErrorMessage = '⚠️ Minimum duration: 30 minutes (0.5 hours)';
        });
        NotificationHelper.showError(
          context,
          'Duration must be at least 30 minutes (0.5 hours)',
        );
      } else if (hours <= 0) {
        setState(() {
          _isDurationValid = false;
          _durationErrorMessage = '⚠️ End time must be after start time';
        });
        NotificationHelper.showError(
          context,
          'End time must be after start time',
        );
      } else {
        setState(() {
          _isDurationValid = true;
          _durationErrorMessage = '';
        });
      }
    }
  }

  Future<void> _openMapLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          initialLocation:
              _selectedLatitude != null && _selectedLongitude != null
              ? LatLng(_selectedLatitude!, _selectedLongitude!)
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _lieuController.text = result['address'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.activity != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Activity' : 'Create Activity'),
        backgroundColor: const Color(0xFF2D5016),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D5016)),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Titre
                  _buildTextField(
                    controller: _titreController,
                    label: 'Title',
                    icon: Icons.title,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 4,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Type d'activité
                  _buildDropdownField(),
                  const SizedBox(height: 16),

                  // Location Selection Section
                  _buildLocationSection(),
                  const SizedBox(height: 16),

                  // Dates Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Start Date',
                          date: _dateDebut,
                          onTap: () => _selectDate(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField(
                          label: 'End Date',
                          date: _dateFin,
                          onTap: () => _selectDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Time Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeField(
                          label: 'Start Time',
                          time: _heureDebut,
                          onTap: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeField(
                          label: 'End Time',
                          time: _heureFin,
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                  // Warning for new activities
                  if (widget.activity == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Activity must start in the future',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Prix et Capacité Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _prixController,
                          label: 'Price (DT)',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true)
                              return 'Price is required';
                            if (double.tryParse(value!) == null) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _capaciteController,
                          label: 'Max Capacity',
                          icon: Icons.people,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Capacity is required';
                            }
                            if (int.tryParse(value!) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Durée (Auto-calculated)
                  Container(
                    decoration: BoxDecoration(
                      color: _isDurationValid
                          ? Colors.grey[100]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDurationValid
                            ? Colors.grey[300]!
                            : Colors.red[300]!,
                        width: _isDurationValid ? 1 : 2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextFormField(
                      controller: _dureeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Duration (hours) - Auto-calculated',
                        labelStyle: TextStyle(
                          color: _isDurationValid ? null : Colors.red[700],
                        ),
                        prefixIcon: Icon(
                          Icons.timer,
                          color: _isDurationValid
                              ? const Color(0xFF2D5016)
                              : Colors.red[700],
                        ),
                        border: InputBorder.none,
                        suffixIcon: Icon(
                          _isDurationValid ? Icons.check_circle : Icons.error,
                          color: _isDurationValid
                              ? Colors.green[600]
                              : Colors.red[700],
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return 'Please select start and end dates/times';
                        final duration = double.tryParse(value!);
                        if (duration == null || duration <= 0)
                          return 'Invalid duration';
                        if (duration < 0.5)
                          return 'Duration must be at least 30 minutes';
                        return null;
                      },
                    ),
                  ),
                  if (!_isDurationValid && _dureeController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        _durationErrorMessage.isEmpty
                            ? '⚠️ Minimum duration: 30 minutes (0.5 hours)'
                            : _durationErrorMessage,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Images Section
                  ImagePickerWidget(
                    initialImages: widget.activity?.photos,
                    onImagesSelected: (images) {
                      setState(() {
                        _selectedImages = images;
                      });
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5016),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        isEditing ? 'Update Activity' : 'Create Activity',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF2D5016), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location Mode Toggle
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  label: 'From List',
                  icon: Icons.list,
                  isSelected: _locationMode == 'list',
                  onTap: () {
                    setState(() => _locationMode = 'list');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeButton(
                  label: 'On Map',
                  icon: Icons.map,
                  isSelected: _locationMode == 'map',
                  onTap: () {
                    setState(() => _locationMode = 'map');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location Input based on mode
          if (_locationMode == 'list')
            DropdownButtonFormField<String>(
              value: _predefinedLocations.contains(_lieuController.text)
                  ? _lieuController.text
                  : null,
              decoration: InputDecoration(
                hintText: 'Select a location',
                prefixIcon: const Icon(Icons.place, color: Color(0xFF2D5016)),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2D5016),
                    width: 2,
                  ),
                ),
              ),
              items: _predefinedLocations.map((location) {
                return DropdownMenuItem(value: location, child: Text(location));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _lieuController.text = value;
                    _selectedLatitude = null;
                    _selectedLongitude = null;
                  });
                }
              },
              validator: (value) =>
                  _lieuController.text.isEmpty ? 'Location is required' : null,
            )
          else
            Column(
              children: [
                if (_lieuController.text.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5016).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF2D5016),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lieuController.text,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openMapLocationPicker,
                    icon: const Icon(Icons.map),
                    label: Text(
                      _lieuController.text.isEmpty
                          ? 'Select Location on Map'
                          : 'Change Location',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5016),
                      side: const BorderSide(color: Color(0xFF2D5016)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5016) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D5016) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2D5016)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D5016), width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: _typeActivite,
        decoration: const InputDecoration(
          labelText: 'Activity Type',
          prefixIcon: Icon(Icons.category, color: Color(0xFF2D5016)),
          border: InputBorder.none,
        ),
        items:
            [
              'Visite guidée',
              'Excursion',
              'Randonnée',
              'Aventure',
              'Culture',
              'Gastronomie',
              'Sport',
              'Autre',
            ].map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _typeActivite = value);
          }
        },
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: date == null
                      ? Colors.grey[400]
                      : const Color(0xFF2D5016),
                ),
                const SizedBox(width: 8),
                Text(
                  date == null
                      ? 'Select date'
                      : '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    fontSize: 15,
                    color: date == null ? Colors.grey[400] : Colors.black87,
                    fontWeight: date == null
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: time == null
                      ? Colors.grey[400]
                      : const Color(0xFF2D5016),
                ),
                const SizedBox(width: 8),
                Text(
                  time == null
                      ? 'Select time'
                      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 15,
                    color: time == null ? Colors.grey[400] : Colors.black87,
                    fontWeight: time == null
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
