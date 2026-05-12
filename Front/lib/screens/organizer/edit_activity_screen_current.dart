import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/ai_text_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_text_widgets.dart';

class EditActivityScreen extends StatefulWidget {
  final ActivityModel activity;

  const EditActivityScreen({super.key, required this.activity});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _maxParticipantsCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _locationCtrl;

  final List<XFile> _images = [];
  final List<String> _existingImageUrls = [];
  bool _isProcessingAi = false;
  bool _isSaving = false;
  int _currentStep = 0;
  final int _totalSteps = 6;

  final List<String> _categories = [
    'Adventure', 'Beach', 'Culture', 'Food & Drink', 'Nature',
    'Nightlife', 'Shopping', 'Sports', 'Wellness', 'Water Sports'
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.activity.titre);
    _descCtrl = TextEditingController(text: widget.activity.description);
    _priceCtrl = TextEditingController(text: widget.activity.prix.toString());
    _maxParticipantsCtrl = TextEditingController(text: widget.activity.capaciteMax.toString());
    _durationCtrl = TextEditingController(text: widget.activity.duree.toString());
    _categoryCtrl = TextEditingController(text: widget.activity.categorie);
    _locationCtrl = TextEditingController(text: widget.activity.lieu);
    _existingImageUrls.addAll(widget.activity.photos);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _durationCtrl.dispose();
    _categoryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Widget _buildAiActionButtons(TextEditingController controller, String fieldType) {
    if (controller.text.trim().isEmpty) return const SizedBox.shrink();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rewrite button
        AiActionButton(
          icon: Icons.auto_fix_high,
          tooltip: 'Rewrite',
          onPressed: _isProcessingAi ? null : () => _rewriteFieldText(controller, fieldType),
        ),
        const SizedBox(width: 4),
        // Improve button  
        AiActionButton(
          icon: Icons.spellcheck,
          tooltip: 'Improve',
          onPressed: _isProcessingAi ? null : () => _improveFieldText(controller, fieldType),
        ),
      ],
    );
  }

  Future<void> _rewriteFieldText(TextEditingController controller, String fieldType) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.rewriteText(text);
      
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

  Future<void> _improveFieldText(TextEditingController controller, String fieldType) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.improveText(text);
      
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter> inputFormatters = const [],
    bool showAiButtons = false,
    String fieldType = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2458),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1B2458),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            suffixIcon: showAiButtons && controller.text.trim().isNotEmpty 
                ? _buildAiActionButtons(controller, fieldType)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildDescriptionStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildLocationStep();
      case 4:
        return _buildImagesStep();
      case 5:
        return _buildReviewStep();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _titleCtrl,
          label: 'Activity Title',
          hint: 'Enter a catchy title for your activity',
          showAiButtons: true,
          fieldType: 'title',
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _categoryCtrl,
          label: 'Category',
          hint: 'Select or enter a category',
          showAiButtons: false,
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _categories.contains(_categoryCtrl.text) ? _categoryCtrl.text : null,
          decoration: InputDecoration(
            labelText: 'Popular Categories',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _categoryCtrl.text = value;
            }
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionStep() {
    return _buildTextField(
      controller: _descCtrl,
      label: 'Description',
      hint: 'Describe your activity in detail...',
      maxLines: 6,
      showAiButtons: true,
      fieldType: 'description',
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _priceCtrl,
                label: 'Price',
                hint: '0.00',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _durationCtrl,
                label: 'Duration',
                hint: 'e.g., 2 hours',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _maxParticipantsCtrl,
          label: 'Max Participants',
          hint: 'Maximum number of participants',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return _buildTextField(
      controller: _locationCtrl,
      label: 'Location',
      hint: 'Where will the activity take place?',
      showAiButtons: true,
      fieldType: 'location',
    );
  }

  Widget _buildImagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Images',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2458),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final images = await picker.pickMultiImage();
            if (images != null) {
              setState(() {
                _images.clear();
                _images.addAll(images.take(5));
              });
            }
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: _images.isEmpty
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Add Images', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_images[index].path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _images.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Your Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2458),
          ),
        ),
        const SizedBox(height: 24),
        _buildReviewCard('Title', _titleCtrl.text),
        _buildReviewCard('Category', _categoryCtrl.text),
        _buildReviewCard('Description', _descCtrl.text, maxLines: 3),
        _buildReviewCard('Price', '\$${_priceCtrl.text}'),
        _buildReviewCard('Duration', _durationCtrl.text),
        _buildReviewCard('Max Participants', _maxParticipantsCtrl.text),
        _buildReviewCard('Location', _locationCtrl.text),
        _buildReviewCard('Images', '${_existingImageUrls.length + _images.length} image(s) selected'),
      ],
    );
  }

  Widget _buildReviewCard(String label, String value, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'Not provided' : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: value.isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF1B2458),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _saveActivity();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _saveActivity() async {
    if (_isSaving) return;

    // Validate required fields
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update activity with proper field names
      final updatedActivity = ActivityModel(
        id: widget.activity.id,
        titre: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        typeActivite: widget.activity.typeActivite,
        categorie: _categoryCtrl.text.trim(),
        lieu: _locationCtrl.text.trim(),
        duree: double.tryParse(_durationCtrl.text) ?? 1.0,
        prix: double.tryParse(_priceCtrl.text) ?? 0.0,
        capaciteMax: int.tryParse(_maxParticipantsCtrl.text) ?? 1,
        photos: _existingImageUrls,
        createdAt: widget.activity.createdAt,
      );

      final result = await ActivityService.updateActivity(
        id: updatedActivity.id,
        titre: updatedActivity.titre,
        typeActivite: updatedActivity.typeActivite,
        categorie: updatedActivity.categorie,
        description: updatedActivity.description,
        prix: updatedActivity.prix,
        capaciteMax: updatedActivity.capaciteMax,
        lieu: updatedActivity.lieu,
        duree: updatedActivity.duree,
        dateDebut: widget.activity.dateDebut ?? DateTime.now(),
        newPhotos: _images.map((image) => File(image.path)).toList(),
        existingPhotoUrls: _existingImageUrls,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity updated successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update activity'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while updating the activity'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F1FA),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppColors.primary),
        ),
        title: const Text(
          'Edit Activity',
          style: TextStyle(
            color: Color(0xFF1B2458),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : () => _currentStep = 5,
              child: const Text(
                'Preview',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStepContent(),
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _nextStep,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentStep == _totalSteps - 1 ? 'Save Changes' : 'Next',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
}
