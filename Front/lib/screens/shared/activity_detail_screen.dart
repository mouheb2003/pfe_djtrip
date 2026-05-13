import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/inscription_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../tourist/booking_detail_screen.dart';
import '../tourist/booking_selection_screen.dart';
import 'chat_conversation_screen.dart';
import 'public_profile_screen.dart';
import 'edit_review_modal.dart';
import 'add_review_modal.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool viewOnly;

  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.viewOnly = false,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen>
    with WidgetsBindingObserver {
  bool _showFullDesc = false;
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentImage = 0;
  ActivityModel? _activity;
  String _currentUserId = '';
  String _currentUserType = '';
  bool _loadingActivity = true;
  bool _isBooking = false;
  InscriptionModel? _bookingForActivity;
  List<InscriptionModel> _participants = [];
  bool _loadingParticipants = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = false;
  String? _errorMsg;

  // Ongoing review state
  int _activityRating = 0;
  int _organizerRating = 0;
  bool _isSubmittingReview = false;
  final _reviewController = TextEditingController();

  final _images = const [
    // Djerba beach images - using reliable URLs
    'https://picsum.photos/seed/djerba-beach-1/1600/900.jpg',
    'https://picsum.photos/seed/djerba-beach-2/1600/900.jpg',
    // Djerba palm trees and landscape
    'https://picsum.photos/seed/djerba-palms/1600/900.jpg',
    'https://picsum.photos/seed/djerba-landscape/1600/900.jpg',
    // Djerba culture and architecture
    'https://picsum.photos/seed/djerba-culture/1600/900.jpg',
    'https://picsum.photos/seed/djerba-architecture/1600/900.jpg',
  ];

  List<String> get _displayImages {
    final photos = _activity?.photos ?? const <String>[];
    final List<String> extractedUrls = [];
    final urlRegExp = RegExp(r'https?://[^"\\]+');

    for (final p in photos) {
      final matches = urlRegExp.allMatches(p);
      for (final m in matches) {
        final url = m.group(0)!.replaceAll('\\/', '/');
        if (url.contains('cloudinary.com') ||
            url.contains('.jpg') ||
            url.contains('.png') ||
            url.contains('.jpeg')) {
          extractedUrls.add(url);
        }
      }
    }
    // Only use default images if NO images are provided
    if (extractedUrls.isEmpty) return _images;
    return extractedUrls;
  }

  String get _description => (_activity?.description ?? '').trim().isNotEmpty
      ? _activity!.description
      : 'No description available.';

  LatLng? get _meetingPoint {
    final coords = _activity?.coordonnees;
    if (coords == null) return null;
    final latRaw = coords['latitude'] ?? coords['lat'];
    final lngRaw = coords['longitude'] ?? coords['lng'];
    if (latRaw is! num || lngRaw is! num) return null;
    return LatLng(latRaw.toDouble(), lngRaw.toDouble());
  }

  bool get _canContactOrganizer {
    final organizer = _activity?.organisateur;
    final organizerId = (organizer?['_id'] ?? organizer?['id'] ?? '')
        .toString()
        .trim();
    if (organizerId.isEmpty) return false;
    if (_currentUserId.isEmpty) return true;
    return organizerId != _currentUserId;
  }

  bool get _isTouristUser {
    final role = _currentUserType.trim().toLowerCase();
    return role == 'touriste' || role == 'tourist';
  }

  bool get _isOrganizerUser {
    final role = _currentUserType.trim().toLowerCase();
    return role == 'organisator' ||
        role == 'organisateur' ||
        role == 'organizer';
  }

  String _generateActivityMessage() {
    if (_activity == null) return '';

    final title = _activity!.titre.isNotEmpty
        ? _activity!.titre
        : (_activity!.title ?? 'Activity');
    final date = _activity!.dateDebut != null
        ? _fmtDate(_activity!.dateDebut)
        : 'Date TBD';
    final location = (_activity!.lieu ?? _activity!.formattedLieu ?? '')
        .toString()
        .trim();
    final price = _activity!.prix > 0
        ? '${_activity!.prix.toStringAsFixed(2)} TND'
        : 'Price N/A';

    return [
      'This User Contacted you about Your Activity "$title".',
      '',
      'Activity details:',
      '• Date: $date',
      '• Location: ${location.isNotEmpty ? location : 'Not specified'}',
      '• Price: $price',
    ].join('\n');
  }

  bool get _isActivityOrganizer {
    if (_activity == null || _currentUserId.isEmpty) return false;
    final organizer = _activity?.organisateur;
    final organizerId = (organizer?['_id'] ?? organizer?['id'] ?? '')
        .toString()
        .trim();
    return organizerId == _currentUserId;
  }

  bool get _hasBookingForActivity {
    final booking = _bookingForActivity;
    if (booking == null) return false;
    // If cancelled, allow rebooking (Participate button)
    return !booking.isCancelled;
  }

  bool get _canCancelBooking {
    final booking = _bookingForActivity;
    if (booking == null) return false;
    // Can cancel if pending or approved, and not already cancelled or rejected
    return (booking.isPending || booking.isApproved) &&
        !booking.isCancelled &&
        !booking.isRejected;
  }

  bool get _hasAlreadyReviewedActivity {
    if (_reviews.isEmpty) return false;
    return _reviews.any((review) {
      final touristeId =
          review['touriste_id']?['_id']?.toString() ??
          review['touriste_id']?['id']?.toString() ??
          '';
      return touristeId == _currentUserId;
    });
  }

  /// Check if a participant can be displayed based on privacy settings
  bool _canDisplayParticipant(Map<String, dynamic> participant) {
    if (participant.isEmpty) return false;

    // Extract ID from both possible structures (same logic as in logging)
    String participantUserId = '';
    if (participant['touriste']?['_id'] != null) {
      participantUserId = participant['touriste']['_id'].toString();
    } else if (participant['touriste_id']?['_id'] != null) {
      participantUserId = participant['touriste_id']['_id'].toString();
    } else {
      participantUserId =
          (participant['touriste']?['_id'] ??
                  participant['touriste']?['id'] ??
                  '')
              .toString();
    }

    if (participantUserId.isEmpty) return false;

    print(
      '🔍 [PARTICIPANT DEBUG FRONTEND] participantUserId: "$participantUserId"',
    );
    print('🔍 [PARTICIPANT DEBUG FRONTEND] _currentUserId: "$_currentUserId"');
    print(
      '🔍 [PARTICIPANT DEBUG FRONTEND] comparison result: ${participantUserId == _currentUserId}',
    );
    print(
      '🔍 [PARTICIPANT DEBUG FRONTEND] _isActivityOrganizer: $_isActivityOrganizer',
    );

    // Always show if viewer is the participant themselves (even if profileVisibility is false)
    // This is because a user can always see their own profile
    if (participantUserId == _currentUserId) return true;

    // Always show if viewer is activity organizer
    if (_isActivityOrganizer) return true;

    // Check participant's privacy settings
    final profileVisibility =
        participant['touriste']?['profileVisibility'] ?? true;
    print(
      '🔍 [PARTICIPANT DEBUG FRONTEND] profileVisibility: $profileVisibility',
    );

    return profileVisibility == true;
  }

  bool get _isPastActivity {
    final activity = _activity;
    if (activity == null) return false;
    return activity.isPast;
  }

  InscriptionModel? _latestBookingForActivity(
    String activityId,
    Map<String, List<InscriptionModel>> bookings,
  ) {
    InscriptionModel? latest;
    print('🔍 [LATEST BOOKING SEARCH] Searching for activity: $activityId');

    void collect(List<InscriptionModel> items) {
      for (final item in items) {
        final itemActivityId = (item.activite?['_id'] ?? '').toString();
        print(
          '🔍 [LATEST BOOKING SEARCH] Comparing activity ID: "$itemActivityId" vs "$activityId" - Match: ${itemActivityId == activityId}',
        );
        if (itemActivityId != activityId) continue;

        if (latest == null) {
          latest = item;
          print(
            '🔍 [LATEST BOOKING SEARCH] Set as first match: ${item.id} (Date: ${item.dateDemande})',
          );
          continue;
        }

        final currentDate = item.dateDemande;
        final previousDate = latest!.dateDemande;

        if (currentDate == null && previousDate != null) continue;
        if (currentDate != null && previousDate == null) {
          latest = item;
          print(
            '🔍 [LATEST BOOKING SEARCH] Updated to newer (null->date): ${item.id}',
          );
          continue;
        }
        if (currentDate != null &&
            previousDate != null &&
            currentDate.isAfter(previousDate)) {
          latest = item;
          print(
            '🔍 [LATEST BOOKING SEARCH] Updated to newer (date comparison): ${item.id}',
          );
        }
      }
    }

    collect(bookings['pending'] ?? const <InscriptionModel>[]);
    collect(bookings['confirmed'] ?? const <InscriptionModel>[]);
    collect(bookings['cancelled'] ?? const <InscriptionModel>[]);

    print('🔍 [LATEST BOOKING SEARCH] Final result: ${latest?.id ?? "null"}');
    return latest;
  }

  Future<void> _openBookingStatus() async {
    final booking = _bookingForActivity;
    if (booking == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(inscription: booking),
      ),
    );
  }

  String _getDateRangeLabel(ActivityModel a) {
    if (a.dateDebut == null) return '-';
    if (a.dateFin == null) return _fmtDate(a.dateDebut);

    // Check if on the same day
    bool sameDay =
        a.dateDebut!.year == a.dateFin!.year &&
        a.dateDebut!.month == a.dateFin!.month &&
        a.dateDebut!.day == a.dateFin!.day;

    if (sameDay) {
      final hh = a.dateFin!.hour.toString().padLeft(2, '0');
      final mm = a.dateFin!.minute.toString().padLeft(2, '0');
      return '${_fmtDate(a.dateDebut)} - $hh:$mm';
    } else {
      return '${_fmtDate(a.dateDebut)} - ${_fmtDate(a.dateFin)}';
    }
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }

  String _fmtCoords() {
    final point = _meetingPoint;
    if (point == null) return '-';
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _resetCarouselTimer();
    _loadActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload activity when app is resumed
    if (state == AppLifecycleState.resumed) {
      _loadActivity(isRefresh: true);
    }
  }

  @override
  void didUpdateWidget(ActivityDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔍 [ACTIVITY DETAIL] didUpdateWidget called');
    print('🔍 [ACTIVITY DETAIL] Old activityId: ${oldWidget.activityId}');
    print('🔍 [ACTIVITY DETAIL] New activityId: ${widget.activityId}');
    // Only reload activity when activityId actually changes
    if (widget.activityId != oldWidget.activityId) {
      _loadActivity(isRefresh: true);
    }
  }

  void _resetCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      final images = _displayImages;
      if (images.length <= 1) return;
      if (_pageController.hasClients) {
        int nextPage = _currentImage + 1;
        if (nextPage >= images.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carouselTimer?.cancel();
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity({bool isRefresh = false}) async {
    try {
      print(
        '🔍 Loading activity with ID: ${widget.activityId} (isRefresh: $isRefresh)',
      );
      if (widget.activityId.isEmpty) throw Exception('Activity ID is empty');
      final results = await Future.wait([
        ActivityService.getActivityById(widget.activityId),
        AuthService.getUserId(),
        AuthService.getUserType(),
      ]);
      if (!mounted) return;

      final userType = (results[2] as String? ?? '').trim();
      InscriptionModel? booking;
      final role = userType.toLowerCase();
      if (role == 'touriste' || role == 'tourist') {
        final bookings = await InscriptionService.getMyBookings();
        if (!mounted) return;
        print(
          '🔍 [ACTIVITY DETAIL] Bookings loaded - pending: ${bookings['pending']?.length ?? 0}, confirmed: ${bookings['confirmed']?.length ?? 0}, cancelled: ${bookings['cancelled']?.length ?? 0}, used: ${bookings['used']?.length ?? 0}',
        );
        print('🔍 [ACTIVITY DETAIL] Activity ID: ${widget.activityId}');
        for (final entry in bookings.entries) {
          print('🔍 [ACTIVITY DETAIL] Bucket "${entry.key}":');
          for (final item in entry.value) {
            print(
              '  - Inscription ID: ${item.id}, Status: ${item.statut}, Activity ID: ${item.activite?['_id'] ?? 'N/A'}',
            );
          }
        }
        booking = _latestBookingForActivity(widget.activityId, bookings);
        print(
          '🔍 [ACTIVITY DETAIL] Latest booking found: ${booking?.id ?? 'null'} (Status: ${booking?.statut ?? 'N/A'})',
        );
      }

      setState(() {
        // Preserve existing activity data on refresh if API returns null
        final newActivity = results[0] as ActivityModel?;
        print(
          '🔍 New activity data: ${newActivity?.titre ?? 'null'}, Existing activity: ${_activity?.titre ?? 'null'}',
        );
        if (!isRefresh || newActivity != null) {
          _activity = newActivity;
          print('✅ Updated activity to: ${_activity?.titre ?? 'null'}');
        } else {
          print('🔒 Preserving existing activity data during refresh');
        }
        _currentUserId = (results[1] as String? ?? '').trim();
        _currentUserType = userType;
        _bookingForActivity = booking;
        _loadingActivity = false;
      });

      print('✅ Activity loaded successfully: ${_activity?.titre ?? 'null'}');

      // Load reviews after activity is loaded
      _loadReviews();
      _loadParticipants();
    } catch (e) {
      print('❌ Error loading activity: $e');
      if (mounted) {
        setState(() {
          _loadingActivity = false;
          // Only set activity to null on initial load error, preserve data on refresh error
          if (!isRefresh) {
            _activity = null;
            print('❌ Set activity to null (initial load error)');
          } else {
            print('🔒 Preserving existing activity data on refresh error');
          }
        });
      }
    }
  }

  void _checkReservationStatus() {
    final booking = _bookingForActivity;
    if (booking == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(inscription: booking),
      ),
    );
  }

  Future<void> _bookActivity() async {
    if (_activity == null) return;
    setState(() => _isBooking = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSelectionScreen(activity: _activity!),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _deletePendingBooking() async {
    final booking = _bookingForActivity;
    if (booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBooking = true);
    try {
      bool success = false;
      if (booking.canBeCancelledWithTime) {
        success = await InscriptionService.cancelInscription(booking.id);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadActivity(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This reservation can no longer be cancelled.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _loadParticipants() async {
    if (_activity == null) return;
    // Allow all users to see participants, but apply privacy filtering
    if (!(_activity!.isOngoing || _activity!.isPast)) {
      print(
        '🔍 [PARTICIPANTS] Activity not ongoing/past, skipping participants load',
      );
      return;
    }

    setState(() => _loadingParticipants = true);
    try {
      print(
        '🔍 [PARTICIPANTS] Loading participants for activity: ${widget.activityId}',
      );
      print('🔍 [PARTICIPANTS] Current user ID: $_currentUserId');
      print('🔍 [PARTICIPANTS] Current user type: $_currentUserType');
      print('🔍 [PARTICIPANTS] Is activity organizer: $_isActivityOrganizer');
      print(
        '🔍 [PARTICIPANTS] Activity organizer ID: ${_activity?.organisateur?['_id']}',
      );

      // Use public endpoint - any authenticated user can see participants
      print('🔍 [PARTICIPANTS] Using public endpoint for participants...');
      final participants = await InscriptionService.getActivityParticipants(
        activiteId: widget.activityId,
      );
      print(
        '🔍 [PARTICIPANTS] Total participants loaded from API: ${participants.length}',
      );

      // Log each participant's privacy details
      for (int i = 0; i < participants.length; i++) {
        final participant = participants[i];
        final participantData = participant.toJson();
        print('🔍 [PARTICIPANT $i] RAW DATA: ${participantData}');

        // Extract ID from both possible structures
        String participantUserId = '';
        if (participantData['touriste']?['_id'] != null) {
          participantUserId = participantData['touriste']['_id'].toString();
        } else if (participantData['touriste_id']?['_id'] != null) {
          participantUserId = participantData['touriste_id']['_id'].toString();
        } else {
          participantUserId =
              (participantData['touriste']?['_id'] ??
                      participantData['touriste']?['id'] ??
                      '')
                  .toString();
        }

        final profileVisibility =
            participantData['touriste']?['profileVisibility'] ?? true;
        final canDisplay = _canDisplayParticipant(participantData);

        print('🔍 [PARTICIPANT $i] ID: $participantUserId');
        print('🔍 [PARTICIPANT $i] ProfileVisibility: $profileVisibility');
        print(
          '🔍 [PARTICIPANT $i] Is current user: ${participantUserId == _currentUserId}',
        );
        print('🔍 [PARTICIPANT $i] Can display: $canDisplay');
        print('🔍 [PARTICIPANT $i] ---');
      }

      if (mounted) {
        setState(() {
          _participants = participants;
          _loadingParticipants = false;
        });
      }

      // Log filtering results
      final visibleParticipants = participants
          .where((p) => _canDisplayParticipant(p.toJson()))
          .toList();
      final hiddenParticipants = participants
          .where((p) => !_canDisplayParticipant(p.toJson()))
          .toList();
      print(
        '🔍 [PARTICIPANTS] Visible participants: ${visibleParticipants.length}',
      );
      print(
        '🔍 [PARTICIPANTS] Hidden participants: ${hiddenParticipants.length}',
      );
    } catch (e) {
      print('❌ [PARTICIPANTS] Error loading participants: $e');
      print('❌ [PARTICIPANTS] Error type: ${e.runtimeType}');
      print('❌ [PARTICIPANTS] Error details: ${e.toString()}');

      if (mounted) {
        setState(() {
          _participants = [];
          _loadingParticipants = false;
        });
      }
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      print('🔍 Loading reviews for activity: ${widget.activityId}');
      final reviews = await ReviewService.getActivityReviews(widget.activityId);
      print('🔍 Reviews loaded: ${reviews.length} reviews');
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      print('❌ Error loading reviews: $e');
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadActivity(isRefresh: true);
    await _loadReviews();
  }

  Future<void> _submitOngoingReview() async {
    if (_activityRating == 0 && _organizerRating == 0) {
      setState(() => _errorMsg = 'Please provide at least one rating.');
      return;
    }

    setState(() {
      _isSubmittingReview = true;
      _errorMsg = null;
    });

    try {
      // Submit activity review if rated
      if (_activityRating > 0) {
        await ReviewService.createReview(
          activiteId: widget.activityId,
          note: _activityRating,
          commentaire: _reviewController.text.trim(),
        );
      }

      // Submit organizer review if rated
      if (_organizerRating > 0 && _activity?.organisateur != null) {
        final organizerId =
            (_activity?.organisateur?['_id'] ?? _activity?.organisateur?['id'])
                .toString();
        if (organizerId.isNotEmpty) {
          await ReviewService.createOrganizerReview(
            organisateurId: organizerId,
            note: _organizerRating,
            commentaire: _reviewController.text.trim(),
          );
        }
      }

      if (mounted) {
        setState(() {
          _activityRating = 0;
          _organizerRating = 0;
          _reviewController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadReviews(); // Reload reviews to show the new one
      }
    } catch (e) {
      print('❌ Error submitting review: $e');
      if (mounted) {
        setState(
          () => _errorMsg = 'Failed to submit review. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  /// Scroll to review section when user clicks "Review" button
  void _scrollToReviewSection() {
    final ScrollController scrollController = PrimaryScrollController.of(
      context,
    );
    if (scrollController != null) {
      // Find the review section in the scroll view
      // Scroll to the review section (approximately at 0.7 of the total scroll extent)
      scrollController.animateTo(
        scrollController.position.maxScrollExtent * 0.7,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Show add review modal for ongoing activities
  void _showAddReviewModal(BuildContext context) {
    if (_activity?.organisateur == null) return;

    final organizerId =
        (_activity?.organisateur?['_id'] ?? _activity?.organisateur?['id'])
            .toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddReviewModal(
        activityId: widget.activityId,
        organizerId: organizerId,
        onReviewAdded: () {
          Navigator.of(context).pop();
          _loadReviews(); // Reload reviews to show the new one
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingActivity) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activity = _activity;
    if (activity == null) {
      return const Scaffold(body: Center(child: Text('Activity not found.')));
    }

    final locationType = activity.locationType?.trim().toLowerCase();
    final hasItinerary =
        locationType == 'itinerary' ||
        (activity.itineraireSteps != null &&
            activity.itineraireSteps!.isNotEmpty) ||
        (activity.itineraire != null &&
            activity.itineraire!.trim().isNotEmpty) ||
        (activity.itineraireCoords != null &&
            activity.itineraireCoords!.isNotEmpty);
    final showItinerary = hasItinerary;
    final showLocation = !showItinerary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 400,
                        width: double.infinity,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) =>
                              setState(() => _currentImage = i),
                          itemCount: _displayImages.length,
                          itemBuilder: (ctx, i) => Image.network(
                            _displayImages[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        left: 16,
                        child: _TopIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _HeroSummaryCard(activity: activity),
                        const SizedBox(height: 20),
                        _SectionTitle('Description'),
                        Text(
                          _description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _SectionTitle('Included Equipment'),
                        _TagListSection(
                          items: activity.equipementsInclus,
                          emptyLabel: 'No equipment specified',
                          icon: Icons.check_circle,
                          chipColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          iconColor: Theme.of(context).colorScheme.primary,
                        ),
                        _SectionTitle('What to Bring'),
                        _TagListSection(
                          items: activity.aApporter,
                          emptyLabel: 'Nothing special is required',
                          icon: Icons.shopping_basket_outlined,
                          chipColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          iconColor: Theme.of(context).colorScheme.primary,
                        ),
                        if (showLocation) ...[
                          _SectionTitle('Location'),
                          _LocationCard(
                            placeLabel: activity.lieu,
                            meetingPoint: _meetingPoint,
                          ),
                        ],
                        if (showItinerary) ...[
                          _SectionTitle('Itinerary'),
                          _ItineraryCard(
                            itinerary: activity.itineraire ?? '',
                            itinerarySteps: activity.itineraireSteps,
                            itineraryCoords: activity.itineraireCoords,
                          ),
                        ],
                        _SectionTitle('Organizer'),
                        _OrganizerCard(
                          organizer: activity.organisateur,
                          canContact: _isTouristUser && _canContactOrganizer,
                          onTap: () {
                            final orgId =
                                (activity.organisateur?['_id'] ??
                                        activity.organisateur?['id'] ??
                                        '')
                                    .toString()
                                    .trim();
                            if (orgId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PublicProfileScreen(userId: orgId),
                                ),
                              );
                            }
                          },
                          onContact: () {
                            final organizer = activity.organisateur;
                            final orgId =
                                (organizer?['_id'] ?? organizer?['id'] ?? '')
                                    .toString()
                                    .trim();
                            if (orgId.isEmpty) return;

                            final orgName =
                                (organizer?['fullname'] ?? 'Organizer')
                                    .toString();
                            final orgAvatar = organizer?['avatar']?.toString();
                            final orgOnline = organizer?['isOnline'] == true;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(
                                  partnerId: orgId,
                                  partnerName: orgName,
                                  partnerAvatar: orgAvatar,
                                  partnerType: 'Organisator',
                                  partnerOnline: orgOnline,
                                  initialMessage: _generateActivityMessage(),
                                ),
                              ),
                            );
                          },
                        ),
                        // Participants section (visible to all users for ongoing/past activities)
                        if ((_activity?.isOngoing == true ||
                            _activity?.isPast == true)) ...[
                          _SectionTitle('Participants'),
                          if (_loadingParticipants)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_participants.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                'No participants yet for this Activity.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ..._participants
                                .where(
                                  (participant) => _canDisplayParticipant(
                                    participant.toJson(),
                                  ),
                                )
                                .map(
                                  (participant) => _ParticipantCard(
                                    participant: participant,
                                    currentUserId: _currentUserId,
                                  ),
                                )
                                .toList(),
                          // Show privacy notice if some participants are hidden
                          if (_participants.any(
                            (p) => !_canDisplayParticipant(p.toJson()),
                          ))
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.privacy_tip_outlined,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Some participants have chosen to keep their profiles private.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        // Activity Review Section (for participants only - ongoing ONLY)
                        if (_activity?.isOngoing == true &&
                            _hasBookingForActivity &&
                            !_isActivityOrganizer &&
                            !_hasAlreadyReviewedActivity) ...[
                          _SectionTitle('Rate Your Experience'),
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Share your experience while the activity is ongoing!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Activity Rating
                                Text(
                                  'Rate this activity',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(5, (index) {
                                    return IconButton(
                                      icon: Icon(
                                        index < _activityRating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFF59E0B),
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _activityRating = index + 1,
                                        );
                                      },
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                // Organizer Rating
                                Text(
                                  'Rate the organizer',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(5, (index) {
                                    return IconButton(
                                      icon: Icon(
                                        index < _organizerRating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFF59E0B),
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _organizerRating = index + 1,
                                        );
                                      },
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                // Comment
                                TextField(
                                  controller: _reviewController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Share your experience...',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isSubmittingReview
                                        ? null
                                        : _submitOngoingReview,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSubmittingReview
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Submit Review',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (!_loadingReviews)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SectionTitle('Reviews'),
                              // Add Review Button for participants who haven't reviewed yet (ongoing activities ONLY)
                              if (_hasBookingForActivity &&
                                  !_isActivityOrganizer &&
                                  !_hasAlreadyReviewedActivity &&
                                  _activity?.isOngoing == true)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // Show add review modal instead of scrolling
                                    _showAddReviewModal(context);
                                  },
                                  icon: const Icon(Icons.rate_review, size: 16),
                                  label: const Text('Review'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (_loadingReviews)
                          const Center(child: CircularProgressIndicator())
                        else if (_reviews.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: const Text(
                              'No reviews yet. Be the first to review!',
                              style: TextStyle(color: Color(0xFF6B7280)),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._reviews
                              .map(
                                (review) => _ReviewCard(
                                  review: review,
                                  currentUserId: _currentUserId,
                                  onReviewUpdated: _loadReviews,
                                ),
                              )
                              .toList(),
                        // Reviews are now available for both ongoing and completed activities
                        // No need to show "reviews will be available" message anymore
                        if (_hasBookingForActivity &&
                            !_isActivityOrganizer) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFDBEAFE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_outlined,
                                        color: Color(0xFF3B82F6),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Reservation Status',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'You already have a reservation for this activity.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _openBookingStatus,
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Check Reservation Status',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.viewOnly && !_isActivityOrganizer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyBottomBar(
                price: activity.prixFormatted,
                showPrice: !_hasBookingForActivity,
                buttonLabel: _hasBookingForActivity
                    ? 'Check reservation status'
                    : 'Participate',
                isCancel: false,
                onBook: _isBooking
                    ? null
                    : (_hasBookingForActivity
                          ? _checkReservationStatus
                          : _bookActivity),
                isLoading: _isBooking,
                showDeleteButton: _hasBookingForActivity,
                deleteIcon: Icons.cancel_outlined,
                onDelete: _deletePendingBooking,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final ActivityModel activity;
  const _HeroSummaryCard({required this.activity});

  String _displayStatus(ActivityModel activity) {
    final timeline = activity.timelineStatus.toUpperCase();
    if (timeline == 'PAST') return 'COMPLETED';
    if (timeline == 'ONGOING') return 'ONGOING';
    return 'UPCOMING';
  }

  String _formatStartDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E8F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF3049D9)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'upcoming') {
      return const Color(0xFF3049D9);
    }
    if (normalized == 'ongoing') {
      return const Color(0xFF059669);
    }
    if (normalized == 'completed') {
      return const Color(0xFF6B7280);
    }
    if (normalized == 'active') {
      return const Color(0xFF2F55EB);
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    final badgeStatus = _displayStatus(activity);
    final ratingText = activity.noteMoyenne.toStringAsFixed(1);
    final activityType = activity.typeActivite.trim().isNotEmpty
        ? activity.typeActivite
        : (activity.categorie.trim().isNotEmpty
              ? activity.categorie
              : 'Activity');
    final languages = activity.languesFormatted.trim().isEmpty
        ? '-'
        : activity.languesFormatted;
    final statusColor = _statusColor(badgeStatus);
    final participants = activity.capaciteMax > 0
        ? '${activity.capaciteMax} max'
        : '-';
    final reviewsCount = activity.nombreAvis > 0
        ? '(${activity.nombreAvis} avis)'
        : '(0 avis)';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE8FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activityType.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3049D9),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: Color(0xFFF6C24A)),
                    const SizedBox(width: 5),
                    Text(
                      '$ratingText $reviewsCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF545273),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activity.titre,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.02,
              color: Color(0xFF17183D),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _infoTile(
                    icon: Icons.event,
                    label: 'Date debut',
                    value: _formatStartDate(activity.dateDebut),
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.timer,
                    label: 'Duree',
                    value: activity.dureeFormatted,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.group,
                    label: 'Capacite',
                    value: participants,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.payments_outlined,
                    label: 'Prix / personne',
                    value: activity.prixFormatted,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.language,
                    label: 'Langues',
                    value: languages,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final InscriptionModel participant;
  final String currentUserId;

  const _ParticipantCard({
    required this.participant,
    required this.currentUserId,
  });

  String _participantName() {
    final touriste = participant.touriste;
    print('🔍 [CARD DEBUG] participant.touriste: $touriste');

    if (touriste != null && touriste is Map<String, dynamic>) {
      final name = (touriste['fullname'] ?? '').toString().trim();
      print('🔍 [CARD DEBUG] extracted name: "$name"');
      if (name.isNotEmpty) return name;
    }

    // Show "X places" for group bookings instead of "Participant"
    final places = participant.nombreParticipants ?? 1;
    print('🔍 [CARD DEBUG] using places: $places');
    return '$places place${places > 1 ? 's' : ''}';
  }

  String _participantAvatar() {
    final touriste = participant.touriste;
    if (touriste != null && touriste is Map<String, dynamic>) {
      return (touriste['avatar'] ?? '').toString();
    }
    return '';
  }

  String _participantId() {
    final touriste = participant.touriste;
    if (touriste != null && touriste is Map<String, dynamic>) {
      return (touriste['_id'] ?? touriste['id'] ?? '').toString().trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final name = _participantName();
    final avatar = _participantAvatar();
    final participantId = _participantId();
    final nbParticipants = participant.nombreParticipants ?? 1;
    final bookingDate = participant.dateDemande;

    // Check if this is the current user
    final isCurrentUser = participantId == currentUserId;

    // Check privacy settings
    final touriste = participant.touriste;
    bool profileVisibility = true;
    if (touriste != null && touriste is Map<String, dynamic>) {
      profileVisibility = touriste['profileVisibility'] ?? true;
    }

    // If not current user and profileVisibility is false, show only alert
    if (!isCurrentUser && !profileVisibility) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_off, size: 20, color: AppColors.textGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This participant has chosen to keep their profile private',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        if (participantId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicProfileScreen(userId: participantId),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty ? const Icon(Icons.person, size: 24) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        '$nbParticipants place${nbParticipants > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (bookingDate != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D2652),
        ),
      ),
    );
  }
}

class _TagListSection extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  final IconData icon;
  final Color chipColor;
  final Color iconColor;

  const _TagListSection({
    required this.items,
    required this.emptyLabel,
    required this.icon,
    required this.chipColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (cleaned.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cleaned
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chipColor.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String placeLabel;
  final LatLng? meetingPoint;
  const _LocationCard({required this.placeLabel, required this.meetingPoint});

  @override
  Widget build(BuildContext context) {
    final markerId = const MarkerId('meeting_point');

    // Build markers and polyline from itinerary coordinates
    Set<Marker> markers = {};
    Set<Polyline> polylines = {};
    LatLng? cameraTarget;
    if (meetingPoint != null) {
      // Use single meeting point
      markers.add(
        Marker(
          markerId: markerId,
          position: meetingPoint!,
          infoWindow: InfoWindow(title: placeLabel),
        ),
      );
      cameraTarget = meetingPoint;
    }

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: cameraTarget == null
            ? Center(
                child: Text(
                  'Meeting point: $placeLabel',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: cameraTarget,
                      zoom: 12.0,
                    ),
                    markers: markers,
                    polylines: polylines,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        placeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final String itinerary;
  final List<Map<String, dynamic>>? itinerarySteps;
  final List<Map<String, dynamic>>? itineraryCoords;
  const _ItineraryCard({
    required this.itinerary,
    this.itinerarySteps,
    this.itineraryCoords,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer structured itinerary steps when available, otherwise fall back to text parsing.
    final steps = itinerarySteps != null && itinerarySteps!.isNotEmpty
        ? itinerarySteps!.map((step) => _formatStructuredStep(step)).toList()
        : _parseItinerarySteps(itinerary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: const Color(0xFF4A65E6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Journey Itinerary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF131E32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Visual timeline with steps
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;

            final location = _locationForStep(index);

            return _buildItineraryStep(index + 1, step, isLast, location);
          }).toList(),
        ],
      ),
    );
  }

  String _formatStructuredStep(Map<String, dynamic> step) {
    final title = step['title']?.toString().trim() ?? '';
    final description = step['description']?.toString().trim() ?? '';
    final address = step['address']?.toString().trim() ?? '';
    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (description.isNotEmpty) parts.add(description);
    if (address.isNotEmpty) parts.add(address);
    return parts.isEmpty ? 'Step' : parts.join(' - ');
  }

  String _locationForStep(int index) {
    if (itinerarySteps != null && index < itinerarySteps!.length) {
      final step = itinerarySteps![index];
      final address = step['address']?.toString() ?? '';
      if (address.isNotEmpty) return address;
    }
    if (itineraryCoords != null &&
        itineraryCoords!.isNotEmpty &&
        index < itineraryCoords!.length) {
      final coord = itineraryCoords![index];
      return coord['address'] as String? ?? '';
    }
    return '';
  }

  List<String> _parseItinerarySteps(String itinerary) {
    // Split by newlines and filter out empty lines
    final lines = itinerary
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();

    // Check if this is the new structured format (Step X: description - address)
    final stepPattern = RegExp(r'^Step\s+(\d+):\s*(.+)$', caseSensitive: false);
    final structuredSteps = <String>[];

    for (final line in lines) {
      final match = stepPattern.firstMatch(line);
      if (match != null) {
        // Extract description from structured format
        final description = match.group(2) ?? line;

        // Remove address part if present (everything after " - ")
        final addressSeparatorIndex = description.indexOf(' - ');
        if (addressSeparatorIndex > 0) {
          final cleanDescription = description
              .substring(0, addressSeparatorIndex)
              .trim();
          structuredSteps.add(cleanDescription);
        } else {
          structuredSteps.add(description);
        }
      } else {
        // For non-structured format, keep the original line
        structuredSteps.add(line);
      }
    }

    // If we found structured steps, return them
    if (structuredSteps.isNotEmpty && structuredSteps.length == lines.length) {
      return structuredSteps;
    }

    // Fallback to original logic for old format
    if (lines.length == 1) {
      // Try to split by common time patterns
      final timePattern = RegExp(r'(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)');
      final matches = timePattern.allMatches(itinerary);

      if (matches.length > 1) {
        final steps = <String>[];
        int lastIndex = 0;

        for (int i = 0; i < matches.length; i++) {
          final match = matches.elementAt(i);
          if (i > 0) {
            steps.add(itinerary.substring(lastIndex, match.start).trim());
          }
          lastIndex = match.start;
        }

        // Add the last part
        if (lastIndex < itinerary.length) {
          steps.add(itinerary.substring(lastIndex).trim());
        }

        return steps.where((step) => step.isNotEmpty).toList();
      }
    }

    return lines;
  }

  Widget _buildItineraryStep(
    int stepNumber,
    String stepText,
    bool isLast,
    String location,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number with circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF4B63FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4B63FF).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Step content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Extract time if present
                  if (_extractTime(stepText) != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _extractTime(stepText)!,
                        style: const TextStyle(
                          color: Color(0xFF4B63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Step description
                  Text(
                    _removeTimeFromText(stepText),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF131E32),
                      height: 1.4,
                    ),
                  ),

                  // Location if available
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E9FF)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: const Color(0xFF4A65E6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A65E6),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Connection line (except for last step)
        if (!isLast) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 2,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF4B63FF).withOpacity(0.3),
                      const Color(0xFF4B63FF).withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  String? _extractTime(String text) {
    final timePattern = RegExp(r'(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)');
    final match = timePattern.firstMatch(text);
    return match?.group(1);
  }

  String _removeTimeFromText(String text) {
    final timePattern = RegExp(r'\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[-–—]\s*');
    return text.replaceFirst(timePattern, '').trim();
  }
}

class _OrganizerCard extends StatelessWidget {
  final Map<String, dynamic>? organizer;
  final VoidCallback onTap;
  final bool canContact;
  final VoidCallback? onContact;
  const _OrganizerCard({
    required this.organizer,
    required this.onTap,
    this.canContact = false,
    this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final name = (organizer?['fullname'] ?? 'Organizer').toString();
    final avatar = organizer?['avatar']?.toString() ?? '';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'View full profile',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            if (canContact && onContact != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF315CFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Contact',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final String price;
  final bool showPrice;
  final String buttonLabel;
  final VoidCallback? onBook;
  final bool isLoading;
  final bool showDeleteButton;
  final VoidCallback? onDelete;
  final IconData deleteIcon;
  final bool isCancel;
  const _StickyBottomBar({
    required this.price,
    required this.showPrice,
    required this.buttonLabel,
    required this.onBook,
    required this.isLoading,
    this.showDeleteButton = false,
    this.onDelete,
    this.deleteIcon = Icons.delete_outline,
    this.isCancel = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showPrice) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TOTAL PRICE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B2452),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
          ],
          if (showDeleteButton) ...[
            SizedBox(
              height: 56,
              width: 56,
              child: OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Icon(deleteIcon, size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCancel
                      ? Colors.red
                      : (showDeleteButton
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF3B82F6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        buttonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final String currentUserId;
  final VoidCallback? onReviewUpdated;
  const _ReviewCard({
    required this.review,
    required this.currentUserId,
    this.onReviewUpdated,
  });

  String _reviewerName() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final name = (touriste['fullname'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Tourist';
  }

  String _reviewerAvatar() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      return (touriste['avatar'] ?? '').toString();
    }
    return '';
  }

  String _reviewText() {
    final text = (review['commentaire'] ?? '').toString().trim();
    if (text.isEmpty) return 'No comment provided.';
    return text;
  }

  String _reviewDate() {
    final raw = (review['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  bool _isMyReview() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final touristeId = (touriste['_id'] ?? '').toString().trim();
      return touristeId == currentUserId;
    }
    return false;
  }

  void _showEditDeleteOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF4B63FF)),
              title: const Text('Edit Review'),
              onTap: () {
                Navigator.pop(context);
                _openEditModal(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Review'),
              onTap: () {
                Navigator.pop(context);
                _openDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditReviewModal(
        avisId: review['_id'].toString(),
        type: 'activite',
        initialRating: (review['note'] ?? 0).toDouble(),
        initialComment: review['commentaire']?.toString(),
        initialTags: review['tags'] is List
            ? List<String>.from(review['tags'] as List)
            : null,
        onReviewUpdated: onReviewUpdated,
        onReviewDeleted: onReviewUpdated,
      ),
    );
  }

  void _openDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final avisId = review['_id'].toString();
              final success = await ReviewService.deleteReview(avisId);
              if (success && onReviewUpdated != null) {
                onReviewUpdated!();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = (review['note'] ?? 0).toInt();
    final avatar = _reviewerAvatar();
    final isMyReview = _isMyReview();

    return InkWell(
      onLongPress: isMyReview ? () => _showEditDeleteOptions(context) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMyReview
                ? const Color(0xFF4B63FF)
                : const Color(0xFFE5E7EB),
            width: isMyReview ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _reviewerName(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (isMyReview) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4B63FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit,
                              size: 14,
                              color: Color(0xFF4B63FF),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: const Color(0xFFF59E0B),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _reviewDate(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _reviewText(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
            if (review['tags'] != null &&
                review['tags'] is List &&
                (review['tags'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (review['tags'] as List)
                      .map<Widget>(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9E8F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3049D9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (isMyReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Long press to edit or delete your review',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B63FF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
