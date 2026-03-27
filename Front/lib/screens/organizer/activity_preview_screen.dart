import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class ActivityPreviewScreen extends StatefulWidget {
  final String title;
  final String category;
  final String description;
  final double price;
  final int capacity;
  final String location;
  final double duration;
  final String durationLabel;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final List<XFile> photos;
  final List<String> requirements;
  final LatLng? pickedLatLng;

  const ActivityPreviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.capacity,
    required this.location,
    required this.duration,
    this.durationLabel = '',
    this.startDateTime,
    this.endDateTime,
    this.photos = const [],
    this.requirements = const [],
    this.pickedLatLng,
  });

  @override
  State<ActivityPreviewScreen> createState() => _ActivityPreviewScreenState();
}

class _ActivityPreviewScreenState extends State<ActivityPreviewScreen> {
  int _currentImage = 0;
  bool _showFullDesc = false;

  String get _prixFormatted {
    final p = widget.price;
    return '${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 2)} TND';
  }

  String get _dureeFormatted {
    if (widget.durationLabel.isNotEmpty) return widget.durationLabel;
    final h = widget.duration;
    if (h <= 0) return '–';
    final totalMin = (h * 60).round();
    final hrs = totalMin ~/ 60;
    final mins = totalMin % 60;
    if (hrs == 0) return '${mins} min';
    if (mins == 0) return '${hrs}h';
    return '${hrs}h ${mins}min';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photos.isNotEmpty;
    final photoCount = hasPhotos ? widget.photos.length : 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // â”€â”€ Image carousel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: Colors.black87,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_red_eye, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'PREVIEW MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasPhotos
                          ? PageView.builder(
                              itemCount: photoCount,
                              onPageChanged: (i) =>
                                  setState(() => _currentImage = i),
                              itemBuilder: (_, i) => Image.file(
                                File(widget.photos[i].path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                      // Dots
                      if (hasPhotos && photoCount > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              photoCount,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == _currentImage ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _currentImage
                                      ? Colors.white
                                      : Colors.white54,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title.isEmpty
                                  ? 'Activity title'
                                  : widget.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _prixFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Category + duration chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(
                            label: widget.category.isEmpty
                                ? 'Category'
                                : widget.category,
                            color: AppColors.primary.withOpacity(0.12),
                            textColor: AppColors.primary,
                          ),
                          _Chip(
                            icon: Icons.schedule,
                            label: _dureeFormatted,
                            color: Colors.grey[100]!,
                            textColor: AppColors.textGrey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // About
                      _SectionHeader('About this activity'),
                      const SizedBox(height: 8),
                      Text(
                      _showFullDesc
                          ? (widget.description.isEmpty
                                ? 'No description.'
                                : widget.description)
                          : () {
                              final d = widget.description.isEmpty
                                  ? 'No description.'
                                  : widget.description;
                                return d.length > 160
                                    ? '${d.substring(0, 160)}...'
                                    : d;
                              }(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                      if (widget.description.length > 160)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showFullDesc = !_showFullDesc),
                          child: Text(
                            _showFullDesc ? 'Show less' : 'Read more',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Info grid
                      Row(
                        children: [
                          _InfoBox(
                            icon: Icons.people,
                            label: 'Group size',
                            value: 'Up to ${widget.capacity}',
                          ),
                          const SizedBox(width: 12),
                          _InfoBox(
                            icon: Icons.schedule,
                            label: 'Duration',
                            value: _dureeFormatted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Requirements & Equipment
                      if (widget.requirements.isNotEmpty) ...[
                        _SectionHeader('Requirements & Equipment'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.requirements
                              .map(
                                (r) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(
                                        0.25,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        r,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Dates
                      if (widget.startDateTime != null) ...[
                        _SectionHeader('Date & Time'),
                        const SizedBox(height: 8),
                        _DateRow(
                          icon: Icons.play_circle,
                          label: 'Start',
                          value: DateFormat(
                            'dd/MM/yyyy at HH:mm',
                          ).format(widget.startDateTime!),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Location
                      _SectionHeader('Location'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.location.isEmpty
                                  ? 'Address not provided'
                                  : widget.location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.pickedLatLng != null
                            ? SizedBox(
                                height: 140,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: widget.pickedLatLng!,
                                    zoom: 14,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('preview'),
                                      position: widget.pickedLatLng!,
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  myLocationButtonEnabled: false,
                                  liteModeEnabled: true,
                                ),
                              )
                            : Container(
                                height: 140,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.map,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // â”€â”€ Back to Edit button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                label: const Text(
                  'Back to Edit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        '$label : ',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
    ],
  );
}
