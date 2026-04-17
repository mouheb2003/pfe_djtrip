import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_image_service.dart';
import '../theme/app_theme.dart';

class AIImageGeneratorWidget extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final Function(String imageUrl) onImageGenerated;
  final Function(String imageUrl)? onImageDeleted;
  final List<XFile>? existingPhotos;
  final List<String>? existingImageUrls;
  final String? category;
  final bool showDebugInfo;

  const AIImageGeneratorWidget({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.onImageGenerated,
    this.onImageDeleted,
    this.existingPhotos,
    this.existingImageUrls,
    this.category,
    this.showDebugInfo = false,
  });

  @override
  State<AIImageGeneratorWidget> createState() => _AIImageGeneratorWidgetState();
}

class _AIImageGeneratorWidgetState extends State<AIImageGeneratorWidget>
    with SingleTickerProviderStateMixin {
  final AIImageService _aiService = AIImageService.instance;
  bool _isGenerating = false;
  List<String> _generatedImageUrls = [];
  int? _selectedImageIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  
  // Quality and metadata tracking
  String? _generationMethod;
  int? _promptScore;
  String? _qualityMessage;
  String? _processingTime;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _generateImages() async {
    final title = widget.titleController.text.trim();
    final description = widget.descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title and description first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await _aiService.generateActivityImages(
        title: title,
        description: description,
        category: widget.category,
      );

      if (mounted) {
        if (result['success'] == true) {
          final images = result['images'] as List<dynamic>? ?? [];
          final isHighQuality = _aiService.isHighQualityGeneration(result);
          final qualityMsg = _aiService.getQualityMessage(result);
          
          setState(() {
            _generatedImageUrls = images.cast<String>();
            _selectedImageIndex = images.isNotEmpty ? 0 : null;
            _isGenerating = false;
            _generationMethod = result['method'] as String?;
            _promptScore = result['promptScore'] as int?;
            _qualityMessage = qualityMsg;
            _processingTime = result['processingTime'] as String?;
            _metadata = result['metadata'] as Map<String, dynamic>?;
          });
          _animationController.forward();
          if (_generatedImageUrls.isNotEmpty) {
            widget.onImageGenerated(_generatedImageUrls[0]);
          }
          
          // Show quality-appropriate message
          final backgroundColor = isHighQuality ? AppColors.online : Colors.orange;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$qualityMsg (${_generatedImageUrls.length} images)'),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Failed to generate images'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _regenerateImages() async {
    setState(() {
      _generatedImageUrls = [];
      _selectedImageIndex = null;
      _generationMethod = null;
      _promptScore = null;
      _qualityMessage = null;
      _processingTime = null;
      _metadata = null;
    });
    _animationController.reset();
    await _generateImages();
  }

  void _removeGeneratedImages() {
    setState(() {
      _generatedImageUrls = [];
      _selectedImageIndex = null;
      _generationMethod = null;
      _promptScore = null;
      _qualityMessage = null;
      _processingTime = null;
      _metadata = null;
    });
    _animationController.reset();
  }

  void _selectImage(int index) {
    setState(() {
      _selectedImageIndex = index;
    });
    widget.onImageGenerated(_generatedImageUrls[index]);
  }

  void _useSelectedImage() {
    if (_selectedImageIndex != null && _generatedImageUrls.isNotEmpty) {
      widget.onImageGenerated(_generatedImageUrls[_selectedImageIndex!]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image selected successfully!'),
          backgroundColor: AppColors.online,
        ),
      );
    }
  }

  List<Widget> _buildPromptTips() {
    return [
      _buildTip('✓ Be specific about the activity and equipment', 'Mention: quad bike, kayak, cooking, etc.'),
      _buildTip('✓ Describe the location clearly', 'Beach, desert, mountain, city, etc.'),
      _buildTip('✓ Include the atmosphere or mood', 'Relaxing, exciting, adventurous, etc.'),
      _buildTip('✓ Mention the number of people', 'Solo, group, family, couples, etc.'),
      _buildTip('✓ Add sensory details', 'Golden hour, turquoise water, warm sunlight, etc.'),
    ];
  }

  Widget _buildTip(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Activity Images',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Let AI create 3 stunning images for your activity',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Prompt Advice Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '💡 Tips for Best Results',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildPromptTips(),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Display existing images if provided
          if (widget.existingImageUrls != null && widget.existingImageUrls!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.photo_library,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Existing Images (${widget.existingImageUrls!.length})',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: widget.existingImageUrls!.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.existingImageUrls![index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppColors.surface,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.onImageDeleted != null)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                widget.onImageDeleted!(widget.existingImageUrls![index]);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Generate Button
          if (_generatedImageUrls.isEmpty && !_isGenerating)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Generate with AI',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading State
          if (_isGenerating)
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Generating your images...',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Generated Images Display
          if (_generatedImageUrls.isNotEmpty)
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          _selectImage(index);
                        },
                        itemCount: _generatedImageUrls.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedImageIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () => _selectImage(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: isSelected ? 3 : 0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        _generatedImageUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: AppColors.surface,
                                            child: const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: AppColors.surface,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Image indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _generatedImageUrls.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedImageIndex == index
                                ? AppColors.primary
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _regenerateImages,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Regenerate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.onSurface,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _useSelectedImage,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Use Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _removeGeneratedImages,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          // Info text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Swipe to select the best image, then click "Use Image"',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Quality indicator (shown when images are generated)
          if (_qualityMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _generationMethod == 'ai_generated' && (_promptScore ?? 0) >= 60
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _generationMethod == 'ai_generated' && (_promptScore ?? 0) >= 60
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _generationMethod == 'ai_generated' && (_promptScore ?? 0) >= 60
                            ? Icons.check_circle
                            : Icons.info,
                        size: 16,
                        color: _generationMethod == 'ai_generated' && (_promptScore ?? 0) >= 60
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _qualityMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _generationMethod == 'ai_generated' && (_promptScore ?? 0) >= 60
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.showDebugInfo && _promptScore != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prompt Score: $_promptScore/100',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                ),
                              ),
                              if (_processingTime != null)
                                Text(
                                  'Processing Time: $_processingTime',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                              if (_generationMethod != null)
                                Text(
                                  'Method: $_generationMethod',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
