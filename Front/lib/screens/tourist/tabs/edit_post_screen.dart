import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/post_service.dart';
import '../../../theme/app_theme.dart';
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

  final List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];
  bool _saving = false;
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
    final source = _effectivePost;
    final raw = source['hashtags'] ?? source['tags'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim().replaceAll('#', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (raw is String) {
      return raw
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim().replaceAll('#', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const <String>[];
  }

  List<String> _readImageUrls() {
    final source = _effectivePost;
    final collected = <String>[];

    final listCandidate = source['image_urls'] ?? source['imageUrls'];
    if (listCandidate is List) {
      collected.addAll(
        listCandidate
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final singleCandidates = [
      source['image_url'],
      source['imageUrl'],
      source['media_url'],
      source['mediaUrl'],
    ];
    for (final value in singleCandidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) collected.add(text);
    }

    return _dedupUrls(collected);
  }

  String _postIdFrom(Map<String, dynamic> source) {
    return (source['_id'] ?? source['id'] ?? '').toString();
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

  List<String> _readHashtagsFrom(Map<String, dynamic> source) {
    final raw = source['hashtags'] ?? source['tags'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim().replaceAll('#', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (raw is String) {
      return raw
          .split(RegExp(r'[,\s]+'))
          .map((e) => e.trim().replaceAll('#', ''))
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const <String>[];
  }

  List<String> _readImageUrlsFrom(Map<String, dynamic> source) {
    final collected = <String>[];

    final listCandidate = source['image_urls'] ?? source['imageUrls'];
    if (listCandidate is List) {
      collected.addAll(
        listCandidate
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final singleCandidates = [
      source['image_url'],
      source['imageUrl'],
      source['media_url'],
      source['mediaUrl'],
    ];
    for (final value in singleCandidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) collected.add(text);
    }

    return _dedupUrls(collected);
  }

  void _applyFetchedPostData(Map<String, dynamic> source) {
    final content = _readStringFrom(source, ['content']);
    final location = _readStringFrom(source, [
      'location_label',
      'locationLabel',
      'location',
      'place',
      'address',
    ]);
    final tags = _readHashtagsFrom(source);
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

    if (_existingImageUrls.isEmpty && images.isNotEmpty) {
      _existingImageUrls
        ..clear()
        ..addAll(images);
    }
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
    final lieux = await LieuService.getLieux();
    if (!mounted) return;

    final selected = await Navigator.push<LieuModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LieuxMapScreen(lieux: lieux, selectionMode: true),
      ),
    );

    if (selected == null) return;
    setState(() {
      _locationCtrl.text = selected.titre;
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

  void _addTagsFromInput() {
    final extracted = _extractTagsFromInput(_tagsCtrl.text);
    if (extracted.isEmpty) return;

    setState(() {
      for (final tag in extracted) {
        if (!_hashtags.contains(tag)) {
          _hashtags.add(tag);
        }
      }
      _tagsCtrl.clear();
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

    final typedTags = _extractTagsFromInput(_tagsCtrl.text);
    final tags = <String>{..._hashtags, ...typedTags}.toList();

    final result = await PostService.updatePost(
      postId: postId,
      content: _contentCtrl.text.trim(),
      locationLabel: _locationCtrl.text.trim(),
      hashtags: tags,
      imageUrls: [..._existingImageUrls, ...uploadedUrls],
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

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F1FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F1FA),
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.primary),
          ),
          title: const Text(
            'Edit Post',
            style: TextStyle(
              color: Color(0xFF1F245A),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FF2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POST CONTENT',
                      style: TextStyle(
                        color: Color(0xFF8790BF),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentCtrl,
                      onChanged: (_) => _didEditContent = true,
                      minLines: 4,
                      maxLines: 6,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1F245A),
                        height: 1.35,
                      ),
                      decoration: const InputDecoration(
                        hintText: "What's happening in Djerba?",
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MANAGE MEDIA',
                      style: TextStyle(
                        color: Color(0xFF555C8F),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${_existingImageUrls.length + _newImages.length} Photos Selected',
                    style: const TextStyle(
                      color: Color(0xFF2051F2),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._existingImageUrls.asMap().entries.map(
                    (entry) => _ImageTile(
                      imageUrl: entry.value,
                      onRemove: () => setState(
                        () => _existingImageUrls.removeAt(entry.key),
                      ),
                    ),
                  ),
                  ..._newImages.asMap().entries.map(
                    (entry) => _ImageTile(
                      file: File(entry.value.path),
                      onRemove: () =>
                          setState(() => _newImages.removeAt(entry.key)),
                    ),
                  ),
                  _AddMediaTile(onTap: _addMoreImages),
                ],
              ),
              const SizedBox(height: 18),
              _InfoCard(
                icon: Icons.map_rounded,
                iconBg: const Color(0xFFC9CAF9),
                title: 'LOCATION',
                child: TextField(
                  controller: _locationCtrl,
                  readOnly: true,
                  onTap: _pickPlaceFromMap,
                  onChanged: (_) => _didEditLocation = true,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1F245A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Change Location',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFD6D9ED)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFD6D9ED)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF9BA6E8),
                        width: 1,
                      ),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_locationCtrl.text.trim().isNotEmpty)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _locationCtrl.clear();
                                _didEditLocation = true;
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF7C83AA),
                            ),
                          ),
                        IconButton(
                          onPressed: _pickPlaceFromDatabase,
                          icon: const Icon(
                            Icons.list_alt_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Choose from database',
                        ),
                        IconButton(
                          onPressed: _pickPlaceFromMap,
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Pick from map',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.tips_and_updates,
                iconBg: const Color(0xFFF3A5EB),
                title: 'GUIDANCE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _tagsCtrl,
                      onChanged: (_) => _didEditTags = true,
                      onSubmitted: (_) => _addTagsFromInput(),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1F245A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type tags then press +',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6D9ED),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6D9ED),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9BA6E8),
                            width: 1,
                          ),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _addTagsFromInput,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Add typed tags',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_hashtags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _hashtags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                onDeleted: () {
                                  setState(() {
                                    _hashtags.remove(tag);
                                    _didEditTags = true;
                                  });
                                },
                                deleteIcon: const Icon(Icons.close, size: 16),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _ImageTile({this.imageUrl, this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 132,
              height: 132,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    )
                  : Image.file(file!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 7,
            top: 7,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 33,
                height: 33,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D2B72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 18),
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
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE2FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFCBFF)),
        ),
        child: const Icon(
          Icons.add_photo_alternate,
          color: AppColors.primary,
          size: 32,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFECEBFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF4B4F90), size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF777EB0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                child,
              ],
            ),
          ),
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
