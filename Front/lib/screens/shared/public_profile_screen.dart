import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/cache_manager.dart';
import '../../services/inscription_service.dart';
import '../../services/post_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auto_image_carousel.dart';
import 'activity_detail_screen.dart';
import 'chat_conversation_screen.dart';
import 'comments_screen.dart';

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

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // State
  bool _isLoading = true;
  bool _isLoadingContent = false;
  Map<String, dynamic>? _userData;
  UserModel? _user;
  List<ActivityModel> _activities = [];
  List<PostModel> _posts = [];
  int _participatedActivities = 0;
  int _submittedReviews = 0;
  final Set<String> _likedPostIds = {}; // Track locally liked posts
  
  // Pagination
  int _postsPage = 1;
  bool _hasMorePosts = true;
  final ScrollController _scrollController = ScrollController();
  
  // Current user info
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
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
    
    // Load all activities and filter by organizer (force refresh to get real data)
    final allActivities = await ActivityService.getActivities(refresh: true);
    debugPrint('Total activities: ${allActivities.length}');
    
    final targetId = (_userData?['_id'] ?? '').toString();
    debugPrint('Target ID for organizer filtering: $targetId');
    
    final organizerActivities = allActivities.where((a) {
      final orgId = (a.organisateur?['_id'] ?? a.organisateur?['id'] ?? '').toString();
      final match = orgId == targetId;
      return match;
    }).toList();

    debugPrint('Filtered organizer activities: ${organizerActivities.length}');
    
    setState(() {
      _activities = organizerActivities;
    });
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
            
            // Stats Bar
            SliverToBoxAdapter(child: _buildStatsBar()),
            
            // Action Buttons
            SliverToBoxAdapter(child: _buildActionButtons()),
            
            // Role-Specific Content
            if (isOrganizer)
              SliverToBoxAdapter(child: _buildActivitiesSection())
            else
              SliverToBoxAdapter(child: _buildTouristContent()),
            
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
      title: Text(
        'Profile',
        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
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
    final defaultBio = isOrganizer ? 'Activity organizer' : 'Passionate traveler';
    final subtitle = bio.isEmpty ? defaultBio : bio;
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
                  Container(
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
                      location,
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
    
    // Average rating from all activities
    final avgRating = _activities.isEmpty
        ? 0.0
        : _activities.fold<double>(0, (sum, a) => sum + a.noteMoyenne) / _activities.length;
    
    // Reviews received - count from activities' review counts
    final reviewsGot = _activities.fold<int>(
      0,
      (sum, activity) => sum + (activity.nombreAvis ?? 0),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          value: avgRating.toStringAsFixed(1),
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
          value: reviewsGot.toString(),
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
    
    debugPrint('Building tourist stats - posts: ${_posts.length}, submitted reviews: $reviewsCount, participated: $totalActivities');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          value: _posts.length.toString(),
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
          if (!isOwnProfile)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
                icon: const Icon(Icons.message_rounded, size: 22),
                label: Text(
                  isOrganizer ? 'Book Now' : 'Contact',
                  style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to edit profile screen
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 22),
                label: Text(
                  'Edit Profile',
                  style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
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
        const SizedBox(height: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Activities',
              style: AppTextStyles.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activities.isEmpty)
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
                Icon(Icons.event_busy, size: 48, color: AppColors.textGrey),
                const SizedBox(height: 12),
                Text(
                  'No activities yet',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activities.length > 6 ? 6 : _activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return _ActivityCard(activity: activity);
              },
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
    final specialties = <String>{};
    for (final activity in _activities) {
      if (activity.typeActivite.trim().isNotEmpty) {
        specialties.add(activity.typeActivite.trim());
      }
      for (final equipment in activity.equipementsInclus) {
        if (equipment.trim().isNotEmpty) {
          specialties.add(equipment.trim());
        }
      }
      if (specialties.length >= 8) break;
    }
    return specialties.take(8).toList();
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

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final imageUrl = activity.photos.isNotEmpty
        ? activity.photos.first
        : '';
    final resolvedUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '')}/$imageUrl';

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
                activityId: activity.id,
                viewOnly: true,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: resolvedUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.outline,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.outline,
                          child: Icon(Icons.image, color: AppColors.textGrey),
                        ),
                      )
                    : Container(
                        color: AppColors.outline,
                        child: Icon(Icons.image, color: AppColors.textGrey),
                      ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.titre,
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
                            activity.lieu,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          activity.noteMoyenne.toStringAsFixed(1),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${activity.nombreAvis})',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textGrey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          activity.prixFormatted,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                          ),
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
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final VoidCallback? onLikeToggle;

  const _PostCard({
    required this.post,
    this.isLiked = false,
    this.onLikeToggle,
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
                        debugPrint('Like post ${post.id} - isLiked: $isLiked');
                        // TODO: Call API to like/unlike post
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
                      onTap: () {
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
