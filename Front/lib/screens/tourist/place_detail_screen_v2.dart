import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/maps/presentation/map_explorer_screen.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/lieu_service.dart';
import '../../services/review_service.dart';
import '../../services/place_service.dart';
import '../../utils/snackbar_utils.dart';
import 'view_all_places_screen.dart';
import '../shared/activity_detail_screen.dart';
import '../shared/bookmarked_items_screen.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/bookmark_provider.dart';

class PlaceDetailScreenV2 extends StatefulWidget {
  final dynamic place;
  const PlaceDetailScreenV2({super.key, required this.place});

  @override
  State<PlaceDetailScreenV2> createState() => _PlaceDetailScreenV2State();
}

class _PlaceDetailScreenV2State extends State<PlaceDetailScreenV2> {
  bool _showFull = false;
  bool _showLongDescription = false;
  int _currentImageIndex = 0;
  late PageController _pageController;
  Timer? _autoPlayTimer;
  bool _isLoadingActivities = false;
  bool _isSaved = false;
  bool _isSavingState = false;
  List<ActivityModel> _activities = const [];
  List<Map<String, dynamic>> _reviews = const [];
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmittingReview = false;
  Map<String, dynamic> _placeData = const {};
  String _currentUserId = '';
  String _currentUserDisplayName = '';

