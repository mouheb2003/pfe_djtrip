import 'package:flutter/material.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/lieu_service.dart';
import '../../services/review_service.dart';

class PlaceDetailScreenV2 extends StatefulWidget {
  final dynamic place;
  const PlaceDetailScreenV2({super.key, required this.place});

  @override
  State<PlaceDetailScreenV2> createState() => _PlaceDetailScreenV2State();
}

class _PlaceDetailScreenV2State extends State<PlaceDetailScreenV2> {
  bool _showFull = false;
  bool _isLoadingActivities = false;
  List<ActivityModel> _activities = const [];
  List<Map<String, dynamic>> _reviews = const [];
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmittingReview = false;

  Map<String, dynamic> get _place {
    final raw = widget.place;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  @override
  void initState() {
    super.initState();
    _bootstrapData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String _stringFrom(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _place[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  double _doubleFrom(List<String> keys, {double fallback = 0}) {
    for (final key in keys) {
      final value = _place[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  int _intFrom(List<String> keys, {int fallback = 0}) {
    for (final key in keys) {
      final value = _place[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  List<String> _extractImages() {
    final images = <String>[];
    final gallery = _place['gallery'];
    final rawImages = _place['images'];

    void addFrom(dynamic source) {
      if (source is List) {
        for (final item in source) {
          final url = item?.toString().trim() ?? '';
          if (url.isNotEmpty && !images.contains(url)) {
            images.add(url);
          }
        }
      }
    }

    addFrom(gallery);
    addFrom(rawImages);

    final mainImage = _stringFrom([
      'main_image',
      'imagePortrait',
      'image',
      'displayImage',
    ]);
    if (mainImage.isNotEmpty && !images.contains(mainImage)) {
      images.insert(0, mainImage);
    }

    return images;
  }

  Future<void> _bootstrapData() async {
    final localReviewsRaw = _place['reviews'];
    List<Map<String, dynamic>> localReviews = const [];
    if (localReviewsRaw is List) {
      localReviews = localReviewsRaw
          .whereType<Map>()
          .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }

    if (mounted) {
      setState(() {
        _reviews = localReviews;
      });
    }

    final placeActivityId = _stringFrom([
      'activity_id',
      'activiteLiee',
      'activite_id',
    ]);
    final placeTitle = _stringFrom(['name', 'title', 'titre']);

    setState(() {
      _isLoadingActivities = true;
    });

    final loadedActivities = <ActivityModel>[];

    if (placeActivityId.isNotEmpty) {
      final activity = await ActivityService.getActivityById(placeActivityId);
      if (activity != null) {
        loadedActivities.add(activity);
      }

      if (_reviews.isEmpty) {
        final remoteReviews = await ReviewService.getActivityReviews(
          placeActivityId,
        );
        if (mounted && remoteReviews.isNotEmpty) {
          setState(() {
            _reviews = remoteReviews;
          });
        }
      }
    }

    if (loadedActivities.isEmpty) {
      final allActivities = await ActivityService.getActivities(refresh: true);
      if (allActivities.isNotEmpty) {
        final filtered = allActivities
            .where((activity) {
              if (placeActivityId.isNotEmpty &&
                  activity.id == placeActivityId) {
                return true;
              }
              if (placeTitle.isEmpty) return false;
              return activity.lieu.toLowerCase().contains(
                placeTitle.toLowerCase(),
              );
            })
            .take(6)
            .toList();
        loadedActivities.addAll(filtered);
      }
    }

    if (!mounted) return;
    setState(() {
      _activities = loadedActivities;
      _isLoadingActivities = false;
    });
  }

  String get _reviewActivityId {
    final placeActivityId = _stringFrom([
      'activity_id',
      'activiteLiee',
      'activite_id',
    ]);
    if (placeActivityId.isNotEmpty) return placeActivityId;
    if (_activities.isNotEmpty) return _activities.first.id;
    return '';
  }

  String get _reviewLieuId {
    final id = _stringFrom(['_id', 'id', 'lieu_id', 'lieuId']);
    return id;
  }

  Future<void> _submitReview() async {
    final activityId = _reviewActivityId;
    final lieuId = _reviewLieuId;

    if (activityId.isEmpty && lieuId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No place or linked activity found for review.'),
        ),
      );
      return;
    }

    if (_selectedRating <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    final comment = _reviewController.text.trim();

    Map<String, dynamic> result;
    if (activityId.isNotEmpty) {
      result = await ReviewService.createReview(
        activiteId: activityId,
        note: _selectedRating,
        commentaire: comment.isEmpty ? null : comment,
      );
    } else {
      result = await LieuService.addReview(
        lieuId: lieuId,
        rating: _selectedRating,
        comment: comment,
      );
    }

    if (!mounted) return;

    if (result['success'] == true) {
      _reviewController.clear();
      setState(() {
        _selectedRating = 0;
      });

      if (activityId.isNotEmpty) {
        final latestReviews = await ReviewService.getActivityReviews(
          activityId,
        );
        if (!mounted) return;
        setState(() {
          if (latestReviews.isNotEmpty) {
            _reviews = latestReviews;
          }
        });
      } else {
        final lieu = result['lieu'];
        if (lieu is Map && lieu['reviews'] is List) {
          final latestReviews = (lieu['reviews'] as List)
              .whereType<Map>()
              .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
          if (mounted && latestReviews.isNotEmpty) {
            setState(() {
              _reviews = latestReviews;
            });
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
    } else {
      final message = (result['message'] ?? 'Unable to submit review.')
          .toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    if (!mounted) return;
    setState(() {
      _isSubmittingReview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _stringFrom([
      'name',
      'title',
      'titre',
    ], fallback: 'Unknown place');
    final city = _stringFrom(['city']);
    final country = _stringFrom(['country']);
    final subtitle = [city, country].where((e) => e.isNotEmpty).join(', ');
    final ratingValue = _doubleFrom([
      'rating',
      'noteMoyenne',
      'note_moyenne',
    ], fallback: 0);
    final rating = ratingValue > 0 ? ratingValue.toStringAsFixed(1) : 'N/A';
    final reviewCount = _intFrom([
      'review_count',
      'nombreAvis',
      'nombre_avis',
    ], fallback: _reviews.length);
    final description = _stringFrom([
      'long_description',
      'description',
      'desc',
    ], fallback: 'No description available.');
    final openingHours = _stringFrom([
      'opening_hours',
      'openingHours',
    ], fallback: 'Not specified');
    final price = _stringFrom([
      'price_range',
      'price',
      'prix',
    ], fallback: 'Not specified');
    final header = _stringFrom([
      'main_image',
      'imagePortrait',
      'image',
      'displayImage',
    ]);
    final images = _extractImages();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: header.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(header),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey[900],
                        ),
                      ),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 24,
                        right: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const SizedBox(height: 6),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.orange,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$rating ($reviewCount)',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white24,
                              onPressed: () {},
                              child: const Icon(
                                Icons.bookmark_border,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            if (subtitle.isNotEmpty)
                              _infoPill(Icons.location_on, subtitle),
                            _infoPill(Icons.access_time, openingHours),
                            _infoPill(Icons.price_check, price),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'About',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                          maxLines: _showFull ? null : 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showFull = !_showFull),
                          child: Text(
                            _showFull ? 'Show less' : 'Read more',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Activities',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isLoadingActivities)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_activities.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'No activities found for this place.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _activities.length,
                              itemBuilder: (context, idx) {
                                final activity = _activities[idx];
                                final photo = activity.photos.isNotEmpty
                                    ? activity.photos.first
                                    : '';
                                return Container(
                                  width: 250,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: Colors.white24,
                                            image: photo.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(photo),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        activity.titre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${activity.prixFormatted} • ${activity.dureeFormatted}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Gallery',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (images.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'No gallery images available.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  images[i],
                                  width: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 120,
                                    color: Colors.white12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Reviews',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rate this place',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(5, (index) {
                                  final star = index + 1;
                                  final isOn = star <= _selectedRating;
                                  return IconButton(
                                    onPressed: _isSubmittingReview
                                        ? null
                                        : () => setState(
                                            () => _selectedRating = star,
                                          ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    icon: Icon(
                                      isOn
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: isOn
                                          ? Colors.orange
                                          : Colors.white54,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reviewController,
                                enabled: !_isSubmittingReview,
                                minLines: 2,
                                maxLines: 4,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Write your comment...',
                                  hintStyle: const TextStyle(
                                    color: Colors.white54,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white12,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSubmittingReview
                                      ? null
                                      : _submitReview,
                                  icon: _isSubmittingReview
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                  label: Text(
                                    _isSubmittingReview
                                        ? 'Submitting...'
                                        : 'Submit review',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C2A8),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_reviews.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'No reviews yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          ..._reviews.take(4).map((review) {
                            final author = (review['touriste'] is Map)
                                ? (review['touriste']['nom'] ??
                                          review['touriste']['name'] ??
                                          'User')
                                      .toString()
                                : (review['authorName'] ??
                                          review['userName'] ??
                                          'User')
                                      .toString();
                            final noteRaw = review['note'] ?? review['rating'];
                            final note = noteRaw is num
                                ? noteRaw.toDouble()
                                : double.tryParse(noteRaw?.toString() ?? '') ??
                                      0;
                            final text =
                                (review['commentaire'] ??
                                        review['comment'] ??
                                        '')
                                    .toString();

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          author,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.star,
                                        color: Colors.orange,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        note.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (text.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: const Color(0xFF071025),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C2A8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
