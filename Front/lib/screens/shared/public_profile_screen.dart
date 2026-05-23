import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/activity_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/cache_manager.dart';
import '../../services/follow_service.dart';
import '../../services/inscription_service.dart';
import '../../services/post_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auto_image_carousel.dart';
import 'activity_detail_screen.dart';
import '../../widgets/publication_card.dart';
import '../../widgets/tiktok_share_widget.dart';
import 'chat_conversation_screen.dart';
import 'comments_screen.dart';
import 'edit_profile_screen.dart';
import '../settings/privacy_settings_screen.dart';
import 'relations_screen.dart';

/// Modern Public Profile Screen
/// Supports both Tourist and Organizer profiles with premium UI/UX
class PublicProfileScreen extends StatefulWidget {
  final String? userId;

  const PublicProfileScreen({super.key, this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with WidgetsBindingObserver {
  // State
  bool _isLoading = true;
  bool _isLoadingContent = false;
  Map<String, dynamic>? _userData;
  UserModel? _user;
  List<ActivityModel> _activities = [];
  List<PostModel> _posts = [];
  List<Map<String, dynamic>> _reviews = [];
  int _participatedActivities = 0;
  int _submittedReviews = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  final Set<String> _likedPostIds = {}; // Track locally liked posts

  // Pagination
  int _postsPage = 1;
  bool _hasMorePosts = true;
  final ScrollController _scrollController = ScrollController();

  // Activities display
  int _shownActivitiesCount = 6;
  int _activeTabIndex = 0; // 0: Activities, 1: Posts

  // Reviews auto-scroll
  late PageController _reviewsPageController;
  Timer? _autoScrollTimer;
  Timer? _presenceUpdateTimer;

  // Current user info
  String? _currentUserId;

  // Follow status
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  // Real-time location tracking
  Timer? _locationUpdateTimer;
  String? _currentLocation;
  bool _isAdmin = false;

  // Privacy settings change listener
  StreamSubscription<Map<String, dynamic>>? _privacySettingsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reviewsPageController = PageController(viewportFraction: 0.85);
    _initializeData();
    _scrollController.addListener(_onScroll);
    _startAutoScroll();
    _setupPrivacySettingsListener();
    _checkIfAdmin();
    _startRealTimeLocationUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload data when app is resumed
    if (state == AppLifecycleState.resumed) {
      _loadUserData(forceRefresh: true);
      // Restart location updates when app resumes
      if (_isAdmin) {
        _startRealTimeLocationUpdates();
      }
    }
  }

  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if userId changed or when screen is revisited
    if (widget.userId != oldWidget.userId) {
      debugPrint(
        '🔄 Profile changed from ${oldWidget.userId} to ${widget.userId} - refreshing data',
      );

      // Stop presence updates for old profile
      _presenceUpdateTimer?.cancel();

      // Reset user data to prevent showing old presence info
      setState(() {
        _userData = null;
        _user = null;
      });

      // Force cache invalidation for both old and new profiles
      if (oldWidget.userId != null) {
        CacheManager.instance.remove('GET:/users/${oldWidget.userId}');
        CacheManager.instance.removeByPattern(
          'GET:/users/${oldWidget.userId}*',
        );
      }
      if (widget.userId != null) {
        CacheManager.instance.remove('GET:/users/${widget.userId}');
        CacheManager.instance.removeByPattern('GET:/users/${widget.userId}*');
      }

      // Load new profile data with force refresh
      _loadUserData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _reviewsPageController.dispose();
    _autoScrollTimer?.cancel();
    _presenceUpdateTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _privacySettingsSubscription?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_reviews.length > 1) {
      _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_reviewsPageController.hasClients) {
          final currentPage = _reviewsPageController.page?.round() ?? 0;
          final nextPage = (currentPage + 1) % _reviews.length;
          _reviewsPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _toggleShowMoreActivities() {
    setState(() {
      if (_shownActivitiesCount >= _activities.length) {
        _shownActivitiesCount = 6; // Reset to initial state
      } else {
        _shownActivitiesCount = (_shownActivitiesCount + 6).clamp(
          6,
          _activities.length,
        );
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _initializeData() async {
    _currentUserId = await AuthService.getUserId();
    await _loadUserData(forceRefresh: true);
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    try {
      final targetId = widget.userId ?? _currentUserId;
      debugPrint('Loading user data for targetId: $targetId');
      if (targetId == null || targetId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      debugPrint(
        '🔄 Loading user data for: $targetId (forceRefresh: $forceRefresh)',
      );

      // Stop any existing presence updates before loading new data
      _presenceUpdateTimer?.cancel();

      // Users are now identified exclusively by their MongoDB ObjectId
      final userData = await UserService.getUserById(
        targetId!,
        forceRefresh: forceRefresh,
      );
      if (userData != null && mounted) {
        debugPrint('✅ User data loaded successfully');
        debugPrint(
          '🔍 New user presence data: isReallyOnline=${userData['isReallyOnline']}, lastActiveAt=${userData['lastActiveAt']}',
        );

        setState(() {
          _userData = userData;
          _user = UserModel.fromJson(userData!);
          _isLoading = false;
        });

        // Load role-specific content
        await _loadRoleSpecificContent(_user!);

        // Check follow status if viewing another user's profile
        if (targetId != _currentUserId && _currentUserId != null) {
          await _checkFollowStatus(targetId!);
        }

        // Start periodic presence updates for real-time status
        _startPresenceUpdates();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFollowStatus(String targetId) async {
    try {
      final isFollowing = await FollowService.checkFollowStatus(targetId);
      final followers = await FollowService.getFollowersList(targetId);
      final following = await FollowService.getFollowingList(targetId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _followersCount = followers.length;
          _followingCount = following.length;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  void _startPresenceUpdates() {
    _presenceUpdateTimer?.cancel();

    // Smart presence update: check every 10 seconds but only fetch if needed
    _presenceUpdateTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (_userData != null && mounted) {
        final targetId = widget.userId ?? _currentUserId;
        if (targetId != null) {
          try {
            // Check if we need to update based on lastActiveAt age
            final lastActiveAtString = _userData?['lastActiveAt']?.toString();
            if (lastActiveAtString != null && lastActiveAtString.isNotEmpty) {
              final lastActiveAt = DateTime.tryParse(lastActiveAtString);
              if (lastActiveAt != null) {
                final now = DateTime.now();
                final timeSinceLastActive = now.difference(lastActiveAt);

                // If user was online within last 70 seconds, check more frequently
                // If user was offline longer, check less frequently
                final shouldCheck =
                    timeSinceLastActive.inSeconds < 70 ||
                    timeSinceLastActive.inMinutes % 2 ==
                        0; // Every 2 minutes for offline users

                if (!shouldCheck) {
                  debugPrint(
                    '🔄 [PRESENCE] Skipping check for user: $targetId (offline: ${timeSinceLastActive.inMinutes}m ago)',
                  );
                  return;
                }
              }
            }

            debugPrint(
              '🔄 [PRESENCE] Updating presence data for user: $targetId',
            );

            // Force cache invalidation for real-time data
            CacheManager.instance.remove('GET:/users/$targetId');
            CacheManager.instance.removeByPattern('GET:/users/$targetId*');

            // Users are now identified exclusively by their MongoDB ObjectId
            final userData = await UserService.getUserById(
              targetId,
              forceRefresh: true,
            );
            if (userData != null && mounted) {
              final newIsOnline = userData['isReallyOnline'] ?? false;
              final newLastActiveAt = userData['lastActiveAt']?.toString();
              final currentIsOnline = _userData?['isReallyOnline'] ?? false;
              final currentLastActiveAt = _userData?['lastActiveAt']
                  ?.toString();

              debugPrint(
                '🔄 [PRESENCE] Status: $currentIsOnline → $newIsOnline, LastActive: $currentLastActiveAt → $newLastActiveAt',
              );

              // Update state if presence data changed
              if (newIsOnline != currentIsOnline ||
                  newLastActiveAt != currentLastActiveAt) {
                debugPrint('🔄 [PRESENCE] Status changed! Updating UI...');
                setState(() {
                  _userData = userData;
                  _user = UserModel.fromJson(userData!);
                });
              }
            }
          } catch (e) {
            debugPrint('Error updating presence data: $e');
          }
        }
      }
    });
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;

    final targetId = widget.userId ?? _currentUserId;
    if (targetId == null || targetId == _currentUserId) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        final result = await FollowService.unfollowUser(targetId);
        if (result['success'] == true && mounted) {
          setState(() {
            _isFollowing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unfollowed successfully')),
          );
        }
      } else {
        final result = await FollowService.followUser(targetId);
        if (result['success'] == true && mounted) {
          setState(() {
            _isFollowing = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Followed successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Future<void> _loadRoleSpecificContent(UserModel user) async {
    setState(() => _isLoadingContent = true);

    try {
      if (user.isOrganisator) {
        await _loadOrganizerContent(_userData?['_id']?.toString() ?? '');
      } else {
        await _loadTouristContent(_userData?['_id']?.toString() ?? '');
      }
    } catch (e) {
      debugPrint('Error loading role-specific content: $e');
    } finally {
      setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _loadOrganizerContent(String userId) async {
    debugPrint('Loading organizer content for userId: $userId');

    final targetId = (_userData?['_id'] ?? '').toString();
    debugPrint('Target ID for organizer: $targetId');

    // Use dedicated backend endpoint to get organizer's activities
    List<ActivityModel> organizerActivities = [];
    try {
      organizerActivities = await ActivityService.getActivitiesByOrganisateur(
        targetId,
        refresh: true,
      );
      debugPrint(
        'Organizer activities loaded from backend: ${organizerActivities.length}',
      );
    } catch (e) {
      debugPrint('Error loading organizer activities: $e');
    }

    // Load reviews submitted by tourists to this organizer
    List<Map<String, dynamic>> organizerReviews = [];
    try {
      organizerReviews = await ReviewService.getOrganizerReviews(targetId);
      debugPrint('Organizer reviews loaded: ${organizerReviews.length}');
      if (organizerReviews.isNotEmpty) {
        debugPrint('First review data: ${organizerReviews.first}');
      }
    } catch (e) {
      debugPrint('Error loading organizer reviews: $e');
    }

    setState(() {
      _activities = organizerActivities;
      _reviews = organizerReviews;
      _shownActivitiesCount = 6; // Reset to initial state on refresh
    });

    // Load posts for organizer as well
    try {
      final rawPosts = await PostService.getPublicUserPosts(targetId);
      setState(() {
        _posts = rawPosts.map((post) => PostModel.fromJson(post)).toList();
      });
      debugPrint('Organizer posts loaded: ${_posts.length}');
    } catch (e) {
      debugPrint('Error loading organizer posts: $e');
    }

    // Restart auto-scroll with new reviews
    _startAutoScroll();
  }

  Future<void> _loadTouristContent(String userId) async {
    debugPrint('Loading tourist content for userId: $userId');

    // Load posts from backend (includes authored posts and mentions)
    List<PostModel> userPosts = [];
    try {
      final targetId = (_userData?['_id'] ?? '').toString();
      debugPrint('Target ID for fetching posts: $targetId');

      final rawPosts = await PostService.getPublicUserPosts(targetId);
      userPosts = rawPosts.map((post) => PostModel.fromJson(post)).toList();

      debugPrint('Loaded user posts from backend: ${userPosts.length}');
    } catch (e) {
      debugPrint('Error loading user posts: $e');
    }

    // Load reviews submitted by tourist
    int submittedReviewsCount = 0;
    List<Map<String, dynamic>> touristReviews = [];
    try {
      final reviewsData = await ReviewService.getTouristeReviews(userId);
      submittedReviewsCount = reviewsData['count'] ?? 0;
      final rawAvis = reviewsData['avis'];
      if (rawAvis is List) {
        touristReviews = List<Map<String, dynamic>>.from(rawAvis);
      }
      debugPrint('Tourist submitted reviews: $submittedReviewsCount');
    } catch (e) {
      debugPrint('Error loading tourist reviews: $e');
    }

    // Load participated activities count (public endpoint)
    int participatedCount = 0;
    try {
      participatedCount = await InscriptionService.getTouristeParticipatedCount(
        userId,
      );
      debugPrint('Tourist participated activities: $participatedCount');
    } catch (e) {
      debugPrint('Error loading tourist participated count: $e');
    }

    debugPrint(
      'Tourist stats - posts: ${userPosts.length}, submitted reviews: $submittedReviewsCount, participated: $participatedCount',
    );

    // Initialize liked posts from post data
    _likedPostIds.clear();
    for (var post in userPosts) {
      if (post.isLiked) {
        _likedPostIds.add(post.id);
      }
    }

    setState(() {
      _posts = userPosts;
      _submittedReviews = submittedReviewsCount;
      _participatedActivities = participatedCount;
      _reviews = touristReviews;
      _hasMorePosts = userPosts.length >= 10;
    });
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _isLoadingContent) return;

    setState(() => _isLoadingContent = true);

    try {
      _postsPage++;
      // In a real implementation, you'd use pagination here
      // For now, we'll just mark as no more content
      setState(() => _hasMorePosts = false);
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _onRefresh() async {
    _postsPage = 1;
    _hasMorePosts = true;
    // Invalidate caches
    CacheManager.instance.removeByPattern('GET:/activites*');
    CacheManager.instance.removeByPattern('GET:/posts*');
    await _loadUserData(forceRefresh: true);
  }

  String _resolveUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    if (value.startsWith('/')) {
      return '$serverUrl$value';
    }
    return '$serverUrl/$value';
  }

  void _showAvatarFullScreen(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Avatar Full Screen',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                  Center(
                    child: Hero(
                      tag: 'public_profile_avatar',
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.70,
                        height: MediaQuery.of(context).size.width * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleContact() {
    if (_userData == null) return;

    final partnerId = _userData?['_id']?.toString() ?? '';
    final partnerName = (_userData?['fullname']?.toString() ?? '').trim();
    final partnerAvatar = _userData?['avatar']?.toString();
    final partnerOnline = _userData?['isOnline'] == true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          partnerId: partnerId,
          partnerName: partnerName.isEmpty ? 'User' : partnerName,
          partnerAvatar: partnerAvatar,
          partnerOnline: partnerOnline,
        ),
      ),
    );
  }

  void _handleShare() {
    if (_userData == null) return;
    final userId = _userData?['_id']?.toString() ?? '';
    final fullname = (_userData?['fullname']?.toString() ?? '').trim();
    final profileUrl = 'https://djtrip.com/profile/$userId';
    final text = 'Check out $fullname on DJTrip!';
    Share.share('$text\n$profileUrl');
  }

  Future<void> _launchPhone(String phone) async {
    // Clean phone number - remove spaces, dashes, etc.
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    debugPrint('🔍 DEBUG: Launching phone with clean number: $cleanPhone');

    // Try different URI formats for Android compatibility
    final List<Uri> phoneUris = [
      Uri(scheme: 'tel', path: cleanPhone),
      Uri(scheme: 'tel', path: phone), // Original format
    ];

    for (final phoneUri in phoneUris) {
      debugPrint('🔍 DEBUG: Trying phone URI: $phoneUri');

      try {
        if (await canLaunchUrl(phoneUri)) {
          debugPrint('🔍 DEBUG: Can launch phone, attempting...');
          final launched = await launchUrl(
            phoneUri,
            mode: LaunchMode.platformDefault,
          );

          if (launched) {
            debugPrint('🔍 DEBUG: Phone launch successful with URI: $phoneUri');
            return; // Success, exit the method
          }
        } else {
          debugPrint('🔍 DEBUG: Cannot launch phone with URI: $phoneUri');
        }
      } catch (e) {
        debugPrint('🔍 DEBUG: Error launching phone with URI $phoneUri: $e');
        continue; // Try next URI format
      }
    }

    // If all attempts failed
    debugPrint('🔍 DEBUG: All phone launch attempts failed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not launch phone app. Please check your device settings.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _launchEmail(String email) async {
    debugPrint('🔍 DEBUG: Launching email with address: $email');

    // Try different URI formats for Android compatibility
    final List<Uri> emailUris = [
      Uri(scheme: 'mailto', path: email),
      Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Contact from DJTrip',
      ), // With subject
    ];

    for (final emailUri in emailUris) {
      debugPrint('🔍 DEBUG: Trying email URI: $emailUri');

      try {
        if (await canLaunchUrl(emailUri)) {
          debugPrint('🔍 DEBUG: Can launch email, attempting...');
          final launched = await launchUrl(
            emailUri,
            mode: LaunchMode.platformDefault,
          );

          if (launched) {
            debugPrint('🔍 DEBUG: Email launch successful with URI: $emailUri');
            return; // Success, exit the method
          }
        } else {
          debugPrint('🔍 DEBUG: Cannot launch email with URI: $emailUri');
        }
      } catch (e) {
        debugPrint('🔍 DEBUG: Error launching email with URI $emailUri: $e');
        continue; // Try next URI format
      }
    }

    // If all attempts failed
    debugPrint('🔍 DEBUG: All email launch attempts failed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not launch email app. Please check your device settings.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _launchSMS(String phone) async {
    // Clean phone number - remove spaces, dashes, etc.
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    debugPrint('🔍 DEBUG: Launching SMS with clean number: $cleanPhone');

    // Try different URI formats for Android compatibility
    final List<Uri> smsUris = [
      Uri(scheme: 'sms', path: cleanPhone),
      Uri(scheme: 'smsto', path: cleanPhone), // Alternative SMS scheme
      Uri(scheme: 'sms', path: phone), // Original format
    ];

    for (final smsUri in smsUris) {
      debugPrint('🔍 DEBUG: Trying SMS URI: $smsUri');

      try {
        if (await canLaunchUrl(smsUri)) {
          debugPrint('🔍 DEBUG: Can launch SMS, attempting...');
          final launched = await launchUrl(
            smsUri,
            mode: LaunchMode.platformDefault,
          );

          if (launched) {
            debugPrint('🔍 DEBUG: SMS launch successful with URI: $smsUri');
            return; // Success, exit the method
          }
        } else {
          debugPrint('🔍 DEBUG: Cannot launch SMS with URI: $smsUri');
        }
      } catch (e) {
        debugPrint('🔍 DEBUG: Error launching SMS with URI $smsUri: $e');
        continue; // Try next URI format
      }
    }

    // If all attempts failed
    debugPrint('🔍 DEBUG: All SMS launch attempts failed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not launch SMS app. Please check your device settings.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleEditReview(Map<String, dynamic> review) {
    final reviewId = review['_id']?.toString() ?? '';
    final currentNote = (review['note'] ?? 0).toDouble();
    final currentComment = (review['commentaire'] ?? '').toString();

    showDialog(
      context: context,
      builder: (context) => _EditReviewDialog(
        reviewId: reviewId,
        initialRating: currentNote,
        initialComment: currentComment,
        onSave: (rating, comment) async {
          final result = await ReviewService.updateReview(
            avisId: reviewId,
            note: rating,
            commentaire: comment,
          );
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review updated successfully')),
            );
            // Reload reviews
            if (_userData != null) {
              await _loadOrganizerContent(_userData?['_id']?.toString() ?? '');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to update review'),
              ),
            );
          }
        },
      ),
    );
  }

  void _handleDeleteReview(Map<String, dynamic> review) {
    final reviewId = review['_id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Review'),
        content: Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ReviewService.deleteReview(reviewId);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review deleted successfully')),
                );
                // Reload reviews
                if (_userData != null) {
                  await _loadOrganizerContent(
                    _userData?['_id']?.toString() ?? '',
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete review')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(),
        body: _buildSkeletonLoader(),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: AppColors.textGrey),
              SizedBox(height: 16.h),
              Text('User not found', style: AppTextStyles.headlineSmall),
            ],
          ),
        ),
      );
    }

    final userType = _userData?['userType']?.toString() ?? '';
    final isOrganizer =
        userType == 'Organisator' || _userData?['isOrganisator'] == true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.surface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Cover Image & Profile Header
            SliverToBoxAdapter(child: _buildProfileHeader()),

            // Interests Section (for tourists only)
            if (!isOrganizer)
              SliverToBoxAdapter(child: _buildInterestsSection()),

            // Specialties and Languages (for organizers only)
            if (isOrganizer) ...[
              SliverToBoxAdapter(child: _buildSpecialtiesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24.h)),
              SliverToBoxAdapter(child: _buildLanguagesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            ],

            // Stats Bar
            SliverToBoxAdapter(child: _buildStatsBar(isOrganizer: isOrganizer)),

            // Contact Information (respect privacy)
            SliverToBoxAdapter(child: _buildContactInfo()),

            // Action Buttons
            SliverToBoxAdapter(child: _buildActionButtons()),

            // Role-Specific Content
            if (isOrganizer) ...[
              _buildOrganizerContent(),
              SliverToBoxAdapter(child: _buildReviewsSection()),
            ] else
              _buildTouristContent(),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 32.h)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          'Profile Details',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // Cover skeleton
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          SizedBox(height: 60.h),
          // Avatar skeleton
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.outline,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(height: 16.h),
          // Name skeleton
          Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          SizedBox(height: 8.h),
          // Bio skeleton
          Container(
            width: 250,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = _resolveUrl(_userData?['avatar']?.toString());
    final coverUrl = _resolveUrl(_userData?['cover_photo']?.toString());

    // Use _userData directly for name, bio, and location
    final fullname = (_userData?['fullname']?.toString() ?? '').trim();
    final displayName = fullname.isEmpty ? 'User' : fullname;
    final bio = (_userData?['bio']?.toString() ?? '').trim();
    final userType = _userData?['userType']?.toString() ?? '';
    final isOrganizer =
        userType == 'Organisator' || _userData?['isOrganisator'] == true;
    final subtitle = bio.isEmpty ? '' : bio;
    final location = (_userData?['pays_origine']?.toString() ?? '').trim();

    // Privacy settings - stored directly in user document, not nested
    final profileVisibility = _userData?['profileVisibility'] ?? true;
    final showOnlineStatus = _userData?['showOnlineStatus'] ?? true;
    final showLastSeen = _userData?['showLastSeen'] ?? false;
    final allowDirectMessages = _userData?['allowDirectMessages'] ?? true;
    final showPhone = _userData?['showPhone'] ?? false;
    final showEmail = _userData?['showEmail'] ?? false;
    final allowLocationSharing = _userData?['allowLocationSharing'] ?? false;

    // Check if this is the current user's own profile
    final targetUserId = widget.userId ?? _currentUserId;
    final isCurrentUser = targetUserId == _currentUserId;

    // If profile is not visible and not the current user, show restricted message
    if (!profileVisibility && !isCurrentUser) {
      return _buildRestrictedProfile();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Premium Background with Gradient & Image
        Container(
          height: 240,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4B63FF), Color(0xFF1B2458)],
            ),
          ),
          child: Stack(
            children: [
              // Abstract Mediterranean pattern overlay
              Opacity(
                opacity: 0.15,
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: double.infinity,
                        height: 240,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        'https://images.unsplash.com/photo-1544413647-ad342f022790?auto=format&fit=crop&w=1200&q=80',
                        width: double.infinity,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
              ),
              // Glassmorphism accent
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Main Profile Content (Avatar & Info)
        Column(
          children: [
            SizedBox(height: 140.h),
            // Avatar with Premium Border
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 124,
                  height: 124,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFE0E7FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.all(4.w),
                  child: GestureDetector(
                    onTap: () => _showAvatarFullScreen(avatarUrl),
                    child: Hero(
                      tag: 'profile_avatar_${widget.userId ?? _currentUserId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60.r),
                        child: avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFF94A3B8),
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: Color(0xFF94A3B8),
                              ),
                      ),
                    ),
                  ),
                ),
                // Online status indicator
                if (showOnlineStatus)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: (_userData?['isOnline'] == true)
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 16.h),

            // Name & Verification Badge
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isOrganizer) ...[
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.verified,
                          color: Color(0xFF4B63FF),
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  // Badge for User Type
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOrganizer
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      (isOrganizer ? 'Expert Organizer' : 'Djerba Explorer')
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: isOrganizer
                            ? const Color(0xFF4B63FF)
                            : const Color(0xFF16A34A),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Color(0xFF64748B),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 12.h),
                  // Location Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBar({required bool isOrganizer}) {
    // Privacy setting to show/hide relations
    final bool showRelations = _userData?['showRelations'] ?? true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (isOrganizer) ...[
            _buildStatItem('Activities', _activities.length.toString()),
            _buildDivider(),
            _buildStatItem('Posts', _posts.length.toString()),
            _buildDivider(),
            _buildStatItem('Rate', _reviews.isEmpty
                ? '0.0'
                : (_reviews.fold<double>(0, (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0)) / _reviews.length).toStringAsFixed(1)),
            _buildDivider(),
            _buildRelationsStatItem('Relations', '${_followersCount + _followingCount}', true, showRelations),
          ] else ...[
            _buildStatItem('Posts', _posts.length.toString()),
            _buildDivider(),
            _buildStatItem('Reservations', _participatedActivities.toString()),
            _buildDivider(),
            _buildRelationsStatItem('Relations', '${_followersCount + _followingCount}', true, showRelations),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 34, color: Colors.grey.withOpacity(0.2));
  }

  Widget _buildRelationsStatItem(String label, String value, bool isFollowers, bool showRelations) {
    return InkWell(
      onTap: () {
        if (!showRelations) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User has hidden their followers and following lists.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RelationsScreen(
              userId: widget.userId ?? _currentUserId!,
              initialTabIndex: isFollowers ? 0 : 1,
            ),
          ),
        );
      },
      child: _buildStatItem(label, value),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRestrictedProfile() {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: const Center(
        child: Text('This profile is private or unavailable.'),
      ),
    );
  }

  Widget _buildContactInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Privacy settings - stored directly in user document, not nested

    debugPrint('🔍 DEBUG: User data keys: ${_userData?.keys.toList()}');
    debugPrint('🔍 DEBUG: showPhone: ${_userData?['showPhone']}');
    debugPrint('🔍 DEBUG: showEmail: ${_userData?['showEmail']}');
    debugPrint('🔍 DEBUG: showLastSeen: ${_userData?['showLastSeen']}');
    debugPrint('🔍 DEBUG: allowPhoneCalls: ${_userData?['allowPhoneCalls']}');
    debugPrint('🔍 DEBUG: isReallyOnline: ${_userData?['isReallyOnline']}');
    debugPrint('🔍 DEBUG: lastActiveAt: ${_userData?['lastActiveAt']}');

    // Backend stores privacy settings directly in user document
    final showPhone = _userData?['showPhone'] ?? false;
    final showEmail = _userData?['showEmail'] ?? false;
    final showLastSeen = _userData?['showLastSeen'] ?? false;
    final allowLocationSharing = _userData?['allowLocationSharing'] ?? false;
    final allowPhoneCalls = _userData?['allowPhoneCalls'] ?? true;

    // New presence system data
    final isReallyOnline = _userData?['isReallyOnline'] ?? false;
    final lastActiveAtString = _userData?['lastActiveAt']?.toString();
    final lastActiveAt =
        lastActiveAtString != null && lastActiveAtString.isNotEmpty
        ? DateTime.tryParse(lastActiveAtString)
        : null;

    // Legacy derniere_connexion (kept for backward compatibility)
    final lastSeenString = _userData?['derniere_connexion']?.toString();
    final lastSeen = lastSeenString != null && lastSeenString.isNotEmpty
        ? DateTime.tryParse(lastSeenString)
        : null;

    debugPrint('🔍 DEBUG: Presence data:');
    debugPrint('  - isReallyOnline: $isReallyOnline');
    debugPrint('  - lastActiveAtString: $lastActiveAtString');
    debugPrint('  - lastActiveAt: $lastActiveAt');
    debugPrint('  - lastSeenString: $lastSeenString');
    debugPrint('  - lastSeen: $lastSeen');
    debugPrint('  - showLastSeen: $showLastSeen');

    final phone = _userData?['num_tel']?.toString() ?? '';
    final email = _userData?['email']?.toString() ?? '';

    final hasPhone =
        phone.isNotEmpty &&
        showPhone; // Show phone number when showPhone is true
    final hasEmail = email.isNotEmpty && showEmail;
    // Use new presence system: show online status or last active time
    // Temporarily bypass showLastSeen for testing - remove this line for production
    final hasPresenceInfo = (isReallyOnline || lastActiveAt != null);

    debugPrint('🔍 DEBUG Contact Info:');
    debugPrint('  - phone: "$phone"');
    debugPrint('  - email: "$email"');
    debugPrint('  - isReallyOnline: $isReallyOnline');
    debugPrint('  - lastActiveAt: $lastActiveAt');
    debugPrint('  - showPhone: $showPhone');
    debugPrint('  - showEmail: $showEmail');
    debugPrint('  - showLastSeen: $showLastSeen');
    debugPrint('  - allowPhoneCalls: $allowPhoneCalls');
    debugPrint('  - hasPhone: $hasPhone');
    debugPrint('  - hasEmail: $hasEmail');
    debugPrint('  - hasPresenceInfo: $hasPresenceInfo');

    if (!hasPhone && !hasEmail && !hasPresenceInfo)
      return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                color: Color(0xFF4B63FF),
                size: 20,
              ),
              SizedBox(width: 10.w),
              Text(
                'Contact Details',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Private',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (hasPhone) ...[
            _buildContactItem(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: phone,
              color: const Color(0xFF22C55E),
              onTap: () => _launchPhone(phone),
            ),
            SizedBox(height: 12.h),
          ],
          if (hasEmail) ...[
            _buildContactItem(
              icon: Icons.email_rounded,
              label: 'Email',
              value: email,
              color: const Color(0xFF4B63FF),
              onTap: () => _launchEmail(email),
            ),
            SizedBox(height: 12.h),
          ],
          if (hasPresenceInfo)
            _buildContactItem(
              icon: Icons.access_time_rounded,
              label: 'Last Active',
              value: isReallyOnline
                  ? 'Online Now'
                  : (lastActiveAt != null
                        ? _formatDate(lastActiveAt)
                        : 'Recently'),
              color: isReallyOnline
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF94A3B8),
              showBadge: isReallyOnline,
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateInput) {
    try {
      final DateTime date;
      if (dateInput is DateTime) {
        date = dateInput;
      } else {
        date = DateTime.parse(dateInput.toString());
      }
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
    bool showBadge = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (showBadge)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6622C55E),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          if (onTap != null)
            IconButton(
              onPressed: onTap,
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isOwnProfile = _userData?['_id']?.toString() == _currentUserId;
    final isOrganizer =
        _userData?['userType']?.toString() == 'Organisateur' ||
        _userData?['isOrganisator'] == true;

    // Privacy settings - stored directly in user document, not nested
    final allowDirectMessages = _userData?['allowDirectMessages'] ?? true;
    final allowPhoneCalls = _userData?['allowPhoneCalls'] ?? true;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          if (!isOwnProfile) ...[
            // Follow button
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isFollowLoading ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  icon: _isFollowLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          _isFollowing ? Icons.person_remove : Icons.person_add,
                          size: 22,
                        ),
                  label: Text(
                    _isFollowing ? 'Unfollow' : 'Follow',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Contact button (respect privacy)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  gradient: allowDirectMessages
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: allowDirectMessages
                          ? AppColors.primary.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: allowDirectMessages ? _handleContact : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: allowDirectMessages
                        ? Colors.white
                        : Colors.white70,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    shadowColor: Colors.transparent,
                  ),
                  icon: Icon(
                    allowDirectMessages
                        ? Icons.message_rounded
                        : Icons.message_outlined,
                    size: 22,
                  ),
                  label: Text(
                    isOrganizer ? 'Book Now' : 'Contact',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: allowDirectMessages
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3049D9),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                icon: Icon(
                  Icons.edit_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                label: Text(
                  'Edit Profile',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrganizerTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTabIndex = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 0
                      ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: _activeTabIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      color: _activeTabIndex == 0
                          ? AppColors.primary
                          : AppColors.textGrey,
                      size: 20,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Activities',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: _activeTabIndex == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeTabIndex == 0
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTabIndex = 1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 1
                      ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: _activeTabIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: _activeTabIndex == 1
                          ? AppColors.primary
                          : AppColors.textGrey,
                      size: 20,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Posts',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: _activeTabIndex == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeTabIndex == 1
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerContent() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _buildOrganizerTabs(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: _activeTabIndex == 0
                ? KeyedSubtree(
                    key: const ValueKey('organizer_activities'),
                    child: _buildActivitiesSection(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('organizer_posts'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPostsSection(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesSection() {
    final specialties = _extractSpecialties();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Specialized Activities', style: AppTextStyles.headlineSmall),
        SizedBox(height: 20.h),
        if (specialties.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'No specialties listed',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: specialties
                .map((specialty) => _SpecialtyChip(label: specialty))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildLanguagesSection() {
    final languages = _userData?['langues_proposees'] as List? ?? [];

    // Privacy settings
    final privacySettings =
        _userData?['privacy_settings'] as Map<String, dynamic>? ?? {};
    final profileVisibility = privacySettings['profile_visibility'] ?? true;

    // If profile is not visible, show restricted message
    if (!profileVisibility) {
      return _buildRestrictedProfile();
    }

    final languageList = languages
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Spoken Languages', style: AppTextStyles.headlineSmall),
        SizedBox(height: 12.h),
        if (languages.isEmpty || languages.first.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'No languages listed',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: languages
                .map((lang) => _LanguageChip(label: lang))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    final displayCount = _shownActivitiesCount.clamp(0, _activities.length);
    final hasMore = _activities.length > displayCount;

    // Calculate activity stats (type activite)
    final activityReviews = _reviews
        .where((r) => r['type'] == 'activite')
        .toList();
    double activityRating = 0.0;
    if (activityReviews.isNotEmpty) {
      final totalRating = activityReviews.fold<double>(0, (sum, review) {
        final note = review['note'] as num? ?? 0;
        return sum + note.toDouble();
      });
      activityRating = totalRating / activityReviews.length;
    }
    final activityReviewsCount = activityReviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activities', style: AppTextStyles.headlineSmall),
              SizedBox(width: 8.w),
              if (_activities.isNotEmpty)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Activity rate
                        if (activityReviewsCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                activityRating.toStringAsFixed(1),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                          ),
                        // Activity reviews count
                        Text(
                          '$activityReviewsCount reviews',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textGrey,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Total activities count
                        Text(
                          '${_activities.length} activities',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        if (_activities.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: AppColors.textGrey),
                  SizedBox(height: 12.h),
                  Text(
                    'No activities yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayCount,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return _ActivityCard(activity: activity);
                  },
                ),
              ),
              if (_activities.length > 6)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _toggleShowMoreActivities,
                      icon: Icon(
                        _shownActivitiesCount >= _activities.length
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                      label: Text(
                        _shownActivitiesCount >= _activities.length
                            ? 'Show less'
                            : 'Show more',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 32.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reviews', style: AppTextStyles.headlineSmall),
              if (_reviews.isNotEmpty)
                Text(
                  '${_reviews.length} reviews',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        if (_reviews.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No reviews yet',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _reviewsPageController,
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _ReviewCard(
                      review: review,
                      currentUserId: _currentUserId,
                      onEdit: () => _handleEditReview(review),
                      onDelete: () => _handleDeleteReview(review),
                      fallbackName: _userData?['fullname']?.toString(),
                      fallbackAvatar: _userData?['avatar']?.toString(),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTouristContent() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Posts Section
          _buildPostsSection(),
          // Reviews Section
          _buildReviewsSection(),
        ]),
      ),
    );
  }

  Widget _buildInterestsSection() {
    // Use _userData directly with centres_interet key
    final interestsRaw = _userData?['centres_interet'] as List? ?? [];

    final interests = interestsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    debugPrint('Interests: $interests');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 16.h),
          Text('Interests', style: AppTextStyles.headlineSmall),
          SizedBox(height: 12.h),
          if (interests.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.outline),
              ),
              child: Text(
                'No interests listed',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textGrey,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: interests
                  .map((interest) => _InterestChip(label: interest))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Posts', style: AppTextStyles.headlineSmall)],
        ),
        SizedBox(height: 12.h),
        if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: AppColors.textGrey,
                ),
                SizedBox(height: 12.h),
                Text(
                  'No posts yet',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final post = _posts[index];
              return PublicationCard(
                post: post,
                onLikeChanged: (liked, count) async {
                  final result = await PostService.togglePostLike(post.id);
                  if (result['success'] == true && mounted) {
                    setState(() {
                      if (liked) {
                        _likedPostIds.add(post.id);
                      } else {
                        _likedPostIds.remove(post.id);
                      }
                      // Refresh post list to update counts
                      _loadRoleSpecificContent(_user!);
                    });
                  }
                },
                onBookmarkChanged: (bookmarked, count) {
                  if (mounted) {
                    setState(() {
                      final index = _posts.indexWhere((p) => p.id == post.id);
                      if (index != -1) {
                        _posts[index] = _posts[index].copyWith(
                          isBookmarked: bookmarked,
                        );
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          bookmarked
                              ? 'Post saved to bookmarks'
                              : 'Post removed from bookmarks',
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                onToggleHide: () async {
                  final result = await PostService.togglePostHide(post.id);
                  if (result['success'] == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Action successful'),
                      ),
                    );
                    _loadRoleSpecificContent(_user!);
                  }
                },
                onShare: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => TikTokShareWidget(
                      postId: post.id,
                      postContent: post.content,
                      postImageUrl: (post.imageUrl?.isNotEmpty == true)
                          ? post.imageUrl
                          : null,
                    ),
                  );
                },
                onCommentsUpdated: () async {
                  await _loadRoleSpecificContent(_user!);
                },
              );
            },
          ),
        if (_isLoadingContent)
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  List<String> _extractSpecialties() {
    // Use the user's specialites_activites field from backend
    final specialtiesRaw = _userData?['specialites_activites'] as List? ?? [];

    final specialties = specialtiesRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    debugPrint('Specialties from user data: $specialties');

    // If no specialties in user data, fallback to extracting from activities
    if (specialties.isEmpty) {
      final activitySpecialties = <String>{};
      for (final activity in _activities) {
        if (activity.typeActivite.trim().isNotEmpty) {
          activitySpecialties.add(activity.typeActivite.trim());
        }
        for (final equipment in activity.equipementsInclus) {
          if (equipment.trim().isNotEmpty) {
            activitySpecialties.add(equipment.trim());
          }
        }
        if (activitySpecialties.length >= 8) break;
      }
      return activitySpecialties.take(8).toList();
    }

    return specialties.take(8).toList();
  }

  String _getCountryFlag(String country) {
    if (country.isEmpty) return '🌍';

    // Clean the country name - remove extra spaces and lowercase
    final cleanCountry = country.trim().toLowerCase();

    // Common country codes to flag emojis
    final countryFlags = {
      // Tunisia variations
      'tn': '🇹🇳',
      'tunisia': '🇹🇳',
      'tunisie': '🇹🇳',
      'tunisian': '🇹🇳',
      // France variations
      'fr': '🇫🇷',
      'france': '🇫🇷',
      // USA variations
      'us': '🇺🇸',
      'usa': '🇺🇸',
      'united states': '🇺🇸',
      'united states of america': '🇺🇸',
      'america': '🇺🇸',
      // UK variations
      'gb': '🇬🇧',
      'uk': '🇬🇧',
      'united kingdom': '🇬🇧',
      'united arab emirates': '🇦🇪',
      // Qatar
      'qa': '🇶🇦',
      'qatar': '🇶🇦',
      // Canada
      'ca': '🇨🇦',
      'canada': '🇨🇦',
      // Australia
      'au': '🇦🇺',
      'australia': '🇦🇺',
      'australie': '🇦🇺',
      // Japan
      'jp': '🇯🇵',
      'japan': '🇯🇵',
      'japon': '🇯🇵',
      // China
      'cn': '🇨🇳',
      'china': '🇨🇳',
      'chine': ' 🇳',
      // India
      'in': ' 🇮🇳',
      'india': '🇮🇳',
      'inde': '🇮🇳',
      // Brazil
      'br': '🇧🇷',
      'brazil': '🇧🇷',
      'bresil': '🇧🇷',
      // Mexico
      'mx': '🇲🇽',
      'mexico': '🇲🇽',
      'mexique': '🇲🇽',
      // Argentina
      'ar': '🇦🇷',
      'argentina': '🇦🇷',
      'argentine': '🇦🇷',
      // South Africa
      'za': '🇿🇦',
      'south africa': '🇿🇦',
      'afrique du sud': '🇿🇦',
      // Nigeria
      'ng': '🇳🇬',
      'nigeria': '🇳🇬',
      // Kenya
      'ke': '🇰🇪',
      'kenya': '🇰🇪',
      // Turkey
      'tr': '🇹🇷',
      'turkey': '🇹🇷',
      'turquie': '🇹🇷',
      // Greece
      'gr': '🇬🇷',
      'greece': '🇬🇷',
      'grece': '🇬🇷',
      // Netherlands
      'nl': '🇳🇱',
      'netherlands': '🇳🇱',
      'pays-bas': '🇳🇱',
      'pays bas': '🇳🇱',
      // Belgium
      'be': '🇧🇪',
      'belgium': '🇧🇪',
      'belgique': '🇧🇪',
      // Switzerland
      'ch': '🇨🇭',
      'switzerland': '🇨🇭',
      'suisse': '🇨 ',
      // Sweden
      'se': ' 🇸🇪',
      'sweden': '🇸🇪',
      'suede': '🇸🇪',
      // Norway
      'no': '🇳🇴',
      'norway': '🇳🇴',
      'norvege': '🇳🇴',
      // Denmark
      'dk': '🇩🇰',
      'denmark': '🇩🇰',
      'danemark': '🇩🇰',
      // Finland
      'fi': '🇫🇮',
      'finland': '🇫🇮',
      'finlande': '🇫🇮',
      // Poland
      'pl': '🇵🇱',
      'poland': '🇵🇱',
      'pologne': '🇵🇱',
      // Czech Republic
      'cz': '🇨🇿',
      'czech': '🇨🇿',
      'czech republic': '🇨🇿',
      'republique tcheque': '🇨🇿',
      // Austria
      'at': '🇦🇹',
      'austria': '🇦🇹',
      'autriche': '🇦🇹',
      // Hungary
      'hu': '🇭🇺',
      'hungary': '🇭🇺',
      'hongrie': '🇭🇺',
      // Portugal
      'pt': '🇵🇹',
      'portugal': '🇵🇹',
      // Russia
      'ru': '🇷🇺',
      'russia': '🇷🇺',
      'russie': '🇷🇺',
      // Ukraine
      'ua': '🇺🇦',
      'ukraine': '🇺🇦',
      // Romania
      'ro': '🇷🇴',
      'romania': '🇷🇴',
      'roumanie': '🇷🇴',
      // Bulgaria
      'bg': '🇧🇬',
      'bulgaria': '🇧🇬',
      'bulgarie': '🇧🇬',
      // Croatia
      'hr': '🇭🇷',
      'croatia': '🇭🇷',
      'croatie': '🇭🇷',
      // Slovenia
      'si': '🇸🇮',
      'slovenia': '🇸🇮',
      'slovenie': '🇸🇮',
      // Slovakia
      'sk': '🇸🇰',
      'slovakia': '🇸🇰',
      'slovaquie': '🇸🇰',
      // Estonia
      'ee': '🇪🇪',
      'estonia': '🇪🇪',
      'estonie': '🇪🇪',
      // Latvia
      'lv': '🇱🇻',
      'latvia': '🇱🇻',
      'letonie': '🇱🇻',
      // Lithuania
      'lt': '🇱🇹',
      'lithuania': '🇱🇹',
      'lituanie': '🇱🇹',
      // Iceland
      'is': '🇮🇸',
      'iceland': '🇮🇸',
      'islande': '🇮 ',
      // Ireland
      'ie': '🇮 🇪',
      'ireland': '🇮🇪',
      'irlande': '🇮 ',
      // Israel
      'il': '🇮 🇱',
      'israel': '🇮🇱',
      // Jordan
      'jo': '🇯🇴',
      'jordan': '🇯🇴',
      'jordanie': '🇯🇴',
      // Lebanon
      'lb': '🇱🇧',
      'lebanon': '🇱🇧',
      'liban': '🇱🇧',
      // Syria
      'sy': '🇸🇾',
      'syria': '🇸🇾',
      'syrie': '🇸🇾',
      // Iraq
      'iq': '🇮🇶',
      'iraq': '🇮🇶',
      'irak': '🇮🇶',
      // Kuwait
      'kw': '🇰🇼',
      'kuwait': '🇰🇼',
      'koweit': '🇰🇼',
      // Bahrain
      'bh': '🇧🇭',
      'bahrain': '🇧🇭',
      'bahrein': '🇧🇭',
      // Oman
      'om': '🇴🇲',
      'oman': '🇴🇲',
      // Pakistan
      'pk': '🇵🇰',
      'pakistan': '🇵🇰',
      // Bangladesh
      'bd': '🇧🇩',
      'bangladesh': '🇧🇩',
      // Sri Lanka
      'lk': '🇱🇰',
      'sri lanka': '🇱🇰',
      // Myanmar
      'mm': '🇲🇲',
      'myanmar': '🇲🇲',
      // Thailand
      'th': '🇹🇭',
      'thailand': '🇹🇭',
      'thailande': '🇹🇭',
      // Vietnam
      'vn': '🇻🇳',
      'vietnam': '🇻🇳',
      'viet nam': '🇻🇳',
      // Cambodia
      'kh': '🇰🇭',
      'cambodia': '🇰🇭',
      'cambodge': '🇰🇭',
      // Laos
      'la': '🇱🇦',
      'laos': '🇱🇦',
      // Malaysia
      'my': '🇲🇾',
      'malaysia': '🇲🇾',
      'malaisie': '🇲🇾',
      // Singapore
      'sg': '🇸🇬',
      'singapore': '🇸🇬',
      'singapour': '🇸🇬',
      // Indonesia
      'id': '🇮🇩',
      'indonesia': '🇮🇩',
      'indonesie': '🇮🇩',
      // Philippines
      'ph': '🇵🇭',
      'philippines': '🇵🇭',
      'philippins': '🇵🇭',
      // New Zealand
      'nz': '🇳🇿',
      'new zealand': '🇳🇿',
      'nouvelle-zelande': '🇳🇿',
      // South Korea
      'kr': '🇰🇷',
      'south korea': '🇰🇷',
      'coree du sud': '🇰🇷',
      // North Korea
      'kp': '🇰🇵',
      'north korea': '🇰🇵',
      'coree du nord': '🇰🇵',
    };

    final flag = countryFlags[cleanCountry];
    if (flag != null) return flag;

    // Try to find partial match (e.g., "Tunisian" contains "tunisia")
    for (final entry in countryFlags.entries) {
      if (cleanCountry.contains(entry.key) ||
          entry.key.contains(cleanCountry)) {
        return entry.value;
      }
    }

    debugPrint('No flag found for country: $country');
    return '🌍';
  }

  String _formatLastSeen(DateTime lastSeen) {
    debugPrint('🔍 DEBUG: Formatting last seen: $lastSeen');
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    debugPrint(
      '🔍 DEBUG: Time difference: ${difference.inDays}d, ${difference.inHours}h, ${difference.inMinutes}m',
    );

    if (difference.inDays > 30) {
      return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    } else if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute ago';
    } else {
      return 'Just now';
    }
  }

  String _formatLastActive(DateTime lastActiveAt) {
    debugPrint('🔍 DEBUG: Formatting last active: $lastActiveAt');

    // Convert to local time for proper timezone handling
    final localLastActive = lastActiveAt.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localLastActive);
    debugPrint(
      '🔍 DEBUG: Time difference: ${difference.inDays}d, ${difference.inHours}h, ${difference.inMinutes}m',
    );

    if (difference.inDays > 30) {
      return '${localLastActive.day}/${localLastActive.month}/${localLastActive.year}';
    } else if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _checkIfAdmin() async {
    try {
      final currentUser = await AuthService.getUser();
      _isAdmin =
          currentUser?['userType'] == 'Admin' ||
          currentUser?['isAdmin'] == true;
      debugPrint('🔐 User is admin: $_isAdmin');
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      _isAdmin = false;
    }
  }

  void _setupPrivacySettingsListener() {
    // Listen for privacy settings changes (could be enhanced with WebSocket/Stream)
    // For now, we'll use polling when the screen regains focus
  }

  void _startRealTimeLocationUpdates() {
    if (!_isAdmin) {
      debugPrint('📍 Real-time location updates disabled for non-admin users');
      return;
    }

    debugPrint('📍 Starting real-time location updates for admin');
    _locationUpdateTimer?.cancel();

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      await _updateRealTimeLocation();
    });
  }

  Future<void> _updateRealTimeLocation() async {
    if (!_isAdmin) return;

    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Location service disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Location permission denied');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final newLocation = await _getCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (newLocation != _currentLocation && mounted) {
        setState(() {
          _currentLocation = newLocation;
        });
        debugPrint('📍 Location updated: $newLocation');
      }
    } catch (e) {
      debugPrint('📍 Error updating location: $e');
    }
  }

  Future<String> _getCountryFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // For demo purposes, return Tunisia for admins
    // In production, you'd use a reverse geocoding service
    // like geocoding package or Google Maps Geocoding API

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, always return Tunisia for admin demo
      // In real implementation:
      // List<Placemark> placemarks = await Geocoding.placemarkFromCoordinates(latitude, longitude);
      // return placemarks.first.country ?? 'Unknown';

      return 'Tunisia';
    } catch (e) {
      debugPrint('Error getting country from coordinates: $e');
      return 'Tunisia'; // Fallback
    }
  }

  Future<String> _getRealTimeLocation() async {
    // For now, return the stored location
    // In a real implementation, you could use geolocation services
    // like geolocator package to get real-time GPS coordinates
    try {
      // Simulate real-time location fetching
      // In production, you'd use:
      // import 'package:geolocator/geolocator.dart';
      // Position position = await Geolocator.getCurrentPosition();
      // return await _getCountryFromCoordinates(position.latitude, position.longitude);

      // For now, return stored location with real-time fetching simulation
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate API call
      return _userData?['pays_origine']?.toString() ?? 'Unknown';
    } catch (e) {
      debugPrint('Error fetching real-time location: $e');
      return _userData?['pays_origine']?.toString() ?? 'Unknown';
    }
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool showStar;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.showStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 2.h),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showStar ? Icons.star_rounded : icon,
              size: 12,
              color: showStar
                  ? const Color(0xFFFFB31B)
                  : const Color(0xFF94A3B8),
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B63FF).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFF4B63FF),
          fontWeight: FontWeight.w700,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;

  const _LanguageChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB31B).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFFFFB31B),
          fontWeight: FontWeight.w700,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;

  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFF22C55E),
          fontWeight: FontWeight.w700,
          fontSize: 13.sp,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  int _currentImageIndex = 0;

  String _resolveImageUrl(String url) {
    final value = url.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    if (value.startsWith('/')) {
      return '$serverUrl$value';
    }
    return '$serverUrl/$value';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photos = widget.activity.photos;
    final hasMultiplePhotos = photos.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityDetailScreen(
                activityId: widget.activity.id,
                viewOnly: true,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel on top
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(16.r),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: photos.isEmpty
                    ? Container(
                        color: AppColors.outline,
                        child: Icon(Icons.image, color: AppColors.textGrey),
                      )
                    : Stack(
                        children: [
                          // Carousel
                          PageView.builder(
                            itemCount: photos.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final resolvedUrl = _resolveImageUrl(
                                photos[index],
                              );
                              return CachedNetworkImage(
                                imageUrl: resolvedUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.outline),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.outline,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Page indicators
                          if (hasMultiplePhotos)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  photos.length,
                                  (index) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Photo count badge
                          if (hasMultiplePhotos)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '${_currentImageIndex + 1}/${photos.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            // Content below
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.titre,
                    style: AppTextStyles.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          widget.activity.formattedLieu,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: AppColors.accent),
                      SizedBox(width: 4.w),
                      Text(
                        widget.activity.noteMoyenne.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '(${widget.activity.nombreAvis})',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.activity.prixFormatted,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
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
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final String? currentUserId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? fallbackName;
  final String? fallbackAvatar;

  const _ReviewCard({
    required this.review,
    this.currentUserId,
    this.onEdit,
    this.onDelete,
    this.fallbackName,
    this.fallbackAvatar,
  });

  String _getReviewerId() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      return (touriste['_id'] ?? '').toString();
    }
    return '';
  }

  bool _isReviewAuthor() {
    final reviewerId = _getReviewerId();
    return reviewerId == currentUserId;
  }

  String _getReviewerName() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final name = (touriste['fullname'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    if (fallbackName != null && fallbackName!.isNotEmpty) {
      return fallbackName!;
    }
    return 'Tourist';
  }

  String _getReviewerAvatar() {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final avatar = (touriste['avatar'] ?? '').toString();
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return avatar;
      }
      final serverUrl = ApiClient.baseUrl.replaceFirst(
        RegExp(r'/api(?:/v1)?$'),
        '',
      );
      if (avatar.startsWith('/')) {
        return '$serverUrl$avatar';
      }
      return '$serverUrl/$avatar';
    }
    if (fallbackAvatar != null && fallbackAvatar!.isNotEmpty) {
      if (fallbackAvatar!.startsWith('http://') ||
          fallbackAvatar!.startsWith('https://')) {
        return fallbackAvatar!;
      }
      final serverUrl = ApiClient.baseUrl.replaceFirst(
        RegExp(r'/api(?:/v1)?$'),
        '',
      );
      if (fallbackAvatar!.startsWith('/')) {
        return '$serverUrl$fallbackAvatar';
      }
      return '$serverUrl/$fallbackAvatar';
    }
    return '';
  }

  String _getReviewText() {
    final text = (review['commentaire'] ?? '').toString().trim();
    if (text.isEmpty) return 'No comment provided.';
    return text;
  }

  String _getReviewDate() {
    final raw = (review['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  double _getRating() {
    final rating = review['note'] ?? review['rating'] ?? 0;
    return rating.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewerName = _getReviewerName();
    final reviewerAvatar = _getReviewerAvatar();
    final reviewText = _getReviewText();
    final reviewDate = _getReviewDate();
    final rating = _getRating();
    final tags = review['tags'] as List? ?? [];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar, name, date, and rating
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                backgroundImage: reviewerAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(reviewerAvatar)
                    : null,
                child: reviewerAvatar.isEmpty
                    ? Icon(Icons.person, size: 20, color: AppColors.primary)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                    if (reviewDate.isNotEmpty)
                      Text(
                        reviewDate,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 11.sp,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.accent),
                    SizedBox(width: 3.w),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Review text
          Text(
            reviewText,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.4, fontSize: 13.sp),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Tags if available
          if (tags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(2).map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    tag.toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.sp,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditReviewDialog extends StatefulWidget {
  final String reviewId;
  final double initialRating;
  final String initialComment;
  final Function(double, String) onSave;

  const _EditReviewDialog({
    required this.reviewId,
    required this.initialRating,
    required this.initialComment,
    required this.onSave,
  });

  @override
  State<_EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends State<_EditReviewDialog> {
  late double _rating;
  late TextEditingController _commentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating.round() ? Icons.star : Icons.star_border,
                  color: AppColors.accent,
                ),
                onPressed: () {
                  setState(() {
                    _rating = (index + 1).toDouble();
                  });
                },
              );
            }),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your review...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  await widget.onSave(_rating, _commentController.text);
                  if (mounted) {
                    setState(() => _isSaving = false);
                    Navigator.pop(context);
                  }
                },
          child: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save'),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final VoidCallback onLikeToggle;
  final VoidCallback onCommentTap;

  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.onLikeToggle,
    required this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrls = post.imageUrls ?? [];
    final imageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or placeholder
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12.r),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.outline,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.outline,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, color: Colors.grey, size: 48),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content
                Text(
                  post.content,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),

                // Date
                Text(
                  _formatDate(post.createdAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textGrey,
                  ),
                ),
                SizedBox(height: 12.h),

                // Actions
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: onLikeToggle,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isLiked ? Colors.red : AppColors.textGrey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${post.likesCount}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),

                    // Comment button
                    GestureDetector(
                      onTap: onCommentTap,
                      child: Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 18,
                            color: AppColors.textGrey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${post.commentsCount}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textGrey,
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
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