  Map<String, dynamic> get _place {
    if (_placeData.isNotEmpty) return _placeData;
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
    _placeData = _normalizePlace(widget.place);
    _pageController = PageController();
    _bootstrapData();
    _loadInitialBookmarkState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoPlay());
  }

  void _loadInitialBookmarkState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isInitiallySaved = _place['isBookmarked'] == true || _place['isSaved'] == true;
        Provider.of<BookmarkProvider>(context, listen: false)
            .updateLieuState(_reviewLieuId, isInitiallySaved);
      }
    });
  }

  Map<String, dynamic> _normalizePlace(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _stopAutoPlay();
    final imgs = _extractImages();
    if (imgs.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      final next = (_currentImageIndex + 1) % imgs.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() {
    try {
      _autoPlayTimer?.cancel();
    } catch (_) {}
    _autoPlayTimer = null;
  }

  void _restartAutoPlay() {
    _stopAutoPlay();
    // slight delay to avoid racing with onPageChanged animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _startAutoPlay();
    });
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

  String _contactFrom(List<String> keys, {String fallback = ''}) {
    final contactInfo = _place['contactInfo'];
    if (contactInfo is Map) {
      for (final key in keys) {
        final value = contactInfo[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
    }

    final contact = _place['contact'];
    if (contact is Map) {
      for (final key in keys) {
        final value = contact[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
    }

    final contactInfoSnake = _place['contact_info'];
    if (contactInfoSnake is Map) {
      for (final key in keys) {
        final value = contactInfoSnake[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
    }

    for (final key in keys) {
      final value = _place[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }

    return fallback;
  }

  String _firstPlaceValue(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _place[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  Map<String, double>? _extractCoordinates() {
    final latRaw = _place['latitude'] ?? _place['lat'];
    final lngRaw = _place['longitude'] ?? _place['lng'] ?? _place['lon'];
    final lat = latRaw is num
        ? latRaw.toDouble()
        : double.tryParse(latRaw?.toString() ?? '');
    final lng = lngRaw is num
        ? lngRaw.toDouble()
        : double.tryParse(lngRaw?.toString() ?? '');
    if (lat != null && lng != null) {
      return {'lat': lat, 'lng': lng};
    }

    final coord =
        _place['coordonnees'] ?? _place['coordinates'] ?? _place['location'];
    if (coord is Map) {
      double? lat;
      double? lng;
      for (final key in ['lat', 'latitude']) {
        final v = coord[key];
        if (v is num) lat = v.toDouble();
        if (v is String) lat ??= double.tryParse(v);
      }
      for (final key in ['lng', 'lon', 'longitude']) {
        final v = coord[key];
        if (v is num) lng = v.toDouble();
        if (v is String) lng ??= double.tryParse(v);
      }
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    final coordStr = _stringFrom(['coordonnees', 'coords', 'latlng']);
    if (coordStr.isNotEmpty && coordStr.contains(',')) {
      final parts = coordStr.split(',');
      final a = double.tryParse(parts[0].trim());
      final b = double.tryParse(parts[1].trim());
      if (a != null && b != null) return {'lat': a, 'lng': b};
    }

    return null;
  }

  Future<void> _openMap(String title, String subtitle) async {
    final coords = _extractCoordinates();
    if (coords != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapExplorerScreen(
            initialLatitude: coords['lat'],
            initialLongitude: coords['lng'],
            initialPlaceName: title,
            initialPlaceAddress: subtitle,
          ),
        ),
      );
      return;
    } else {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MapExplorerScreen()));
    }
  }

  Future<void> _openWebsite(String url) async {
    if (url.isEmpty) return;
    var parsed = url.trim();
    if (!parsed.startsWith('http')) parsed = 'https://$parsed';
    final uri = Uri.tryParse(parsed);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  String _shortDescription(String longDescription) {
    final direct = _stringFrom([
      'short_description',
      'shortDescription',
      'summary',
      'subtitle',
      'excerpt',
    ]);
    if (direct.isNotEmpty) return direct;

    final cleaned = longDescription.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'No description available.';

    final match = RegExp(r'^(.{0,180}?)([\.\!\?]|$)').firstMatch(cleaned);
    if (match != null) {
      final candidate = (match.group(1) ?? '').trim();
      if (candidate.isNotEmpty) return candidate;
    }

    return cleaned.length > 180
        ? '${cleaned.substring(0, 180).trim()}…'
        : cleaned;
  }

  String _reviewAuthorName(Map<String, dynamic> review) {
    String pickFromMap(Map<dynamic, dynamic> data, List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    final touristeId = review['touriste_id'];
    if (touristeId is Map) {
      final name = pickFromMap(touristeId, [
        'fullname',
        'fullName',
        'nom',
        'name',
        'username',
      ]);
      if (name.isNotEmpty) return name;
    }

    final touriste = review['touriste'];
    if (touriste is Map) {
      final name = pickFromMap(touriste, [
        'fullname',
        'fullName',
        'nom',
        'name',
        'username',
      ]);
      if (name.isNotEmpty) return name;
    }

    final user = review['user'];
    if (user is Map) {
      final name = pickFromMap(user, [
        'fullname',
        'fullName',
        'nom',
        'name',
        'username',
      ]);
      if (name.isNotEmpty) return name;
    }

    for (final key in [
      'authorName',
      'userName',
      'username',
      'nom',
      'name',
      'user_fullname',
      'user_full_name',
      'user_name',
    ]) {
      final text = review[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }

    final rawUserId =
        (review['user'] ??
                review['userId'] ??
                review['utilisateur'] ??
                review['user_id'] ??
                '')
            .toString()
            .trim();
    if (rawUserId.isNotEmpty &&
        rawUserId == _currentUserId &&
        _currentUserDisplayName.isNotEmpty) {
      return _currentUserDisplayName;
    }

    return 'User';
  }

  String _reviewAuthorAvatar(Map<String, dynamic> review) {
    String pickFromMap(Map<dynamic, dynamic> data, List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return '';
    }

    final touristeId = review['touriste_id'];
    if (touristeId is Map) {
      final avatar = pickFromMap(touristeId, ['avatar', 'photo', 'image']);
      if (avatar.isNotEmpty) return ApiConfig.getImageUrl(avatar);
    }

    final touriste = review['touriste'];
    if (touriste is Map) {
      final avatar = pickFromMap(touriste, ['avatar', 'photo', 'image']);
      if (avatar.isNotEmpty) return ApiConfig.getImageUrl(avatar);
    }

    final user = review['user'];
    if (user is Map) {
      final avatar = pickFromMap(user, ['avatar', 'photo', 'image']);
      if (avatar.isNotEmpty) return ApiConfig.getImageUrl(avatar);
    }

    final avatar = review['avatar']?.toString().trim() ?? '';
    if (avatar.isNotEmpty && avatar.toLowerCase() != 'null') {
      return ApiConfig.getImageUrl(avatar);
    }

    return '';
  }

  String _reviewSubmittedDate(Map<String, dynamic> review) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      final text = raw.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return null;
      return DateTime.tryParse(text);
    }

    final dt =
        parseDate(review['createdAt']) ??
        parseDate(review['dateDepot']) ??
        parseDate(review['date_depot']) ??
        parseDate(review['datePublication']) ??
        parseDate(review['date_publication']) ??
        parseDate(review['submittedAt']) ??
        parseDate(review['date']) ??
        parseDate(review['updatedAt']);

    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  String _displayNameFromUser(Map<String, dynamic> user) {
    final fullname = (user['fullname'] ?? user['fullName'] ?? '')
        .toString()
        .trim();
    if (fullname.isNotEmpty) return fullname;

    final firstName = (user['prenom'] ?? user['firstName'] ?? '')
        .toString()
        .trim();
    final lastName = (user['nom'] ?? user['lastName'] ?? '').toString().trim();
    final merged = '$firstName $lastName'.trim();
    if (merged.isNotEmpty) return merged;

    final username = (user['username'] ?? user['name'] ?? '').toString().trim();
    return username;
  }

  List<Map<String, dynamic>> _enrichLieuReviewsWithCurrentUserName(
    List<Map<String, dynamic>> reviews,
  ) {
    if (_currentUserId.isEmpty || _currentUserDisplayName.isEmpty) {
      return reviews;
    }

    return reviews
        .map((review) {
          final rawUserId =
              (review['user'] ??
                      review['userId'] ??
                      review['utilisateur'] ??
                      review['user_id'] ??
                      '')
                  .toString()
                  .trim();
          if (rawUserId == _currentUserId) {
            return {...review, 'authorName': _currentUserDisplayName};
          }
          return review;
        })
        .toList(growable: false);
  }

  bool _isCurrentUserReview(Map<String, dynamic> review) {
    if (_currentUserId.isEmpty) return false;
    final reviewUserId =
        (review['user'] ??
                review['userId'] ??
                review['utilisateur'] ??
                review['user_id'] ??
                '')
            .toString()
            .trim();
    return reviewUserId == _currentUserId;
  }

  void _editReview(Map<String, dynamic> review) {
    final comment = (review['commentaire'] ?? review['comment'] ?? '')
        .toString();
    final rating = review['note'] ?? review['rating'] ?? 0;

    _reviewController.text = comment;
    _selectedRating = (rating is num)
        ? rating.toInt()
        : int.tryParse(rating.toString()) ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Review'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _reviewController,
                decoration: const InputDecoration(hintText: 'Your comment'),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Rating: '),
                  ...List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        Icons.star,
                        color: index < _selectedRating
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _selectedRating = index + 1);
                        Navigator.pop(context);
                        _editReview(review);
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _submitEditReview(review),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEditReview(Map<String, dynamic> review) async {
    final comment = _reviewController.text.trim();
    if (comment.isEmpty || _selectedRating == 0) {
      SnackbarUtils.showWarning(context, 'Please add a comment and rating');
      return;
    }

    try {
      setState(() => _isSubmittingReview = true);

      final reviewId = review['_id'] ?? review['id'] ?? '';
      if (reviewId.isEmpty) {
        throw Exception('Review ID not found');
      }

      final response = await LieuService.updateReview(
        lieuId: _place['_id'].toString(),
        reviewId: reviewId,
        rating: _selectedRating,
        comment: comment,
      );

      if (response['success'] == true) {
        Navigator.pop(context);
        _reviewController.clear();
        _selectedRating = 0;
        SnackbarUtils.showSuccess(context, 'Review updated successfully');
        await _fetchReviews();
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Error updating review: $e');
    } finally {
      setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteReview(review);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteReview(Map<String, dynamic> review) async {
    try {
      setState(() => _isSubmittingReview = true);

      final reviewId = review['_id'] ?? review['id'] ?? '';
      if (reviewId.isEmpty) {
        throw Exception('Review ID not found');
      }

      final response = await LieuService.deleteReview(
        lieuId: _place['_id'].toString(),
        reviewId: reviewId,
      );

      if (response['success'] == true) {
        SnackbarUtils.showSuccess(context, 'Review deleted successfully');
        await _fetchReviews();
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Error deleting review: $e');
    } finally {
      setState(() => _isSubmittingReview = false);
    }
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

  Future<void> _fetchReviews() async {
    try {
      final lieuId = _place['_id'].toString();
      if (lieuId.isEmpty) return;

      final lieu = await LieuService.getLieuById(lieuId);
      if (lieu != null && mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(lieu['reviews'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching reviews: $e')));
      }
    }
  }

  Future<void> _bootstrapData() async {
    final currentUser = await AuthService.getUser();
    if (mounted && currentUser != null) {
      setState(() {
        _currentUserId = (currentUser['_id'] ?? '').toString().trim();
        _currentUserDisplayName = _displayNameFromUser(currentUser);
      });
    }

    final placeId = _stringFrom(['_id', 'id', 'lieu_id', 'lieuId']);
    if (placeId.isNotEmpty) {
      final remotePlace = await LieuService.getLieuById(placeId);
      if (mounted && remotePlace != null) {
        setState(() {
          _placeData = {..._place, ...remotePlace};
          if (_placeData['isBookmarked'] == true) {
            _isSaved = true;
          }
        });
      }
    }

    final localReviewsRaw = _place['reviews'];
    List<Map<String, dynamic>> localReviews = const [];
    if (localReviewsRaw is List) {
      localReviews = localReviewsRaw
          .whereType<Map>()
          .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      localReviews = _enrichLieuReviewsWithCurrentUserName(localReviews);
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
    print('DEBUG _reviewLieuId: $id');
    print('DEBUG _place keys: ${_place.keys.toList()}');
    return id;
  }

  Future<void> _toggleSave() async {
    final placeId = _reviewLieuId;
    if (placeId.isEmpty) {
      SnackbarUtils.showError(context, 'Impossible de sauvegarder');
      return;
    }

    setState(() => _isSavingState = true);

    try {
      final provider = Provider.of<BookmarkProvider>(context, listen: false);
      await provider.toggleLieuBookmark(placeId);
      final isNowSaved = provider.isLieuBookmarked(placeId);

      if (mounted) {
        if (isNowSaved) {
          SnackbarUtils.showSnackBar(
            context, 
            message: 'Ajouté aux favoris', 
            type: SnackBarType.success,
            actionLabel: 'See All',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BookmarkedItemsScreen(),
                ),
              );
            },
          );
        } else {
          SnackbarUtils.showInfo(context, 'Retiré des favoris');
        }
        setState(() => _isSavingState = false);
      }
    } catch (e) {
      print('DEBUG: Exception during toggleBookmark: $e');
      if (mounted) {
        setState(() => _isSavingState = false);
        SnackbarUtils.showError(context, '$e');
      }
    }
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
          final enrichedReviews = _enrichLieuReviewsWithCurrentUserName(
            latestReviews,
          );
          if (mounted && latestReviews.isNotEmpty) {
            setState(() {
              _reviews = enrichedReviews;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark ? const Color(0xFF121212) : Colors.white;
    final surface = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final surfaceAlt = isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);

    final title = _stringFrom([
      'name',
      'title',
      'titre',
    ], fallback: 'Unknown place');
    final address = _firstPlaceValue([
      'address',
      'formattedAddress',
      'formatted_address',
      'adresse',
      'location_name',
    ]);
    final city = _firstPlaceValue(['city']);
    final country = _firstPlaceValue(['country']);
    final subtitle = address.isNotEmpty
        ? address
        : [city, country].where((e) => e.isNotEmpty).join(', ');
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
    final hasLongDescription =
        description.trim().isNotEmpty &&
        description.trim().toLowerCase() != 'no description available.';
    final shortDescription = _shortDescription(description);
    final openingHours = _firstPlaceValue([
      'opening_hours',
      'openingHours',
      'openinghours',
      'horaires',
      'hours',
      'workingHours',
      'schedule',
    ]);
    final website = _contactFrom([
      'website',
      'webSite',
      'siteWeb',
      'site_web',
      'site',
      'booking_link',
      'url',
    ]);
    final phone = _contactFrom([
      'telephone',
      'phone',
      'tel',
      'phoneNumber',
      'phone_number',
      'formatted_phone_number',
      'mobile',
      'num_tel',
    ]);
    final email = _contactFrom([
      'email',
      'mail',
      'contact_email',
      'contactEmail',
    ]);
    final images = _extractImages();

    // Debug: log practical info values to help diagnose missing display
    debugPrint('PlaceDetail DEBUG title: $title');
    debugPrint('PlaceDetail DEBUG address/subtitle: $subtitle');
    debugPrint('PlaceDetail DEBUG openingHours: $openingHours');
    debugPrint('PlaceDetail DEBUG website: $website');
    debugPrint('PlaceDetail DEBUG phone: $phone');
    debugPrint('PlaceDetail DEBUG email: $email');

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          Consumer<BookmarkProvider>(
            builder: (context, provider, child) {
              final isSaved = provider.isLieuBookmarked(_reviewLieuId);
              return IconButton(
                onPressed: _isSavingState ? null : _toggleSave,
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: textPrimary,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: images.isNotEmpty
                                ? Listener(
                                    onPointerDown: (_) => _stopAutoPlay(),
                                    onPointerUp: (_) => _restartAutoPlay(),
                                    child: PageView.builder(
                                      controller: _pageController,
                                      physics: const PageScrollPhysics(),
                                      itemCount: images.length,
                                      onPageChanged: (idx) {
                                        setState(
                                          () => _currentImageIndex = idx,
                                        );
                                        _restartAutoPlay();
                                      },
                                      itemBuilder: (context, index) {
                                        final img = images[index];
                                        return img.isNotEmpty
                                            ? Image.network(
                                                ApiConfig.getImageUrl(img),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    color: Colors.white10,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color: Colors.white12,
                                                      child: const Center(
                                                        child: Icon(Icons.image, color: Colors.white54, size: 40),
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: Colors.grey[900],
                                                child: const Center(
                                                  child: Icon(Icons.image, color: Colors.white24, size: 40),
                                                ),
                                              );
                                      },
                                    ),
                                  )
                                : Container(color: Colors.grey[900]),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                      const SizedBox(height: 12),
                                      if (shortDescription.isNotEmpty)
                                        Text(
                                          shortDescription,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                          maxLines: _showFull ? null : 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (shortDescription.isNotEmpty)
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _showFull = !_showFull,
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            _showFull
                                                ? 'Show less'
                                                : 'Show more',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (images.length > 1)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) {
                                  final active = i == _currentImageIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: active ? 10 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? Colors.white
                                          : Colors.white38,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final img = images[i];
                            final selected = i == _currentImageIndex;
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                );
                                setState(() => _currentImageIndex = i);
                                _restartAutoPlay();
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF4B63FF)
                                          : borderColor,
                                      width: 2,
                                    ),
                                    color: surface,
                                  ),
                                  child: img.isNotEmpty
                                      ? Image.network(
                                          img,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 72,
                                          errorBuilder: (_, __, ___) =>
                                              Container(color: Colors.white12),
                                        )
                                      : Container(color: Colors.white12),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  if (hasLongDescription)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Long description',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            maxLines: _showLongDescription ? null : 4,
                            overflow: _showLongDescription
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          if (description.length > 180)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => setState(
                                  () => _showLongDescription =
                                      !_showLongDescription,
                                ),
                                child: Text(
                                  _showLongDescription
                                      ? 'Show less'
                                      : 'Show all',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (hasLongDescription) const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Info pratique',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location row with "See in map" action
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    subtitle.isNotEmpty
                                        ? subtitle
                                        : 'Not specified',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: subtitle.isNotEmpty
                                      ? () => _openMap(title, subtitle)
                                      : null,
                                  child: const Text('See in map'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Opening hours
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    openingHours.isNotEmpty
                                        ? openingHours
                                        : 'Not specified',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Website
                            Row(
                              children: [
                                const Icon(
                                  Icons.language,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: website.isNotEmpty
                                      ? TextButton(
                                          onPressed: () =>
                                              _openWebsite(website),
                                          child: Text(
                                            website,
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                      : Text(
                                          'Not specified',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Phone
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: phone.isNotEmpty
                                      ? TextButton(
                                          onPressed: () => _callPhone(phone),
                                          child: Text(
                                            phone,
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Not specified',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Email
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email.isNotEmpty ? email : 'Not specified',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Activities',
                          style: TextStyle(
                            color: textPrimary,
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
                              color: surface,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'No activities found for this place.',
                              style: TextStyle(color: textSecondary),
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
                                return InkWell(
                                  onTap: () {
                                    if (activity.id.trim().isEmpty) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ActivityDetailScreen(
                                          activityId: activity.id,
                                          viewOnly: !activity.isUpcoming,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 250,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      border: Border.all(color: borderColor),
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: surfaceAlt,
                                              image: photo.isNotEmpty
                                                  ? DecorationImage(
                                                      image: NetworkImage(
                                                        ApiConfig.getImageUrl(photo),
                                                      ),
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
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${activity.prixFormatted} • ${activity.dureeFormatted}',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Reviews',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surface,
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate this place',
                                style: TextStyle(
                                  color: textPrimary,
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
                                          : textSecondary,
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
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Write your comment...',
                                  hintStyle: TextStyle(
                                    color: textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: pageBackground,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4B63FF),
                                      width: 1.5,
                                    ),
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
                                    backgroundColor: const Color(0xFF4B63FF),
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
                              color: surface,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'No reviews yet.',
                              style: TextStyle(color: textSecondary),
                            ),
                          )
                        else
                          ..._reviews.take(4).map((review) {
                            final author = _reviewAuthorName(review);
                            final submittedDate = _reviewSubmittedDate(review);
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
                                color: surface,
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFF4B63FF).withOpacity(0.1),
                                        backgroundImage: _reviewAuthorAvatar(review).isNotEmpty
                                            ? NetworkImage(_reviewAuthorAvatar(review))
                                            : null,
                                        child: _reviewAuthorAvatar(review).isEmpty
                                            ? const Icon(Icons.person, size: 18, color: Color(0xFF4B63FF))
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              author,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (submittedDate.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  submittedDate,
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
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
                                        style: TextStyle(
                                          color: textSecondary,
                                        ),
                                      ),
                                      if (_isCurrentUserReview(review))
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _editReview(review);
                                            } else if (value == 'delete') {
                                              _deleteReview(review);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              [
                                                const PopupMenuItem<String>(
                                                  value: 'edit',
                                                  child: Text('Edit'),
                                                ),
                                                const PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                          icon: const Icon(
                                            Icons.more_vert,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (text.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        color: textSecondary,
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
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}
