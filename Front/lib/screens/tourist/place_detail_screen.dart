import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../shared/activity_detail_screen.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> place;

  const PlaceDetailScreen({super.key, required this.place});

  String get _title => (place['title'] ?? place['titre'] ?? 'Lieu').toString();
  String get _subtitle =>
      (place['subtitle'] ?? place['sousTitre'] ?? '').toString();
  String get _description =>
      (place['description'] ?? 'Aucune description disponible pour ce lieu.')
          .toString();
  String get _image =>
      (place['image'] ?? place['imagePortrait'] ?? '').toString();
  bool get _isTopDestination =>
      place['top_destination'] == true || place['topDestination'] == true;
  String get _rating =>
      (place['rating'] ??
              (place['noteMoyenne'] as num?)?.toStringAsFixed(1) ??
              '0.0')
          .toString();
  int get _reviewsCount => (place['nombreAvis'] as num?)?.toInt() ?? 0;
  String get _bestTime => (place['meilleurePeriode'] ?? 'N/A').toString();
  String get _duration => (place['dureeVisite'] ?? 'N/A').toString();
  String get _price => (place['price'] ?? place['prix'] ?? 'N/A').toString();
  String? get _activityId =>
      (place['activity_id'] ?? place['activiteLiee'])?.toString();
  double? get _lat => (place['coordonnees']?['latitude'] as num?)?.toDouble();
  double? get _lng => (place['coordonnees']?['longitude'] as num?)?.toDouble();

  List<String> get _tags {
    final raw = place['tags'];
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }

  Future<void> _openMap() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -24, 0),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildTags(),
                    const SizedBox(height: 24),
                    Text(
                      'A propos de $_title',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildLocationMap(),
                    const SizedBox(height: 100), // Space for bottom bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.3),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.3),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _image.isNotEmpty
                  ? _image
                  : 'https://plus.unsplash.com/premium_photo-1697730288131-6684ca63584b?q=80&w=800&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
            // Pagination dots (static for mockup)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_isTopDestination)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_activity,
                      color: AppColors.primary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'TOP DESTINATION',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const Icon(Icons.star, color: Colors.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              _rating,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              ' ($_reviewsCount reviews)',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF64748B), size: 16),
            const SizedBox(width: 6),
            Text(
              _subtitle,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTags() {
    final tags = _tags;
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    t,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(
          Icons.calendar_month,
          'BEST TIME',
          _bestTime,
          const Color(0xFFFFF5F0),
        ),
        _buildStatCard(
          Icons.access_time_filled,
          'DURATION',
          _duration,
          const Color(0xFFFFF5F0),
        ),
        _buildStatCard(
          Icons.payments,
          'PRICE',
          _price,
          const Color(0xFFF0FDF4),
          textColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color bgColor, {
    Color? textColor,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMap() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _openMap,
                  child: const Text(
                    'Full Map',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openMap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFFF3EFE0)),
              child: Stack(
                children: [
                  // Mock Map Image equivalent
                  Center(
                    child: Icon(
                      Icons.map,
                      size: 100,
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  if (_lat != null && _lng != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_outlined,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Directions',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final activityId = _activityId;
                if (activityId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ActivityDetailScreen(activityId: activityId),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_activity, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Book Guided Tour',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
