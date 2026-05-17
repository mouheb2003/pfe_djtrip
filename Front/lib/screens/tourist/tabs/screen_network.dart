import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../models/post_model.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../services/post_service.dart';
import '../../../widgets/facebook_mentions_inline_widget.dart';
import '../../../widgets/tiktok_share_widget.dart';
import '../../../utils/time_ago.dart';
import '../place_detail_screen_v2.dart';
import '../../tourist/my_activities_screen.dart';
import '../../shared/comments_screen.dart';
import '../../shared/public_profile_screen.dart';
import '../../shared/bookmarked_items_screen.dart';
import '../../../widgets/publication_card.dart';
import '../../../providers/user_provider.dart';
import 'create_post_screen.dart';

class ScreenNetwork extends StatefulWidget {
  final bool showBackButton;
  final String title;
  final bool showOnlyMyPosts;

  const ScreenNetwork({
    super.key,
    this.showBackButton = false,
    this.title = 'Network',
    this.showOnlyMyPosts = false,
  });

  @override
  State<ScreenNetwork> createState() => _ScreenNetworkState();
}

class _ScreenNetworkState extends State<ScreenNetwork>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFetching = false;
  String _currentUserId = '';
  late final ScrollController _scrollController;
  late final TabController _tabController;
  bool _isScrolled = false;
  final Map<String, _LocalLikeState> _localLikeStateByPost = {};
  final Map<String, _LocalBookmarkState> _localBookmarkStateByPost = {};
  _FeedFilter _activeFilter = _FeedFilter.allPosts;

  List<Map<String, dynamic>> get _visiblePosts {
    var result = List<Map<String, dynamic>>.from(_posts);

    switch (_activeFilter) {
      case _FeedFilter.allPosts:
        return result;
      case _FeedFilter.myPosts:
        return result.where((post) {
          final authorId = _extractAuthorId(post);
          return authorId == _currentUserId;
        }).toList();
      case _FeedFilter.trending:
        result.sort((a, b) {
          final aLikes = (a['likes_count'] as num?)?.toInt() ?? 0;
          final aComments = (a['comments_count'] as num?)?.toInt() ?? 0;
          final bLikes = (b['likes_count'] as num?)?.toInt() ?? 0;
          final bComments = (b['comments_count'] as num?)?.toInt() ?? 0;
          return (bLikes + bComments * 2).compareTo(aLikes + aComments * 2);
        });
        return result;
      case _FeedFilter.media:
        return result.where((post) => _hasPhotos(post)).toList();
      case _FeedFilter.organizers:
        return result.where((post) {
          final authorType = (post['author_id'] is Map) 
              ? (post['author_id']['userType']?.toString() ?? '').toLowerCase() 
              : '';
          return authorType == 'organisateur' || authorType == 'organizer';
        }).toList();
      case _FeedFilter.locations:
        return result.where((post) => (post['location_label']?.toString() ?? '').isNotEmpty).toList();
      case _FeedFilter.mostLiked:
        result.sort((a, b) {
          final aLikes = (a['likes_count'] as num?)?.toInt() ?? 0;
          final bLikes = (b['likes_count'] as num?)?.toInt() ?? 0;
          return bLikes.compareTo(aLikes);
        });
        return result;
      case _FeedFilter.likedByMe:
        return result.where((post) => post['is_liked'] == true).toList();
      case _FeedFilter.recent:
        result.sort((a, b) {
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return result;
    }
  }

  bool _hasPhotos(Map<String, dynamic> post) {
    final imageUrls =
        (post['image_urls'] as List?)
            ?.whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    return imageUrls.isNotEmpty;
  }

  String _extractFirstPhotoUrl(Map<String, dynamic> post) {
    final imageUrls =
        (post['image_urls'] as List?)
            ?.whereType<String>()
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];
    return imageUrls.isNotEmpty ? imageUrls.first : '';
  }

  IconData _getFilterIcon(_FeedFilter filter) {
    switch (filter) {
      case _FeedFilter.allPosts:
        return Icons.public_rounded;
      case _FeedFilter.myPosts:
        return Icons.person_rounded;
      case _FeedFilter.trending:
        return Icons.local_fire_department_rounded;
      case _FeedFilter.media:
        return Icons.image_rounded;
      case _FeedFilter.organizers:
        return Icons.business_center_rounded;
      case _FeedFilter.locations:
        return Icons.location_on_rounded;
      case _FeedFilter.mostLiked:
        return Icons.thumb_up_alt_rounded;
      case _FeedFilter.likedByMe:
        return Icons.favorite_rounded;
      case _FeedFilter.recent:
        return Icons.schedule_rounded;
    }
  }

  String _feedFilterLabel(_FeedFilter filter) {
    switch (filter) {
      case _FeedFilter.allPosts:
        return 'All Posts';
      case _FeedFilter.myPosts:
        return 'My Posts';
      case _FeedFilter.trending:
        return 'Trending';
      case _FeedFilter.media:
        return 'Photos';
      case _FeedFilter.organizers:
        return 'Organizers';
      case _FeedFilter.locations:
        return 'Places';
      case _FeedFilter.mostLiked:
        return 'Most Liked';
      case _FeedFilter.likedByMe:
        return 'Liked by Me';
      case _FeedFilter.recent:
        return 'Recent';
    }
  }

  String _extractAuthorId(Map<String, dynamic> post) {
    final author = post['author_id'];
    if (author is Map<String, dynamic>) {
      return (author['_id'] ?? author['id'] ?? '').toString();
    }
    return author?.toString() ?? '';
  }

  void _reportPost(Map<String, dynamic> post) {
    if (!mounted) return;
    final postId = (post['_id'] ?? '').toString();
    if (postId.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  void _muteAuthor(Map<String, dynamic> post) {
    if (!mounted) return;
    final authorId = _extractAuthorId(post);
    if (authorId.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Author muted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  void _showFilterBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Posts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1D245D),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Filter Items List
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: _FeedFilter.values.map((filter) {
                    final isSelected = _activeFilter == filter;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary.withOpacity(0.1) 
                              : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getFilterIcon(filter),
                          color: isSelected ? AppColors.primary : (isDark ? Colors.grey[400] : const Color(0xFF4B5563)),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _feedFilterLabel(filter),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937)),
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _activeFilter = filter;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _onLikeChanged(String postId, bool liked, int likesCount) async {
    if (!mounted) return;
    
    // Optimistic state update
    setState(() {
      final postIndex = _posts.indexWhere(
        (p) => (p['_id']?.toString() ?? '') == postId,
      );
      if (postIndex != -1) {
        _posts[postIndex]['is_liked'] = liked;
        _posts[postIndex]['likes_count'] = likesCount;
      }
    });

    try {
      final result = await PostService.togglePostLike(postId);
      if (result['success'] == true && mounted) {
        setState(() {
          final postIndex = _posts.indexWhere(
            (p) => (p['_id']?.toString() ?? '') == postId,
          );
          if (postIndex != -1) {
            _posts[postIndex]['is_liked'] = result['liked'] == true;
            _posts[postIndex]['likes_count'] = result['likesCount'] ?? likesCount;
          }
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  void _onBookmarkChanged(String postId, bool bookmarked, int bookmarksCount) {
    if (!mounted) return;

    setState(() {
      final postIndex = _posts.indexWhere(
        (p) => (p['_id']?.toString() ?? '') == postId,
      );
      if (postIndex != -1) {
        _posts[postIndex]['is_bookmarked'] = bookmarked;
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

  Future<void> _loadFeed({bool showLoader = true}) async {
    if (!mounted) return;
    if (_isFetching) return;

    if (showLoader) {
      setState(() => _loading = true);
    }
    _isFetching = true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.user is Map
          ? (userProvider.user as Map)['_id']?.toString() ?? ''
          : (userProvider.user as UserModel?)?.id ?? '';
      _currentUserId = userId;

      final posts = await PostService.getFeedPosts();

      if (!mounted) return;
      setState(() {
        _posts = posts
            .map(
              (post) => {
                ...post,
                'is_liked': post['is_liked'] ?? false,
                'is_bookmarked': post['is_bookmarked'] ?? false,
                'likes_count': post['likes_count'] ?? 0,
                'comments_count': post['comments_count'] ?? 0,
                'shares_count': post['shares_count'] ?? 0,
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _refreshFeed() async {
    await _loadFeed(showLoader: false);
  }

  void _handleScroll() {
    if (!mounted) return;
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 0;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FC),
      body: Stack(
        children: [
          RefreshIndicator(
        onRefresh: _refreshFeed,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Modern Header with Gradient
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: widget.showBackButton,
              iconTheme: const IconThemeData(color: AppColors.primary),
              centerTitle: false,
              toolbarHeight: 70,
              forceElevated: _isScrolled,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isScrolled ? 20 : 0,
                    sigmaY: _isScrolled ? 20 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF121212), const Color(0xFF121212)]
                            : _isScrolled
                                ? [Colors.white, Colors.white]
                                : [
                                    const Color(0xFFE8F4FD),
                                    const Color(0xFFF0F4FF),
                                  ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.transparent
                              : _isScrolled
                                  ? Colors.black.withOpacity(0.05)
                                  : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      boxShadow: _isScrolled && !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discover what\'s happening around you',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: _showFilterBottomSheet,
                    tooltip: 'Filter',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookmarkedItemsScreen(),
                        ),
                      );
                    },
                    tooltip: 'Saved Items',
                  ),
                ),
              ],
            ),

            // Horizontal Filter Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: () {
                      final mainFilters = [_FeedFilter.allPosts, _FeedFilter.myPosts];
                      if (!mainFilters.contains(_activeFilter)) {
                        mainFilters.add(_activeFilter);
                      }
                      return mainFilters;
                    }().map((filter) {
                      final isSelected = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                else if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF2E2E2E) : Colors.grey.withOpacity(0.1)),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getFilterIcon(filter),
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _feedFilterLabel(filter),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563)),
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Loading State
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (_visiblePosts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.feed_outlined,
                        size: 64,
                        color: Colors.black.withOpacity(0.15),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _activeFilter == _FeedFilter.allPosts
                            ? 'No posts yet'
                            : 'No results for this filter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share something amazing!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = _visiblePosts[index];
                  return PublicationCard(
                    post: PostModel.fromJson(post),
                    onLikeChanged: (liked, likesCount) {
                      final postId = (post['_id']?.toString() ?? '');
                      if (postId.isEmpty) return;
                      _onLikeChanged(postId, liked, likesCount);
                    },
                    onBookmarkChanged: (bookmarked, bookmarksCount) {
                      final postId = (post['_id']?.toString() ?? '');
                      if (postId.isEmpty) return;
                      _onBookmarkChanged(postId, bookmarked, bookmarksCount);
                    },
                    onReport: () => _reportPost(post),
                    onMute: () => _muteAuthor(post),
                    onModified: () {
                      _refreshFeed();
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(
                            'Delete Post',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D245D),
                            ),
                          ),
                          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4757),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final postId = (post['_id']?.toString() ?? '');
                        if (postId.isEmpty) return;
                        final result = await PostService.deletePost(postId);
                        if (result['success'] == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post deleted successfully'),
                              backgroundColor: Color(0xFF22C55E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _refreshFeed();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'Failed to delete post'),
                              backgroundColor: const Color(0xFFFF4757),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    onShare: () {
                      final postId = (post['_id']?.toString() ?? '');
                      if (postId.isEmpty) return;
                      final content = (post['content'] ?? '').toString();
                      final imageUrl =
                          (post['image_url'] ?? post['imageUrl'] ?? '')
                              .toString();
                      if (postId.isEmpty) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => TikTokShareWidget(
                          postId: postId,
                          postContent: content,
                          postImageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                        ),
                      );
                    },
                    onCopyLink: () async {
                      final postId = (post['_id']?.toString() ?? '');
                      if (postId.isEmpty) return;
                      final link = 'https://djtrip.com/post/$postId';
                      await Clipboard.setData(ClipboardData(text: link));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            backgroundColor: Color(0xFF22C55E),
                          ),
                        );
                      }
                    },
                    onToggleHide: () async {
                      final postId = (post['_id']?.toString() ?? '');
                      if (postId.isEmpty) return;
                      
                      final result = await PostService.togglePostHide(postId);
                      if (result['success'] == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Post hidden from profile'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        // Refresh to reflect changes if we are in "My Posts" filter
                        if (_activeFilter == _FeedFilter.myPosts) {
                          _refreshFeed();
                        }
                      }
                    },
                  );
                }, childCount: _visiblePosts.length),
              ),
          ],
        ),
      ),
          Positioned(
            top: 220,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final userModel = userProvider.user is Map
                    ? UserModel(
                        id: (userProvider.user as Map)['_id']?.toString() ?? '',
                        fullname: (userProvider.user as Map)['fullname']?.toString() ?? 'User',
                        email: (userProvider.user as Map)['email']?.toString() ?? '',
                        avatar: (userProvider.user as Map)['avatar']?.toString(),
                        userType: (userProvider.user as Map)['userType']?.toString() ?? 'Touriste',
                      )
                    : (userProvider.user as UserModel?);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatePostScreen(
                      user: userModel,
                    ),
                  ),
                );
                if (result == true) {
                  _refreshFeed();
                }
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Classes ─────────────────────────────────────────────────────────────

class _LocalLikeState {
  final bool liked;
  final int likesCount;

  const _LocalLikeState({required this.liked, required this.likesCount});
}

class _LocalBookmarkState {
  final bool bookmarked;
  final int bookmarksCount;

  const _LocalBookmarkState({
    required this.bookmarked,
    required this.bookmarksCount,
  });
}

enum _FeedFilter { 
  allPosts, 
  myPosts, 
  trending, 
  media, 
  organizers, 
  locations,
  mostLiked,
  likedByMe,
  recent
}
