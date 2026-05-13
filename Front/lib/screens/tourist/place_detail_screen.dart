import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/activity_model.dart';
import '../../models/lieu_model.dart';
import '../../services/activity_service.dart';
import '../../services/lieu_service.dart';
import '../../theme/app_theme.dart';
import '../shared/activity_detail_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final dynamic place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final PageController _imageController;
  Timer? _carouselTimer;
  int _currentImage = 0;
  bool _showFullDescription = false;
  bool _isLoading = true;
  String? _errorMessage;
  LieuModel? _place;
  List<ActivityModel> _associatedActivities = const [];
  final List<Map<String, dynamic>> _dynamicReviews = [];
  bool _isSubmittingReview = false;
  bool _isBookmarked = false;
  bool _isTogglingBookmark = false;

  LieuModel get _placeData {
    if (_place != null) return _place!;
    final source = widget.place;
    if (source is LieuModel) return source;
    if (source is Map<String, dynamic>) {
      return LieuModel.fromJson(source);
    }
    if (source is Map) {
      return LieuModel.fromJson(
        source.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    throw StateError('Unsupported place payload');
  }

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _isBookmarked = _placeData.isBookmarked;
    _startCarouselTimer();
    _loadContent();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_images.length <= 1) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_imageController.hasClients) return;

      final nextIndex = (_currentImage + 1) % _images.length;
      _imageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final initial = _placeData;
      var place = initial;

      if (initial.id.isNotEmpty) {
        final rawPlace = await LieuService.getLieuById(initial.id);
        if (rawPlace != null) {
          place = LieuModel.fromJson(rawPlace);
        }
      }

      final activities = await ActivityService.getAllActivities();
      final related = _filterAssociatedActivities(place, activities);

      if (!mounted) return;
      setState(() {
        _place = place;
        _associatedActivities = related;
        _isBookmarked = place.isBookmarked;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load place details.';
        _isLoading = false;
      });
    }
  }

  List<String> get _images {
    final raw = <String>{};
    final place = _placeData;
    for (final image in place.images) {
      if (image.trim().isNotEmpty) raw.add(image.trim());
    }
    if (place.imagePortrait.trim().isNotEmpty)
      raw.add(place.imagePortrait.trim());
    if (place.imagePaysage?.trim().isNotEmpty == true) {
      raw.add(place.imagePaysage!.trim());
    }
    if (raw.isEmpty && place.displayImage.isNotEmpty)
      raw.add(place.displayImage);
    return raw.isEmpty
        ? const [
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
          ]
        : raw.toList(growable: false);
  }

  List<Map<String, dynamic>> get _reviews {
    final base = _placeData.reviews;
    return [..._dynamicReviews, ...base];
  }

  void _showReviewDialog() {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Write a Review'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmittingReview
                  ? null
                  : () async {
                      final comment = commentController.text.trim();
                      if (comment.isEmpty) return;

                      setDialogState(() => _isSubmittingReview = true);
                      try {
                        final lieuId = _placeData.id;
                        if (lieuId.isNotEmpty) {
                          final res = await LieuService.addReview(
                            lieuId: lieuId,
                            rating: selectedRating,
                            comment: comment,
                          );
                          if (res['success'] == true) {
                            setState(() {
                              _dynamicReviews.insert(0, {
                                'user': 'You',
                                'comment': comment,
                                'rating': selectedRating,
                                'date': DateTime.now().toIso8601String(),
                              });
                            });
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                        }
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Review submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } finally {
                        if (mounted)
                          setDialogState(() => _isSubmittingReview = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmittingReview
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  String get _locationLabel {
    final place = _placeData;
    final parts = <String>[
      place.address,
      place.city,
      place.country,
    ].where((part) => part.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' • ');
    if (place.sousTitre.trim().isNotEmpty) return place.sousTitre.trim();
    return 'Location not specified';
  }

  String get _description {
    final place = _placeData;
    if (place.description.trim().isNotEmpty) return place.description.trim();
    return 'No description available for this place.';
  }

  String get _placeTypeLabel {
    final type = _placeData.categorie.trim();
    if (type.isNotEmpty) return type;
    return _placeData.categoryLabelEn;
  }

  String get _category => _placeData.categoryLabelEn;

  String get _priceText {
    final price = _placeData.prix.trim();
    return price.isEmpty ? 'Free' : price;
  }

  String get _telephone => (_placeData.telephone ?? '').trim();

  String get _website => (_placeData.website ?? '').trim();

  String get _openingHours {
    final value = _placeData.openingHours?.trim() ?? '';
    if (value.isNotEmpty) return value;
    final fallback = _placeData.closingHours?.trim() ?? '';
    return fallback.isNotEmpty ? fallback : 'Not specified';
  }

  double get _rating => _placeData.noteMoyenne;

  int get _reviewsCount => _placeData.nombreAvis;

  bool get _isFeatured => _placeData.topDestination;

  double? get _lat => _placeData.latitude;

  double? get _lng => _placeData.longitude;

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesPlace(ActivityModel activity, LieuModel place) {
    // 1. Comparaison par coordonnées (la plus précise)
    if (place.latitude != null &&
        place.longitude != null &&
        activity.coordonnees != null) {
      final actLat = (activity.coordonnees!['latitude'] as num?)?.toDouble();
      final actLng = (activity.coordonnees!['longitude'] as num?)?.toDouble();

      if (actLat != null && actLng != null) {
        // Distance approximative de 500m (0.005 degrés)
        final double threshold = 0.005;
        if ((actLat - place.latitude!).abs() < threshold &&
            (actLng - place.longitude!).abs() < threshold) {
          return true;
        }
      }
    }

    // 2. Comparaison textuelle intelligente
    final placeName = _normalize(place.titre);
    final activityLieu = _normalize(activity.lieu);
    final activityTitle = _normalize(activity.titre);

    // Si le nom du lieu est contenu dans le champ 'lieu' ou le 'titre' de l'activité
    if (activityLieu.contains(placeName) || placeName.contains(activityLieu)) {
      return true;
    }

    if (activityTitle.contains(placeName)) {
      return true;
    }

    // 3. Vérification des étapes de l'itinéraire (si présentes)
    if (activity.itineraire != null) {
      final itinerary = _normalize(activity.itineraire!);
      if (itinerary.contains(placeName)) {
        return true;
      }
    }

    return false;
  }

  List<ActivityModel> _filterAssociatedActivities(
    LieuModel place,
    List<ActivityModel> activities,
  ) {
    final matched = activities.where((activity) {
      final isActiveTimeline = activity.isUpcoming || activity.isOngoing;
      return isActiveTimeline && _matchesPlace(activity, place);
    }).toList();

    matched.sort((a, b) {
      final aPriority = a.isOngoing ? 0 : 1;
      final bPriority = b.isOngoing ? 0 : 1;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      final aDate = a.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    return matched;
  }

  Future<void> _openMap() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWebsite() async {
    if (_website.isEmpty) return;

    final parsed = Uri.tryParse(_website);
    final uri = parsed != null && parsed.hasScheme
        ? parsed
        : Uri.tryParse('https://$_website');
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openActivity(ActivityModel activity) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activityId: activity.id),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_isTogglingBookmark) return;

    final placeId = _placeData.id;
    if (placeId.isEmpty) return;

    setState(() => _isTogglingBookmark = true);

    try {
      final res = await LieuService.toggleLieuBookmark(placeId);
      if (res['success'] == true) {
        setState(() {
          _isBookmarked = res['bookmarked'] == true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isBookmarked ? 'Added to bookmarks' : 'Removed from bookmarks',
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: _isBookmarked ? Colors.green : Colors.grey[800],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isTogglingBookmark = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _placeData.id.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        edgeOffset: 340, // Positionne l'indicateur sous l'image
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.18),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.18),
                  child: IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                      color: _isBookmarked ? Colors.amber : Colors.white,
                    ),
                    onPressed: _isTogglingBookmark ? null : _toggleBookmark,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _imageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _images.length,
                    onPageChanged: (value) {
                      setState(() => _currentImage = value);
                      // Reset timer on manual or auto change to maintain 5s delay
                      _carouselTimer?.cancel();
                      _startCarouselTimer();
                    },
                    itemBuilder: (_, index) {
                      return Image.network(
                        _images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE2E8F0),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 42,
                          ),
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xAA0F172A),
                            Color(0x220F172A),
                            Color(0xCC0F172A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_images.length, (index) {
                          final active = index == _currentImage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 7,
                            width: active ? 22 : 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 44,
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                              ),
                              child: const Text(
                                'Top destination',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            _placeData.titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chip(
                              Icons.category_rounded,
                              _category,
                              const Color(0xFFE0E7FF),
                              const Color(0xFF1D4ED8),
                            ),
                            _chip(
                              Icons.star_rounded,
                              _rating.toStringAsFixed(1),
                              const Color(0xFFFFEDD5),
                              const Color(0xFFB45309),
                            ),
                            _chip(
                              Icons.chat_bubble_rounded,
                              '$_reviewsCount reviews',
                              const Color(0xFFF1F5F9),
                              const Color(0xFF475569),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _descriptionBlock(),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _miniInfo(
                              Icons.location_on_rounded,
                              _placeData.address.isNotEmpty
                                  ? _placeData.address
                                  : 'Address not specified',
                            ),
                            _miniInfo(
                              Icons.location_city_rounded,
                              _placeData.city.isNotEmpty
                                  ? _placeData.city
                                  : 'City not specified',
                            ),
                            _miniInfo(Icons.category_rounded, _placeTypeLabel),
                            _miniInfo(Icons.attach_money_rounded, _priceText),
                            _miniInfo(
                              Icons.event_available_rounded,
                              _placeData.bookingRequired == true
                                  ? 'Booking required'
                                  : 'Walk-in friendly',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Practical Info',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoLine(
                          Icons.access_time_rounded,
                          'Opening hours',
                          _openingHours,
                        ),
                        const SizedBox(height: 10),
                        _infoLine(
                          Icons.phone_rounded,
                          'Telephone',
                          _telephone.isNotEmpty ? _telephone : 'Not specified',
                        ),
                        const SizedBox(height: 10),
                        _infoLine(
                          Icons.language_rounded,
                          'Website',
                          _website.isNotEmpty ? _website : 'Not specified',
                          onTap: _website.isNotEmpty ? _openWebsite : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('Reviews'),
                      TextButton.icon(
                        onPressed: _showReviewDialog,
                        icon: const Icon(Icons.add_comment_rounded, size: 18),
                        label: const Text('Write a review'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_reviews.isNotEmpty)
                    ..._reviews
                        .take(5)
                        .map(
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReviewCard(review: review),
                          ),
                        )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'No reviews yet. Be the first to share your thoughts!',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _sectionTitle('Associated Activities'),
                  const SizedBox(height: 10),
                  if (_associatedActivities.isEmpty)
                    _sectionCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.event_busy_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No upcoming or ongoing activities are currently linked to this place.',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._associatedActivities.map(
                      (activity) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AssociatedActivityCard(
                          activity: activity,
                          onTap: () => _openActivity(activity),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  if (_lat != null && _lng != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openMap,
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text('Open in Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
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
    ),
  );
}

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionBlock() {
    final text = _description;
    final shouldCollapse = text.length > 220;
    final visibleText = _showFullDescription || !shouldCollapse
        ? text
        : '${text.substring(0, 220).trimRight()}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visibleText,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF334155),
          ),
        ),
        if (shouldCollapse) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () =>
                setState(() => _showFullDescription = !_showFullDescription),
            child: Text(
              _showFullDescription ? 'See less' : 'See more',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoLine(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF475569)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: content,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final author =
        (review['user'] ?? review['name'] ?? review['author'] ?? 'Visitor')
            .toString();
    final comment =
        (review['comment'] ?? review['text'] ?? 'No comment provided.')
            .toString();
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final date = DateTime.tryParse(
      (review['date'] ?? review['createdAt'] ?? '').toString(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE0E7FF),
                child: Text(
                  author.isNotEmpty
                      ? author
                            .substring(0, math.min(1, author.length))
                            .toUpperCase()
                      : 'V',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final active = index < rating.round();
                  return Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: active ? Colors.amber : const Color(0xFFE2E8F0),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(color: Color(0xFF334155), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AssociatedActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const _AssociatedActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = activity.photos.isNotEmpty ? activity.photos.first : '';
    final statusLabel = activity.isOngoing ? 'Ongoing' : 'Upcoming';
    final statusColor = activity.isOngoing
        ? const Color(0xFF059669)
        : const Color(0xFF2563EB);
    final date = activity.dateDebut != null
        ? '${activity.dateDebut!.day.toString().padLeft(2, '0')}/${activity.dateDebut!.month.toString().padLeft(2, '0')}/${activity.dateDebut!.year}'
        : 'Date TBD';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(22),
              ),
              child: SizedBox(
                width: 118,
                height: 118,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _activityPlaceholder(),
                      )
                    : _activityPlaceholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          activity.prixFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activity.formattedLieu,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
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

  Widget _activityPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Icon(
        Icons.hiking_rounded,
        color: Color(0xFF64748B),
        size: 32,
      ),
    );
  }
}