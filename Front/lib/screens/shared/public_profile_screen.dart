import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'chat_conversation_screen.dart';
import 'comments_screen.dart';
import 'edit_profile_screen.dart';

/// Modern Public Profile Screen
/// Supports both Tourist and Organizer profiles with premium UI/UX
class PublicProfileScreen extends StatefulWidget {
  final String? userId;

  const PublicProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> with WidgetsBindingObserver {
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
  final Set<String> _likedPostIds = {}; // Track locally liked posts

  // Pagination
  int _postsPage = 1;
  bool _hasMorePosts = true;
  final ScrollController _scrollController = ScrollController();

  // Activities display
  int _shownActivitiesCount = 6;

  // Reviews auto-scroll
  late PageController _reviewsPageController;
  Timer? _autoScrollTimer;

  // Current user info
  String? _currentUserId;
  
  // Follow status
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reviewsPageController = PageController(viewportFraction: 0.85);
    _initializeData();
    _scrollController.addListener(_onScroll);
    _startAutoScroll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload data when app is resumed
    if (state == AppLifecycleState.resumed) {
      _loadUserData(forceRefresh: true);
    }
  }

  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if userId changed or when screen is revisited
    if (widget.userId != oldWidget.userId) {
      _initializeData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _reviewsPageController.dispose();
    _autoScrollTimer?.cancel();
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
        _shownActivitiesCount = (_shownActivitiesCount + 6).clamp(6, _activities.length);
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
    await _loadUserData();
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

      // Fetch user data
      final userData = await UserService.getUserById(targetId, forceRefresh: forceRefresh);
      if (userData == null) {
        debugPrint('User data is null');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('User loaded: ${userData['_id']}');
      debugPrint('User type: ${userData['userType']}');
      debugPrint('User data keys: ${userData.keys}');

      final user = UserModel.fromJson(userData);
      
      setState(() {
        _userData = userData;
        _user = user;
      });

      // Load role-specific content
      await _loadRoleSpecificContent(user);
      
      // Check follow status if viewing another user's profile
      if (targetId != _currentUserId && _currentUserId != null) {
        await _checkFollowStatus(targetId);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFollowStatus(String targetId) async {
    try {
      final isFollowing = await FollowService.checkFollowStatus(targetId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      organizerActivities = await ActivityService.getActivitiesByOrganisateur(targetId, refresh: true);
      debugPrint('Organizer activities loaded from backend: ${organizerActivities.length}');
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
    
    // Restart auto-scroll with new reviews
    _startAutoScroll();
  }

  Future<void> _loadTouristContent(String userId) async {
    debugPrint('Loading tourist content for userId: $userId');
    
    // Load posts from feed and filter by user
    List<PostModel> userPosts = [];
    try {
      final feedPosts = await PostService.getFeedPosts();
      debugPrint('Feed posts total: ${feedPosts.length}');
      
      // Log first few posts to see structure
      if (feedPosts.isNotEmpty) {
        debugPrint('First post structure: ${feedPosts.first.keys}');
        debugPrint('First post user: ${feedPosts.first['user']}');
        debugPrint('First post author_id: ${feedPosts.first['author_id']}');
      }
      
      final targetId = (_userData?['_id'] ?? '').toString();
      debugPrint('Target ID for filtering: $targetId');
      
      userPosts = feedPosts.where((post) {
        // Match the old screen's filtering logic exactly
        // The API returns author_id as a Map object, need to extract _id
        String authorId = '';
        if (post['author_id'] is Map) {
          authorId = (post['author_id'] as Map)?['_id']?.toString() ?? '';
        } else {
          authorId = post['author_id']?.toString() ?? '';
        }
        if (authorId.isEmpty) {
          authorId = (post['user']?['_id']?.toString() ?? post['userId']?.toString() ?? post['author']?['_id']?.toString() ?? '').toString();
        }
        final match = authorId == targetId;
        if (feedPosts.indexOf(post) < 3) {
          debugPrint('Post ${feedPosts.indexOf(post)}: authorId=$authorId, targetId=$targetId, match=$match');
        }
        return match;
      }).map((post) => PostModel.fromJson(post)).toList();
      
      debugPrint('Filtered feed posts: ${userPosts.length}');
    } catch (e) {
      debugPrint('Error loading feed posts: $e');
    }

    // Load reviews submitted by tourist
    int submittedReviewsCount = 0;
    try {
      final reviewsData = await ReviewService.getTouristeReviews(userId);
      submittedReviewsCount = reviewsData['count'] ?? 0;
      debugPrint('Tourist submitted reviews: $submittedReviewsCount');
    } catch (e) {
      debugPrint('Error loading tourist reviews: $e');
    }

    // Load participated activities count (public endpoint)
    int participatedCount = 0;
    try {
      participatedCount = await InscriptionService.getTouristeParticipatedCount(userId);
      debugPrint('Tourist participated activities: $participatedCount');
    } catch (e) {
      debugPrint('Error loading tourist participated count: $e');
    }

    debugPrint('Tourist stats - posts: ${userPosts.length}, submitted reviews: $submittedReviewsCount, participated: $participatedCount');

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
              SnackBar(content: Text(result['message'] ?? 'Failed to update review')),
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
              final success = await ReviewService.deleteReview(reviewId);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review deleted successfully')),
                );
                // Reload reviews
                if (_userData != null) {
                  await _loadOrganizerContent(_userData?['_id']?.toString() ?? '');
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete review')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
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
              const SizedBox(height: 16),
              Text(
                'User not found',
                style: AppTextStyles.headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    final userType = _userData?['userType']?.toString() ?? '';
    final isOrganizer = userType == 'Organisator' || _userData?['isOrganisator'] == true;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Cover Image & Profile Header
            SliverToBoxAdapter(child: _buildProfileHeader()),
            
            // Interests Section (for tourists only)
            if (!isOrganizer) SliverToBoxAdapter(child: _buildInterestsSection()),
            
            // Specialties and Languages (for organizers only)
            if (isOrganizer) ...[
              SliverToBoxAdapter(child: _buildSpecialtiesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildLanguagesSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
            
            // Stats Bar
            SliverToBoxAdapter(child: _buildStatsBar()),
            
            // Action Buttons
            SliverToBoxAdapter(child: _buildActionButtons()),
            
            // Role-Specific Content
            if (isOrganizer) ...[
              SliverToBoxAdapter(child: _buildActivitiesSection()),
              SliverToBoxAdapter(child: _buildReviewsSection()),
            ] else
              _buildTouristContent(),
            
            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.share, color: AppColors.primary),
          onPressed: _handleShare,
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cover skeleton
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 60),
          // Avatar skeleton
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          // Name skeleton
          Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          // Bio skeleton
          Container(
            width: 250,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = _resolveUrl(_userData?['avatar']?.toString());
    final coverUrl = _resolveUrl(_userData?['coverImage']?.toString());
    
    // Use _userData directly for name, bio, and location
    final fullname = (_userData?['fullname']?.toString() ?? '').trim();
    final displayName = fullname.isEmpty ? 'User' : fullname;
    final bio = (_userData?['bio']?.toString() ?? '').trim();
    final userType = _userData?['userType']?.toString() ?? '';
    final isOrganizer = userType == 'Organisator' || _userData?['isOrganisator'] == true;
    final subtitle = bio.isEmpty ? '' : bio;
    final location = (_userData?['pays_origine']?.toString() ?? '').trim();

    return Column(
      children: [
        // Cover Image & Avatar Stack
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Cover Image
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
              ),
              child: coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primaryLight.withOpacity(0.2),
                      ),
                    )
                  : null,
            ),
            
            // Avatar with Online Status
            Positioned(
              bottom: -50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onLongPress: () => _showAvatarFullScreen(avatarUrl),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.outline,
                                  child: Icon(Icons.person, size: 40, color: AppColors.textGrey),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.outline,
                                  child: Icon(Icons.person, size: 40, color: AppColors.textGrey),
                                ),
                              )
                            : Container(
                                color: AppColors.outline,
                                child: Icon(Icons.person, size: 40, color: AppColors.textGrey),
                              ),
                      ),
                    ),
                  ),
                  // Online Status Indicator
                  Positioned(
                    right: 0,
                    bottom: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: (_userData?['isOnline'] == true) ? AppColors.online : AppColors.offline,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Profile Info (Name, Bio, Location)
        SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                displayName,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Role Badge
              if (isOrganizer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Organizer',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Traveler',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textGrey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              if (location.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      '${_getCountryFlag(location)} $location',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    if (_userData == null) return const SizedBox.shrink();

    final userType = _userData?['userType']?.toString() ?? '';
    final isOrganizer = userType == 'Organisator' || _userData?['isOrganisator'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isOrganizer
            ? _buildOrganizerStats()
            : _buildTouristStats(),
      ),
    );
  }

  Widget _buildOrganizerStats() {
    // Activities created
    final activitiesCreated = _activities.length;
    
    // Separate reviews by type
    final organizerReviews = _reviews.where((r) => r['type'] == 'organisateur').toList();
    final activityReviews = _reviews.where((r) => r['type'] == 'activite').toList();
    
    // Calculate organizer rating (only organizer-type reviews)
    double organizerRating = 0.0;
    if (organizerReviews.isNotEmpty) {
      final totalRating = organizerReviews.fold<double>(0, (sum, review) {
        final note = review['note'] as num? ?? 0;
        return sum + note.toDouble();
      });
      organizerRating = totalRating / organizerReviews.length;
    }
    
    // Calculate activity rating (only activity-type reviews)
    double activityRating = 0.0;
    if (activityReviews.isNotEmpty) {
      final totalRating = activityReviews.fold<double>(0, (sum, review) {
        final note = review['note'] as num? ?? 0;
        return sum + note.toDouble();
      });
      activityRating = totalRating / activityReviews.length;
    }
    
    // Total reviews count (organizer-type only)
    final organizerReviewsCount = organizerReviews.length;
    final activityReviewsCount = activityReviews.length;

    debugPrint('Organizer stats - Activities: $activitiesCreated, Organizer Reviews: $organizerReviewsCount, Activity Reviews: $activityReviewsCount, Organizer Rating: $organizerRating, Activity Rating: $activityRating');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          value: organizerRating.toStringAsFixed(1),
          label: 'Rate',
          icon: Icons.star,
          showStar: true,
        ),
        _buildDivider(),
        _StatItem(
          value: activitiesCreated.toString(),
          label: 'Created',
          icon: Icons.event,
        ),
        _buildDivider(),
        _StatItem(
          value: organizerReviewsCount.toString(),
          label: 'Reviews',
          icon: Icons.rate_review,
        ),
      ],
    );
  }

