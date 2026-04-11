import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../shared/activity_detail_screen.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> place;

  const PlaceDetailScreen({super.key, required this.place});

  String get _name => (place['name'] ?? place['title'] ?? place['titre'] ?? 'Lieu').toString();
  String get _shortDescription =>
      (place['short_description'] ?? place['description'] ?? 'Aucune description disponible pour ce lieu.')
          .toString();
  String get _experienceDescription =>
      (place['experience_description'] ?? '').toString();
  String get _heritageHistory =>
      (place['heritage_history'] ?? '').toString();
  String get _mainImage =>
      (place['main_image'] ?? place['image'] ?? place['imagePortrait'] ?? '').toString();
  bool get _isFeatured =>
      place['is_featured'] == true || place['top_destination'] == true || place['topDestination'] == true;
  String get _rating =>
      (place['rating'] ??
              (place['noteMoyenne'] as num?)?.toStringAsFixed(1) ??
              '0.0')
          .toString();
  int get _reviewsCount => (place['review_count'] as num?)?.toInt() ?? (place['nombreAvis'] as num?)?.toInt() ?? 0;
  String get _city => (place['city'] ?? '').toString();
  String get _country => (place['country'] ?? '').toString();
  String get _openingHours => (place['opening_hours'] ?? '').toString();
  String get _closingHours => (place['closing_hours'] ?? '').toString();
  String get _languages => (place['languages_spoken'] as List?)?.join(', ') ?? '';
  bool get _bookingRequired => place['booking_required'] == true;
  String get _priceRange => (place['price_range'] ?? place['price'] ?? place['prix'] ?? 'N/A').toString();
  double? get _pricePerAdult => (place['price_per_adult'] as num?)?.toDouble();
  double? get _minPrice => (place['min_price'] as num?)?.toDouble();
  double? get _maxPrice => (place['max_price'] as num?)?.toDouble();
  String? get _activityId =>
      (place['activity_id'] ?? place['activiteLiee'])?.toString();
  double? get _lat => (place['coordinates']?['latitude'] as num?)?.toDouble() ?? (place['coordonnees']?['latitude'] as num?)?.toDouble();
  double? get _lng => (place['coordinates']?['longitude'] as num?)?.toDouble() ?? (place['coordonnees']?['longitude'] as num?)?.toDouble();

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
                    _buildLocationInfo(),
                    const SizedBox(height: 16),
                    _buildRatingInfo(),
                    const SizedBox(height: 16),
                    _buildTimingInfo(),
                    const SizedBox(height: 16),
                    _buildLanguageInfo(),
                    const SizedBox(height: 16),
                    _buildBookingInfo(),
                    const SizedBox(height: 16),
                    _buildPriceInfo(),
                    const SizedBox(height: 24),
                    _buildTheExperienceSection(),
                    const SizedBox(height: 24),
                    _buildHeritageHistorySection(),
                    const SizedBox(height: 24),
                    _buildExperienceHighlightsSection(),
                    const SizedBox(height: 24),
                    _buildIncludedServicesSection(),
                    const SizedBox(height: 24),
                    _buildGuestReviewsSection(),
                    const SizedBox(height: 120), // Space for bottom bar
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
              _mainImage.isNotEmpty
                  ? _mainImage
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
            if (_isFeatured)
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
          _name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _shortDescription,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Color(0xFF64748B), size: 16),
        const SizedBox(width: 6),
        Text(
          '$_city, $_country',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        if (_lat != null && _lng != null) ...[
          const SizedBox(width: 12),
          const Icon(Icons.gps_fixed, color: Color(0xFF64748B), size: 16),
          const SizedBox(width: 4),
          Text(
            '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildRatingInfo() {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.orange, size: 16),
        const SizedBox(width: 4),
        Text(
          _rating,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          ' ($_reviewsCount reviews)',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTimingInfo() {
    return Row(
      children: [
        const Icon(Icons.access_time, color: Color(0xFF64748B), size: 16),
        const SizedBox(width: 4),
        Text(
          'Timing: $_openingHours - $_closingHours',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLanguageInfo() {
    if (_languages.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.language, color: Color(0xFF64748B), size: 16),
        const SizedBox(width: 4),
        Text(
          'Languages: $_languages',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBookingInfo() {
    return Row(
      children: [
        const Icon(Icons.event_available, color: Color(0xFF64748B), size: 16),
        const SizedBox(width: 4),
        Text(
          'Booking: ${_bookingRequired ? "Required" : "Not Required"}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPriceInfo() {
    String priceText = _priceRange;
    if (_pricePerAdult != null) {
      priceText = 'Starting from ${_pricePerAdult!.toStringAsFixed(2)} TND / adult';
    } else if (_minPrice != null && _maxPrice != null) {
      priceText = '${_minPrice!.toStringAsFixed(0)}-${_maxPrice!.toStringAsFixed(0)} TND';
    }
    
    return Row(
      children: [
        const Icon(Icons.attach_money, color: Color(0xFF64748B), size: 16),
        const SizedBox(width: 4),
        Text(
          priceText,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTheExperienceSection() {
    if (_experienceDescription.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Experience',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _experienceDescription,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildHeritageHistorySection() {
    if (_heritageHistory.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Heritage & History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _heritageHistory,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceHighlightsSection() {
    final highlights = (place['experience_highlights'] as List?)?.whereType<String>().toList() ?? [];
    if (highlights.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Experience Highlights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...highlights.map((highlight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  highlight,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildIncludedServicesSection() {
    final amenities = (place['amenities'] as List?)?.whereType<String>().toList() ?? [];
    final wheelchairAccess = place['wheelchair_access'] == true;
    
    if (amenities.isEmpty && !wheelchairAccess) return const SizedBox.shrink();
    
    final services = <String>[...amenities];
    if (wheelchairAccess) services.add('Wheelchair Access');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Included Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: services.map((service) => _buildServiceItem(service)).toList(),
        ),
      ],
    );
  }

  Widget _buildServiceItem(String service) {
    IconData icon = Icons.check_circle_outline;
    if (service.toLowerCase().contains('wifi')) icon = Icons.wifi;
    if (service.toLowerCase().contains('parking')) icon = Icons.local_parking;
    if (service.toLowerCase().contains('drink') || service.toLowerCase().contains('snack')) icon = Icons.restaurant;
    if (service.toLowerCase().contains('wheelchair')) icon = Icons.accessible;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          service,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGuestReviewsSection() {
    final reviews = (place['reviews'] as List?) ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Guest Reviews',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...reviews.take(3).map((review) => _buildReviewItem(review)).toList(),
      ],
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = (review['comment'] ?? '').toString();
    final date = review['date'] != null 
        ? DateTime.tryParse(review['date'].toString())?.toString().split(' ')[0] ?? ''
        : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['user']?.toString() ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  ...List.generate(5, (index) => Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 16,
                  )),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    String priceText = _priceRange;
    if (_pricePerAdult != null) {
      priceText = '${_pricePerAdult!.toStringAsFixed(2)} TND';
    } else if (_minPrice != null && _maxPrice != null) {
      priceText = '${_minPrice!.toStringAsFixed(0)}-${_maxPrice!.toStringAsFixed(0)} TND';
    }
    
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
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Book Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
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
