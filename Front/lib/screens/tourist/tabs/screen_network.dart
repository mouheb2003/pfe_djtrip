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
import '../../tourist/place_detail_screen.dart';
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

class _ScreenNetworkState extends State<ScreenNetwork> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFetching = false;
  String _currentUserId = '';
  Timer? _autoRefreshTimer;
  late final ScrollController _scrollController;
  late final TabController _tabController;
  bool _isScrolled = false;
  final Map<String, _LocalLikeState> _localLikeStateByPost = {};
  final Map<String, _LocalBookmarkState> _localBookmarkStateByPost = {};
  _FeedFilter _activeFilter = _FeedFilter.allPublications;

  List<Map<String, dynamic>> get _visiblePosts {
    var result = _posts;
    
    switch (_activeFilter) {
      case _FeedFilter.allPublications:
        return result;
      case _FeedFilter.myPosts:
        return result.where((post) {
          final authorId = post['author_id']?.toString() ?? '';
          return authorId == _currentUserId;
        }).toList();
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
      case _FeedFilter.allPublications:
        return Icons.public_rounded;
      case _FeedFilter.myPosts:
        return Icons.person_rounded;
    }
  }

  String _feedFilterLabel(_FeedFilter filter) {
    switch (filter) {
      case _FeedFilter.allPublications:
        return 'All Publications';
      case _FeedFilter.myPosts:
        return 'My Posts';
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

  void _onLikeChanged(String postId, bool liked, int likesCount) {
    if (!mounted) return;
    setState(() {
      final postIndex = _posts.indexWhere((p) => (p['_id']?.toString() ?? '') == postId);
      if (postIndex != -1) {
        _posts[postIndex]['is_liked'] = liked;
        _posts[postIndex]['likes_count'] = likesCount;
      }
    });
  }

  void _onBookmarkChanged(String postId, bool bookmarked, int bookmarksCount) {
    if (!mounted) return;
    setState(() {
      final postIndex = _posts.indexWhere((p) => (p['_id']?.toString() ?? '') == postId);
      if (postIndex != -1) {
        _posts[postIndex]['is_bookmarked'] = bookmarked;
      }
    });
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
      final userId = userProvider.user is Map ? (userProvider.user as Map)['_id']?.toString() ?? '' : (userProvider.user as UserModel?)?.id ?? '';
      _currentUserId = userId;

      final posts = await PostService.getFeedPosts();
      
      if (!mounted) return;
      setState(() {
        _posts = posts.map((post) => {
          ...post,
          'is_liked': post['is_liked'] ?? false,
          'is_bookmarked': post['is_bookmarked'] ?? false,
          'likes_count': post['likes_count'] ?? 0,
          'comments_count': post['comments_count'] ?? 0,
          'shares_count': post['shares_count'] ?? 0,
        }).toList();
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
    final isScrolled = _scrollController.hasClients && _scrollController.offset > 0;
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadFeed(showLoader: false);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: RefreshIndicator(
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
                        colors: _isScrolled
                            ? [
                                Colors.white,
                                Colors.white,
                              ]
                            : [
                                const Color(0xFFE8F4FD),
                                const Color(0xFFF0F4FF),
                              ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: _isScrolled
                              ? Colors.black.withValues(alpha: 0.05)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      boxShadow: _isScrolled
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
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
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PopupMenuButton<_FeedFilter>(
                    icon: Icon(
                      _getFilterIcon(_activeFilter),
                      color: AppColors.primary,
                    ),
                    color: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (context) {
                      return _FeedFilter.values.map((filter) {
                        final isSelected = _activeFilter == filter;
                        return PopupMenuItem<_FeedFilter>(
                          value: filter,
                          child: Row(
                            children: [
                              Icon(
                                _getFilterIcon(filter),
                                color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _feedFilterLabel(filter),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected 
                                      ? const Color(0xFF1B2458) 
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    onSelected: (filter) {
                      setState(() => _activeFilter = filter);
                    },
                  ),
                ),
              ],
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
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _activeFilter == _FeedFilter.allPublications
                            ? 'No publications yet'
                            : 'No posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share something amazing!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                      onShare: () {
                        final postId = (post['_id']?.toString() ?? '');
                        if (postId.isEmpty) return;
                        final content = (post['content'] ?? '').toString();
                        final imageUrl = (post['image_url'] ?? post['imageUrl'] ?? '').toString();
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
                    );
                  },
                  childCount: _visiblePosts.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostScreen(user: _currentUserId.isNotEmpty ? UserModel(id: _currentUserId, fullname: 'User', email: '', userType: 'Touriste') : null),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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

  const _LocalBookmarkState({required this.bookmarked, required this.bookmarksCount});
}

enum _FeedFilter { allPublications, myPosts }