  Widget _buildTouristStats() {
    // Use submitted reviews count from API
    final reviewsCount = _submittedReviews;
    
    // Calculate total activities (participated) from all bookings
    // This is the sum of pending + confirmed + cancelled bookings
    final totalActivities = _participatedActivities;
    
    // Posts count
    final postsCount = _posts.length;
    
    debugPrint('Building tourist stats - posts: $postsCount, submitted reviews: $reviewsCount, participated: $totalActivities');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          value: postsCount.toString(),
          label: 'Posts',
          icon: Icons.article,
        ),
        _buildDivider(),
        _StatItem(
          value: reviewsCount.toString(),
          label: 'Reviews',
          icon: Icons.rate_review,
        ),
        _buildDivider(),
        _StatItem(
          value: totalActivities.toString(),
          label: 'Participated',
          icon: Icons.hiking,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.outline,
    );
  }

  Widget _buildActionButtons() {
    final isOwnProfile = _userData?['_id']?.toString() == _currentUserId;
    final isOrganizer = _userData?['userType']?.toString() == 'Organisateur' || _userData?['isOrganisator'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          if (!isOwnProfile) ...[
            // Follow button
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isFollowLoading
                      ? const SizedBox(
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
            const SizedBox(width: 12),
            // Contact button
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _handleContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: Colors.transparent,
                  ),
                  icon: const Icon(Icons.message_rounded, size: 22),
                  label: Text(
                    isOrganizer ? 'Book Now' : 'Contact',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ]
          else
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
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 22, color: Colors.white),
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

  Widget _buildOrganizerContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Activities Section (instead of posts)
          _buildActivitiesSection(),
        ]),
      ),
    );
  }

  Widget _buildSpecialtiesSection() {
    final specialties = _extractSpecialties();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Specialized Activities',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 20),
        if (specialties.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'No specialties listed',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
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
    
    debugPrint('Languages: $languages');

    if (languages.isEmpty) {
      return const SizedBox.shrink();
    }

    final languageList = languages.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Spoken Languages',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (languages.isEmpty || languages.first.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'No languages listed',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
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
    final activityReviews = _reviews.where((r) => r['type'] == 'activite').toList();
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activities',
                style: AppTextStyles.headlineSmall,
              ),
              if (_activities.isNotEmpty)
                Row(
                  children: [
                    // Activity rate
                    if (activityReviewsCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            activityRating.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    // Activity reviews count
                    Text(
                      '$activityReviewsCount reviews',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
                    ),
                    const SizedBox(width: 8),
                    // Total activities count
                    Text(
                      '${_activities.length} activities',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: AppColors.textGrey),
                  const SizedBox(height: 12),
                  Text(
                    'No activities yet',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return _ActivityCard(activity: activity);
                  },
                ),
              ),
              if (_activities.length > 6)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: AppTextStyles.headlineSmall,
              ),
              if (_reviews.isNotEmpty)
                Text(
                  '${_reviews.length} reviews',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: AppColors.textGrey),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _reviewsPageController,
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ReviewCard(
                      review: review,
                      currentUserId: _currentUserId,
                      onEdit: () => _handleEditReview(review),
                      onDelete: () => _handleDeleteReview(review),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Posts Section
          _buildPostsSection(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'Interests',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: 12),
        if (interests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              'No interests listed',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
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
          children: [
            Text(
              'Posts',
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Icon(Icons.article_outlined, size: 48, color: AppColors.textGrey),
                const SizedBox(height: 12),
                Text(
                  'No posts yet',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length > 6 ? 6 : _posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = _posts[index];
              return _PostCard(
                post: post,
                isLiked: _likedPostIds.contains(post.id),
                onLikeToggle: () {
                  setState(() {
                    if (_likedPostIds.contains(post.id)) {
                      _likedPostIds.remove(post.id);
                    } else {
                      _likedPostIds.add(post.id);
                    }
                  });
                },
                onCommentTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentsScreen(
                        postId: post.id,
                        postTitle: post.content,
                        initialCommentsCount: post.commentsCount,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        if (_isLoadingContent)
          const Padding(
            padding: EdgeInsets.all(20),
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
      'britain': '🇬🇧',
      'great britain': '🇬🇧',
      'england': '🇬🇧',
      // Germany
      'de': '🇩🇪',
      'germany': '🇩🇪',
      'allemagne': '🇩🇪',
      // Italy
      'it': '🇮🇹',
      'italy': '🇮🇹',
      'italie': '🇮🇹',
      // Spain
      'es': '🇪🇸',
      'spain': '🇪🇸',
      'espagne': '🇪🇸',
      // Morocco
      'ma': '🇲🇦',
      'morocco': '🇲🇦',
      'maroc': '🇲🇦',
      // Algeria
      'dz': '🇩🇿',
      'algeria': '🇩🇿',
      'algerie': '🇩🇿',
      // Egypt
      'eg': '🇪🇬',
      'egypt': '🇪🇬',
      'egypte': '🇪🇬',
      // Libya
      'ly': '🇱🇾',
      'libya': '🇱🇾',
      'libye': '🇱🇾',
      // Saudi Arabia
      'sa': '🇸🇦',
      'saudi arabia': '🇸🇦',
      'arabie saoudite': '🇸🇦',
      // UAE
      'ae': '🇦🇪',
      'uae': '🇦🇪',
      'emirates': '🇦🇪',
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
      'chine': '�🇳',
      // India
      'in': '�🇮🇳',
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
      'suisse': '🇨�',
      // Sweden
      'se': '�🇸🇪',
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
      'islande': '🇮�',
      // Ireland
      'ie': '🇮�🇪',
      'ireland': '🇮🇪',
      'irlande': '🇮�',
      // Israel
      'il': '🇮�🇱',
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
      if (cleanCountry.contains(entry.key) || entry.key.contains(cleanCountry)) {
        return entry.value;
      }
    }
    
    debugPrint('No flag found for country: $country');
    return '🌍';
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showStar)
              Icon(Icons.star, size: 16, color: AppColors.accent)
            else
              Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              value,
              style: AppTextStyles.headlineLarge.copyWith(
                fontSize: 24,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 0.5,
            color: AppColors.textGrey,
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
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
    if (url.startsWith('http')) return url;
    return '${ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '')}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.activity.photos;
    final hasMultiplePhotos = photos.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel on top
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
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
                              final resolvedUrl = _resolveImageUrl(photos[index]);
                              return CachedNetworkImage(
                                imageUrl: resolvedUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.outline,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.outline,
                                  child: Icon(Icons.image, color: AppColors.textGrey),
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
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_currentImageIndex + 1}/${photos.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.titre,
                    style: AppTextStyles.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        widget.activity.noteMoyenne.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
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

  const _ReviewCard({
    required this.review,
    this.currentUserId,
    this.onEdit,
    this.onDelete,
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
    final reviewerName = _getReviewerName();
    final reviewerAvatar = _getReviewerAvatar();
    final reviewText = _getReviewText();
    final reviewDate = _getReviewDate();
    final rating = _getRating();
    final tags = review['tags'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (reviewDate.isNotEmpty)
                      Text(
                        reviewDate,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textGrey,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Review text
          Text(
            reviewText,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.4,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Tags if available
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(2).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag.toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
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

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onCommentTap;

  const _PostCard({
    required this.post,
    this.isLiked = false,
    this.onLikeToggle,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrls = post.imageUrls;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Image Carousel
          if (imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AutoImageCarousel(
                imageUrls: imageUrls,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Reactions/Likes - separate from comments
                    InkWell(
                      onTap: () async {
                        onLikeToggle?.call();
                        final result = await PostService.togglePostLike(post.id);
                        debugPrint('Like post ${post.id} - result: $result');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked 
                                ? Icons.favorite 
                                : Icons.favorite_border,
                              size: 18,
                              color: isLiked 
                                ? Colors.red 
                                : AppColors.textGrey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (isLiked 
                                ? post.likesCount + 1 
                                : post.likesCount).toString(),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Comments - navigate to comments screen
                    InkWell(
                      onTap: onCommentTap ?? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommentsScreen(
                              postId: post.id,
                              postTitle: post.content,
                              initialCommentsCount: post.commentsCount,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_outlined, size: 18, color: AppColors.textGrey),
                            const SizedBox(width: 6),
                            Text(
                              post.commentsCount.toString(),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(post.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textGrey,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
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
      title: const Text('Edit Review'),
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
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your review...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}