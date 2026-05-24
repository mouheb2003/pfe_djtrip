import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/post_service.dart';
import '../../../services/ai_text_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ai_text_widgets.dart';
import '../../../widgets/mention_input_widget.dart';
import '../../../widgets/mention_zone_widget.dart';
import '../../../screens/organizer/interactive_djerba_map_screen.dart';
import '../lieux_map_screen.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final TextEditingController _contentCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _tagsCtrl;
  final List<String> _hashtags = [];
  final List<String> _mentions = [];
  final Map<String, String> _initialFullnames = {};

  final List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];
  bool _saving = false;
  bool _isProcessingAi = false;
  bool _didEditContent = false;
  bool _didEditLocation = false;
  bool _didEditTags = false;

  Map<String, dynamic> get _effectivePost {
    final nested = widget.post['post'];
    if (nested is Map<String, dynamic>) return nested;
    return widget.post;
  }

  String _readString(List<String> keys) {
    final source = _effectivePost;
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<String> _readHashtags() {
    final tags = _effectivePost['hashtags'] ?? _effectivePost['tags'] ?? [];
    if (tags is List) {
      return tags.map((e) => e.toString()).toList();
    }
    return [];
  }

  List<String> _readMentions() {
    final mentions = _effectivePost['mentions'];
    if (mentions is List) {
      return mentions.map((e) {
        if (e is Map) return (e['_id'] ?? e['id'] ?? '').toString();
        return e.toString();
      }).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Map<String, String> _readMentionsFullnames() {
    final Map<String, String> map = {};
    final mentions = _effectivePost['mentions'];
    if (mentions is List) {
      for (final e in mentions) {
        if (e is Map) {
          final id = (e['_id'] ?? e['id'] ?? '').toString();
          final name = (e['fullname'] ?? e['name'] ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) {
            map[id] = name;
          }
        }
      }
    }
    return map;
  }

  List<String> _readImageUrls() {
    final urls = <String>[];
    
    // Try different field names
    final imageUrls = _effectivePost['imageUrls'] ?? _effectivePost['image_urls'];
    if (imageUrls is List) {
      urls.addAll(imageUrls.map((e) => e.toString()));
    }
    
    final imageUrl = _effectivePost['imageUrl'] ?? _effectivePost['image_url'];
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      urls.add(imageUrl.toString());
    }
    
    return urls;
  }

  void _applyFetchedPostData(Map<String, dynamic> source) {
    final content = _readStringFrom(source, ['content']);
    final location = _readStringFrom(source, [
      'location_label',
      'locationLabel',
      'location',
      'place',
    ]);
    
    // Read tags and mentions from the source instead of the stale effectivePost
    final tagsRaw = source['hashtags'] ?? source['tags'] ?? [];
    final tags = tagsRaw is List ? tagsRaw.map((e) => e.toString()).toList() : <String>[];
    
    final mentionsRaw = source['mentions'];
    final mentions = mentionsRaw is List ? mentionsRaw.map((e) => e.toString()).toList() : <String>[];
    
    final images = _readImageUrlsFrom(source);

    if (!_didEditContent && content.isNotEmpty) {
      _contentCtrl.text = content;
    }
    if (!_didEditLocation && location.isNotEmpty) {
      _locationCtrl.text = location;
    }
    if (!_didEditTags && tags.isNotEmpty) {
      _hashtags
        ..clear()
        ..addAll(tags.map(_normalizeTag));
      _tagsCtrl.clear();
    }

    if (_mentions.isEmpty && mentions.isNotEmpty) {
      _mentions
        ..clear()
        ..addAll(mentions);
    }

    if (_existingImageUrls.isEmpty && images.isNotEmpty) {
      _existingImageUrls
        ..clear()
        ..addAll(images);
    }
  }

  String _readStringFrom(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<String> _readImageUrlsFrom(Map<String, dynamic> source) {
    final urls = <String>[];
    
    final imageUrls = source['imageUrls'] ?? source['image_urls'];
    if (imageUrls is List) {
      urls.addAll(imageUrls.map((e) => e.toString()));
    }
    
    final imageUrl = source['imageUrl'] ?? source['image_url'];
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      urls.add(imageUrl.toString());
    }
    
    return urls;
  }

  Future<void> _fetchLatestPostData() async {
    final postId = _postIdFrom(_effectivePost);
    if (postId.isEmpty) return;

    final mine = await PostService.getMyPosts();
    if (!mounted) return;

    final latest = mine.where((p) => _postIdFrom(p) == postId).toList();
    if (latest.isEmpty) return;

    setState(() {
      _applyFetchedPostData(latest.first);
    });
  }

  List<String> _dedupUrls(List<String> urls) {
    final seen = <String>{};
    final output = <String>[];
    for (final url in urls) {
      if (seen.add(url)) output.add(url);
    }
    return output;
  }

  void _onMentionAdded(String username) {
    if (!_mentions.contains(username)) {
      setState(() => _mentions.add(username));
    }
  }

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: _readString(['content']));
    _locationCtrl = TextEditingController(
      text: _readString([
        'location_label',
        'locationLabel',
        'location',
        'place',
      ]),
    );
    _hashtags.addAll(_readHashtags().map(_normalizeTag));
    _mentions.addAll(_readMentions());
    _initialFullnames.addAll(_readMentionsFullnames());
    _tagsCtrl = TextEditingController();

    final uniqueImages = _readImageUrls();

    if (uniqueImages.isNotEmpty) {
      _existingImageUrls.addAll(uniqueImages);
    } else {
      final fallback = _readString(['image_url', 'imageUrl']);
      if (fallback.isNotEmpty) _existingImageUrls.add(fallback);
    }

    _fetchLatestPostData();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _locationCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _addMoreImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isEmpty) return;
    setState(() {
      final remaining = 10 - (_existingImageUrls.length + _newImages.length);
      if (remaining > 0) {
        _newImages.addAll(picked.take(remaining));
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
      builder: (context) => _EditPlacesPickerSheet(lieux: lieux),
    );

    if (selected == null) return;
    setState(() {
      _locationCtrl.text = selected.titre;
      _didEditLocation = true;
    });
  }

  Future<void> _pickPlaceFromMap() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const InteractiveDjerbaMapScreen(),
      ),
    );

    if (result == null) return;
    setState(() {
      _locationCtrl.text = result.placeName;
      _didEditLocation = true;
    });
  }

  Future<void> _mentionPlace() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mention a Place',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D245D),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.dns, color: AppColors.primary),
              title: const Text('Choose from database'),
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
    setState(() {
      _locationCtrl.text = value;
      _didEditLocation = true;
    });
  }

  String _normalizeTag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isEmpty) return '';
    return clean;
  }

  List<String> _extractTagsFromInput(String raw) {
    return raw
        .split(RegExp(r'[,\s]+'))
        .map(_normalizeTag)
        .where((e) => e.isNotEmpty)
        .toList();
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
    setState(() {
      _hashtags.add(normalized);
      _didEditTags = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final postId = (_effectivePost['_id'] ?? _effectivePost['id'] ?? '')
        .toString();
    if (postId.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);

    final uploadedUrls = <String>[];
    for (final image in _newImages) {
      final url = await PostService.uploadPostImage(File(image.path));
      if (url != null && url.isNotEmpty) uploadedUrls.add(url);
    }

    final tags = <String>{..._hashtags}.toList();

    final result = await PostService.updatePost(
      postId: postId,
      content: _contentCtrl.text.trim(),
      locationLabel: _locationCtrl.text.trim(),
      hashtags: tags,
      imageUrls: [..._existingImageUrls, ...uploadedUrls],
      mentions: _mentions,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Unable to update post.',
        ),
      ),
    );
  }

  String _postIdFrom(Map<String, dynamic> post) {
    return (post['_id'] ?? post['id'] ?? '').toString();
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
        controller.text = result['result'];
        if (fieldType == 'post') _didEditContent = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post rewritten successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 1),
          ),
        );
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
        controller.text = result['result'];
        if (fieldType == 'post') _didEditContent = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post improved successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 1),
          ),
        );
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

  Widget _buildImagesGallery() {
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      return _ActionTile(
        icon: Icons.add_a_photo_rounded,
        label: 'Photos',
        color: const Color(0xFF4B63FF),
        onTap: _addMoreImages,
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
              '${_existingImageUrls.length + _newImages.length} Photo(s)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1D245D)),
            ),
            TextButton.icon(
              onPressed: _addMoreImages,
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
              ..._newImages.map((img) => _buildImageItem(
                file: File(img.path),
                onRemove: () => setState(() => _newImages.remove(img)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          'Edit Post',
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
              onPressed: _saving ? null : _save,
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
                _saving ? '...' : 'SAVE',
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
                      backgroundImage: _effectivePost['author_avatar'] != null
                          ? NetworkImage(_effectivePost['author_avatar'])
                          : null,
                      child: _effectivePost['author_avatar'] == null
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
                          _effectivePost['author_name'] ?? 'Traveler',
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
                                  const Icon(Icons.edit_note, size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Editing Mode',
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
                              'ORIGINAL POST',
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

            const SizedBox(height: 24),

            // Mention Zone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MentionZoneWidget(
                selectedMentions: _mentions,
                initialFullnames: _initialFullnames,
                onMentionsChanged: (newMentions) {
                  setState(() {
                    _mentions.clear();
                    _mentions.addAll(newMentions);
                  });
                },
                onFullnamesUpdated: (updatedFullnames) {
                  _initialFullnames.addAll(updatedFullnames);
                },
              ),
            ),

            const SizedBox(height: 24),

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
                              _didEditLocation = true;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildHashtagsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHashtagsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hashtags',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1D245D),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._hashtags.map((tag) => Chip(
              label: Text('#$tag'),
              onDeleted: () => setState(() => _hashtags.remove(tag)),
            )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add Tag'),
              onPressed: _showAddHashtagDialog,
            ),
          ],
        ),
      ],
    );
  }

  void _showAddHashtagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Hashtag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'tag (without #)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final tag = ctrl.text.trim().replaceAll('#', '');
              if (tag.isNotEmpty) {
                setState(() => _hashtags.add(tag));
              }
              Navigator.pop(context);
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _ImageTile({
    this.imageUrl,
    this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : file != null
                    ? Image.file(
                        file!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMediaTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD6D9ED),
            style: BorderStyle.solid,
          ),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFF4B4F90), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF8790BF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EditPlacesPickerSheet extends StatefulWidget {
  final List<LieuModel> lieux;

  const _EditPlacesPickerSheet({required this.lieux});

  @override
  State<_EditPlacesPickerSheet> createState() => _EditPlacesPickerSheetState();
}

class _EditPlacesPickerSheetState extends State<_EditPlacesPickerSheet> {
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
              height: isFullWidth ? null : 120, // Square shape
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
