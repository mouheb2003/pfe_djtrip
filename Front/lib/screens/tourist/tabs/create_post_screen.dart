import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/lieu_model.dart';
import '../../../models/user_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/post_service.dart';
import '../../../theme/app_theme.dart';
import '../lieux_map_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final UserModel? user;

  const CreatePostScreen({super.key, this.user});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final List<XFile> _images = [];
  final List<String> _hashtags = [];

  bool _publishing = false;

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
    final lieux = await LieuService.getLieux();
    if (!mounted) return;

    final selected = await Navigator.push<LieuModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LieuxMapScreen(lieux: lieux, selectionMode: true),
      ),
    );

    if (selected == null) return;
    setState(() => _locationCtrl.text = selected.titre);
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

  Future<void> _publish() async {
    if (_publishing) return;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or at least one image.')),
      );
      return;
    }

    setState(() => _publishing = true);

    final imageUrls = <String>[];
    for (final img in _images) {
      final url = await PostService.uploadPostImage(File(img.path));
      if (url != null && url.isNotEmpty) imageUrls.add(url);
    }

    final result = await PostService.createPost(
      content: content,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      imageUrls: imageUrls,
      locationLabel: _locationCtrl.text.trim(),
      hashtags: _hashtags,
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

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

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
          'Create Post',
          style: TextStyle(
            color: Color(0xFF1B2458),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(_publishing ? 'Publishing...' : 'Publish'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: user?.avatar != null
                      ? NetworkImage(user!.avatar!)
                      : null,
                  child: user?.avatar == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullname ?? 'Traveler',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2458),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (user?.userType ?? 'Touriste').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D739A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _contentCtrl,
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                color: Color(0xFF3B4371),
              ),
              decoration: const InputDecoration(
                hintText: "What's happening in Djerba?",
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            _UploadButton(onTap: _pickImages, count: _images.length),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _ImagePreviewChip(
                    file: _images[i],
                    onRemove: () => setState(() => _images.removeAt(i)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.location_on,
                    label: _locationCtrl.text.isEmpty
                        ? 'Mention place'
                        : _locationCtrl.text,
                    onTap: _mentionPlace,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.tag,
                    label: _hashtags.isEmpty
                        ? 'Add hashtag'
                        : _hashtags.join(' '),
                    onTap: _addHashtag,
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
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
                style: const TextStyle(
                  color: Color(0xFF1B2458),
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
