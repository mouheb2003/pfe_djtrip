import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/lieu_model.dart';
import '../../../models/user_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/post_service.dart';
import '../../../services/ai_text_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/mention_input_widget.dart';
import '../../../widgets/mention_zone_widget.dart';
import '../../../widgets/ai_text_widgets.dart';
import '../../../screens/organizer/interactive_djerba_map_screen.dart';
import '../lieux_map_screen.dart';

import '../../../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  final UserModel? user;
  final PostModel? postToEdit;

  const CreatePostScreen({super.key, this.user, this.postToEdit});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final List<XFile> _images = [];
  final List<String> _hashtags = [];
  final List<String> _mentions = [];
  final List<String> _existingImageUrls = [];

  bool _publishing = false;
  bool _isProcessingAi = false;

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      _contentCtrl.text = widget.postToEdit!.content;
      _locationCtrl.text = widget.postToEdit!.locationLabel ?? '';
      _hashtags.addAll(widget.postToEdit!.hashtags);
      _mentions.addAll(widget.postToEdit!.mentions);
      _existingImageUrls.addAll(widget.postToEdit!.imageUrls);
    }
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isEmpty) return;
    setState(() {
      final remaining = 10 - _images.length;
      if (remaining > 0) {
        _images.addAll(picked.take(remaining));
      }
    });
  }

  Future<void> _pickPlaceFromDatabase() async {
    final lieux = await LieuService.getLieux();
    if (!mounted) return;

    if (lieux.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No places available in database.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<LieuModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PlacesPickerSheet(lieux: lieux),
    );

    if (selected == null) return;
    setState(() => _locationCtrl.text = selected.titre);
  }

  Future<void> _pickPlaceFromMap() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const InteractiveDjerbaMapScreen(),
      ),
    );

    if (result == null) return;
    setState(() => _locationCtrl.text = result.placeName);
  }

  Future<void> _mentionPlace() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.list_alt, color: AppColors.primary),
              title: const Text('Choose from places database'),
              onTap: () => Navigator.pop(context, 'db'),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: const Text('Pick from map'),
              onTap: () => Navigator.pop(context, 'map'),
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_location_alt,
                color: AppColors.primary,
              ),
              title: const Text('Type manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'db') {
      await _pickPlaceFromDatabase();
      return;
    }

    if (action == 'map') {
      await _pickPlaceFromMap();
      return;
    }

    final ctrl = TextEditingController(text: _locationCtrl.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mention a place'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'e.g. Houmt Souk Market'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value == null) return;
    setState(() => _locationCtrl.text = value);
  }

  Future<void> _addHashtag() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add hashtag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'traveltips'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty) return;
    final normalized = value.startsWith('#') ? value : '#$value';
    if (_hashtags.contains(normalized)) return;
    setState(() => _hashtags.add(normalized));
  }

  void _onMentionAdded(String username) {
    if (!_mentions.contains(username)) {
      setState(() => _mentions.add(username));
      // Debug print
      print('[CreatePost] Mention added: @$username, total mentions: $_mentions');
    } else {
      print('[CreatePost] Mention already exists: @$username');
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _images.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or at least one image.')),
      );
      return;
    }

    setState(() => _publishing = true);

    final imageUrls = List<String>.from(_existingImageUrls);
    for (final img in _images) {
      final url = await PostService.uploadPostImage(File(img.path));
      if (url != null && url.isNotEmpty) imageUrls.add(url);
    }

    // Debug print before sending
    print('[CreatePost] Publishing with mentions: $_mentions');
    print('[CreatePost] Publishing with hashtags: $_hashtags');
    print('[CreatePost] Content: $content');
    
    final result = widget.postToEdit != null
        ? await PostService.updatePost(
            postId: widget.postToEdit!.id,
            content: content,
            locationLabel: _locationCtrl.text.trim(),
            hashtags: _hashtags,
            imageUrls: imageUrls,
            mentions: _mentions,
          )
        : await PostService.createPost(
            content: content,
            imageUrls: imageUrls,
            locationLabel: _locationCtrl.text.trim(),
            hashtags: _hashtags,
            mentions: _mentions,
          );

    if (!mounted) return;
    setState(() => _publishing = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Unable to publish post.',
        ),
      ),
    );
  }

  Widget _buildAiActionButtons(TextEditingController controller, String fieldType) {
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
        const SizedBox(width: 4),
        // Translate button
        AiActionButton(
          icon: Icons.translate,
          tooltip: 'Translate',
          onPressed: _isProcessingAi ? null : () => _showLanguageSelector(controller, fieldType),
        ),
      ],
    );
  }

  Future<void> _rewriteFieldText(TextEditingController controller, String fieldType) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.rewriteText(
        text,
        type: 'post',
        title: fieldType == 'post' ? _locationCtrl.text.trim() : null,
        description: fieldType == 'post' ? _contentCtrl.text.trim() : null,
      );
      
      if (!mounted) return;
      
      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        _showAiPreview(controller, text, result['result'], 'rewrite');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to rewrite post'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to rewrite post. Please try again.'),
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
        type: 'post',
        title: fieldType == 'post' ? _locationCtrl.text.trim() : null,
        description: fieldType == 'post' ? _contentCtrl.text.trim() : null,
      );
      
      if (!mounted) return;
      
      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        _showAiPreview(controller, text, result['result'], 'improve');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to improve post'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to improve post. Please try again.'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    }
  }

  void _showLanguageSelector(TextEditingController controller, String fieldType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LanguageSelectorBottomSheet(
        onLanguageSelected: (lang) => _translateFieldText(controller, lang, fieldType),
      ),
    );
  }

  Future<void> _translateFieldText(TextEditingController controller, String lang, String fieldType) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    try {
      final result = await AiTextService.translateText(
        text,
        lang,
        contextText: AiTextService.buildContext(
          type: 'post',
          title: fieldType == 'post' ? _locationCtrl.text.trim() : null,
        ),
      );

      if (!mounted) return;

      setState(() => _isProcessingAi = false);

      if (result['success'] == true) {
        _showAiPreview(controller, text, result['result'], 'translate', lang: lang);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Translation failed'),
            backgroundColor: const Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation failed. Please try again.'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    }
  }

  void _showAiPreview(TextEditingController controller, String original, String processed, String action, {String? lang}) {
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
                action == 'rewrite' ? 'Post rewritten' : (action == 'improve' ? 'Post improved' : 'Post translated'),
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        onCancel: () => Navigator.pop(context),
        onReturn: action == 'translate' ? () {
          Navigator.pop(context);
          _showLanguageSelector(controller, 'post');
        } : null,
      ),
    );
  }

  Widget _buildImagesGallery() {
    if (_existingImageUrls.isEmpty && _images.isEmpty) {
      return _ActionTile(
        icon: Icons.add_a_photo_rounded,
        label: 'Photos',
        color: const Color(0xFF4B63FF),
        onTap: _pickImages,
        isFullWidth: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_existingImageUrls.length + _images.length} Photo(s)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1D245D)),
            ),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_a_photo, size: 16),
              label: const Text('Add More'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingImageUrls.map((url) => _buildImageItem(
                imageUrl: url,
                onRemove: () => setState(() => _existingImageUrls.remove(url)),
              )),
              ..._images.map((img) => _buildImageItem(
                file: File(img.path),
                onRemove: () => setState(() => _images.remove(img)),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem({String? imageUrl, File? file, required VoidCallback onRemove}) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null 
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Image.file(file!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hashtags.isEmpty)
          _ActionTile(
            icon: Icons.tag_rounded,
            label: 'Hashtags',
            color: const Color(0xFF00D2D3),
            onTap: _addHashtag,
            isFullWidth: true,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey[200]!),
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hashtags', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1D245D))),
                    GestureDetector(
                      onTap: _addHashtag,
                      child: const Icon(Icons.add_circle, color: Color(0xFF00D2D3)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hashtags.map((tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _hashtags.remove(tag)),
                    backgroundColor: const Color(0xFFE0F7FA),
                    labelStyle: const TextStyle(color: Color(0xFF00ACC1), fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                  )).toList(),
                ),
              ],
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Debug logs
    print('CreatePostScreen - User: ${user?.fullname}');
    print('CreatePostScreen - Avatar: ${user?.avatar}');
    print('CreatePostScreen - UserType: ${user?.userType}');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFE),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : const Color(0xFF1D245D)),
        ),
        title: Text(
          widget.postToEdit != null ? 'Edit Post' : 'Create New Post',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1D245D),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: Text(
                _publishing ? '...' : (widget.postToEdit != null ? 'UPDATE' : 'PUBLISH'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF0F2FF),
                      backgroundImage: user?.avatar != null
                          ? NetworkImage(user!.avatar!)
                          : null,
                      child: user?.avatar == null
                          ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullname ?? 'Traveler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1D245D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.public, size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Public Post',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (user?.userType ?? 'Touriste').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MentionInputWidget(
                controller: _contentCtrl,
                onMentionAdded: _onMentionAdded,
                focusNode: FocusNode(skipTraversal: true),
              ),
            ),



            // Mention Zone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MentionZoneWidget(
                selectedMentions: _mentions,
                onMentionsChanged: (newMentions) {
                  setState(() {
                    _mentions.clear();
                    _mentions.addAll(newMentions);
                  });
                },
              ),
            ),

            // Actions Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADD TO YOUR POST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.grey[400] : const Color(0xFF9E9E9E),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImagesGallery(),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.location_on_rounded,
                    label: _locationCtrl.text.isNotEmpty ? _locationCtrl.text : 'Place',
                    color: const Color(0xFFFF4757),
                    onTap: _mentionPlace,
                    isFullWidth: true,
                    onClear: _locationCtrl.text.isNotEmpty
                        ? () {
                            setState(() {
                              _locationCtrl.clear();
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildHashtagsList(),

                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;
  final String? previewImageUrl;
  final File? previewFile;
  final int? imageCount;
  final VoidCallback? onClear;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
    this.previewImageUrl,
    this.previewFile,
    this.imageCount,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewImageUrl != null || previewFile != null;
    final hasClear = onClear != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: isFullWidth ? double.infinity : null,
              height: isFullWidth ? null : 120, // Nice square shape
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
              ),
              child: hasPreview
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: previewImageUrl != null
                                ? Image.network(
                                    previewImageUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    previewFile!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: Colors.white, size: 24),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: hasClear ? FontWeight.w800 : FontWeight.w700,
                            color: hasClear ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF1D245D)),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ),
          if (hasClear)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  final int count;

  const _UploadButton({required this.onTap, required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFAFC0FF)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.add_photo_alternate,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              count == 0 ? 'UPLOAD IMAGES' : '$count image(s) selected',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewChip extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImagePreviewChip({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              width: 92,
              height: 92,
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1B2458),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesPickerSheet extends StatefulWidget {
  final List<LieuModel> lieux;

  const _PlacesPickerSheet({required this.lieux});

  @override
  State<_PlacesPickerSheet> createState() => _PlacesPickerSheetState();
}

class _PlacesPickerSheetState extends State<_PlacesPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.toLowerCase().trim();
    final filtered = widget.lieux
        .where((l) => l.titre.toLowerCase().contains(q))
        .toList(growable: false);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search place...',
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final place = filtered[i];
                return ListTile(
                  title: Text(place.titre),
                  subtitle: Text(place.categoryLabelEn),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
