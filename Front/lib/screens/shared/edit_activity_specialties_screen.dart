import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';

class EditActivitySpecialtiesScreen extends StatefulWidget {
  const EditActivitySpecialtiesScreen({super.key});

  @override
  State<EditActivitySpecialtiesScreen> createState() => _EditActivitySpecialtiesScreenState();
}

class _EditActivitySpecialtiesScreenState extends State<EditActivitySpecialtiesScreen> {
  List<String> _specialties = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // 🚀 Spécialités d'activités avec emojis
  static const List<Map<String, String>> _activitySpecialties = [
    {'emoji': '🏃‍♂️', 'name': 'Sports & Aventure'},
    {'emoji': '🎵', 'name': 'Musique & Concerts'},
    {'emoji': '🎨', 'name': 'Art & Culture'},
    {'emoji': '🍽️', 'name': 'Gastronomie & Cuisine'},
    {'emoji': '🏖️', 'name': 'Plage & Mer'},
    {'emoji': '🏔️', 'name': 'Montagne & Randonnée'},
    {'emoji': '🏛️', 'name': 'Histoire & Patrimoine'},
    {'emoji': '🎮', 'name': 'Jeux & Divertissement'},
    {'emoji': '🧘', 'name': 'Bien-être & Spa'},
    {'emoji': '📸', 'name': 'Photographie & Tour'},
    {'emoji': '🚗', 'name': 'Transport & Excursion'},
    {'emoji': '🏕️', 'name': 'Camping & Nature'},
    {'emoji': '🎪', 'name': 'Festivals & Événements'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    setState(() => _isLoading = true);
    try {
      final user = await UserService.getProfile();
      if (user != null && user['specialites_activites'] != null) {
        setState(() {
          _specialties = List<String>.from(user['specialites_activites'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading specialties: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSpecialties() async {
    setState(() => _isSaving = true);
    try {
      final result = await UserService.updateProfile({
        'specialites_activites': _specialties,
      });

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity specialties updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Error saving specialties'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving specialties: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving specialties'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddSpecialtyDialog() {
    final TextEditingController specialtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Custom Specialty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: specialtyCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter activity specialty',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    setState(() {
                      _specialties.add(value.trim());
                    });
                  }
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final value = specialtyCtrl.text.trim();
                      if (value.isNotEmpty) {
                        setState(() {
                          _specialties.add(value);
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Specialty'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity Specialties',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading && _specialties.isNotEmpty)
            TextButton(
              onPressed: _saveSpecialties,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select your activity specialties',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose from predefined categories or add your own custom specialties.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Préférences prédéfinies avec emojis
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activitySpecialties.map((specialty) {
                      final isSelected = _specialties.contains(specialty['name']!);
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(specialty['emoji']!),
                            const SizedBox(width: 6),
                            Text(specialty['name']!),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _specialties.add(specialty['name']!);
                            } else {
                              _specialties.remove(specialty['name']!);
                            }
                          });
                        },
                        backgroundColor: isSelected 
                            ? AppColors.primary.withOpacity(0.2) 
                            : Colors.grey.withOpacity(0.1),
                        selectedColor: AppColors.primary.withOpacity(0.3),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Spécialités personnalisées
                  if (_specialties.isNotEmpty) ...[
                    const Text(
                      'Your Specialties',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specialties.map((specialty) {
                        return Chip(
                          label: Text(specialty),
                          onDeleted: () {
                            setState(() {
                              _specialties.remove(specialty);
                            });
                          },
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          deleteIcon: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ajout manuel
                  GestureDetector(
                    onTap: _showAddSpecialtyDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Custom Specialty',
                            style: TextStyle(
                              color: AppColors.primary,
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
    );
  }
}
