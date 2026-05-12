import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../../models/activity_model.dart';
import '../../../models/user_model.dart';
import '../../../models/post_model.dart';
import '../../../services/activity_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/activity_card.dart';
import '../../../widgets/back_button.dart';
import '../../../widgets/facebook_mentions_inline_widget.dart';
import '../../../widgets/gradient_background.dart';
import '../../../widgets/no_activities_widget.dart';
import '../../../widgets/tiktok_share_widget.dart';
import '../../../widgets/tourist_map_widget.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/time_ago.dart';
import '../../tourist/place_detail_screen.dart';
import '../../tourist/create_post_screen.dart';
import '../../tourist/place_detail_new_screen.dart';
import '../../tourist/my_activities_screen.dart';
import '../../shared/comments_screen.dart';
import '../../shared/public_profile_screen.dart';
import '../../shared/bookmarked_items_screen.dart';
import '../create_post_screen.dart';

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
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (imageUrls.isNotEmpty) return true;
    final imageUrl = (post['image_url'] as String?)?.trim() ?? '';
    return imageUrl.isNotEmpty;
  }

  String get _activeFilterLabel {
    switch (_activeFilter) {
      case _FeedFilter.allPublications:
        return 'All Publications';
      case _FeedFilter.myPosts:
        return 'My Posts';
    }
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<_FeedFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        var localFilter = _activeFilter;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Filter posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Filter options
                    ..._FeedFilter.values.map((filter) {
                      final isSelected = localFilter == filter;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setDialogState(() => localFilter = filter);
                              HapticFeedback.selectionClick();
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFFF0F4FF) 
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFF4B63FF) 
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: RadioListTile<_FeedFilter>(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            activeColor: const Color(0xFF4B63FF),
                            title: Row(
                              children: [
                                Icon(
                                  _getFilterIcon(filter),
                                  size: 18,
                                  color: isSelected 
                                      ? const Color(0xFF4B63FF) 
                                      : const Color(0xFF9CA3AF),
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
                            value: filter,
                            groupValue: localFilter,
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => localFilter = value);
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Apply button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, localFilter),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Apply filter'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _activeFilter = selected);
    }
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

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final scrolled =
        _scrollController.hasClients && _scrollController.offset > 8;
    if (scrolled != _isScrolled && mounted) {
      setState(() => _isScrolled = scrolled);
    }
  }

  Future<void> _loadFeed({bool showLoader = true}) async {
    if (_isFetching) {
      return;
    }
    _isFetching = true;

    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await PostService.getFeedPosts();
      final posts = response['posts'] as List<dynamic>? ?? [];
      final currentUserId = response['currentUserId'] as String? ?? '';

                ? (myPosts.isNotEmpty
                      ? myPosts
                      : feedPosts.where((post) {
                          final authorId = _extractAuthorId(post);
                          return currentUserId.isNotEmpty &&
                              authorId == currentUserId;
                        }).toList())
                : onlyOthers)
            ..sort((a, b) {
              final aDate =
                  DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

      for (final post in posts) {
        final postId = (post['_id'] ?? '').toString();
        if (postId.isEmpty) continue;

        final localLike = _localLikeStateByPost[postId];
        if (localLike != null) {
          post['likes_count'] = localLike.likesCount;
          post['isLiked'] = localLike.liked;
        }

        final localBookmark = _localBookmarkStateByPost[postId];
        if (localBookmark != null) {
          post['bookmarks_count'] = localBookmark.bookmarksCount;
          post['isBookmarked'] = localBookmark.bookmarked;
        }
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = currentUserId;
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _refreshFeed() async {
    await _loadFeed();
  }

  Future<void> _refreshFromBookmarkedScreen() async {
    // Clear local bookmark states to sync with bookmarked screen changes
    _localBookmarkStateByPost.clear();
    await _loadFeed();
  }

  // Menu bottom sheet method
  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Menu title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.more_vert_rounded, color: Color(0xFF6B7280), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2458),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Menu options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Filter option
                  _MenuOption(
                    icon: Icons.tune_rounded,
                    title: 'Filter Posts',
                    subtitle: 'Filter by date, photos, location, etc.',
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openFilterSheet();
                    },
                    isActive: _activeFilter != _FeedFilter.allPublications,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Bookmarked items option
                  _MenuOption(
                    icon: Icons.bookmark_rounded,
                    title: 'Saved Items',
                    subtitle: 'View your bookmarked posts, activities & places',
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookmarkedItemsScreen(),
                        ),
                      ).then((_) {
                        // Refresh feed when returning from bookmarked screen to sync states
                        if (mounted) {
                          _refreshFromBookmarkedScreen();
                        }
                      });
                    },
                    isActive: false,
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _onLikeChanged(String postId, bool liked, int likesCount) {
    _localLikeStateByPost[postId] = _LocalLikeState(
      liked: liked,
      likesCount: likesCount,
    );

    final index = _posts.indexWhere(
      (p) => (p['_id'] ?? '').toString() == postId,
    );
    if (index == -1 || !mounted) return;

    setState(() {
      _posts[index]['likes_count'] = likesCount;
      _posts[index]['isLiked'] = liked;
    });
  }

  void _onBookmarkChanged(String postId, bool bookmarked, int bookmarksCount) {
    _localBookmarkStateByPost[postId] = _LocalBookmarkState(
      bookmarked: bookmarked,
      bookmarksCount: bookmarksCount,
    );

    final index = _posts.indexWhere(
      (p) => (p['_id'] ?? '').toString() == postId,
    );
    if (index == -1 || !mounted) return;

    setState(() {
      _posts[index]['bookmarks_count'] = bookmarksCount;
      _posts[index]['isBookmarked'] = bookmarked;
    });
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
                // Menu Button
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showMenuBottomSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.more_vert_rounded,
                              color: Color(0xFF6B7280),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Menu',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Tab Bar for All Publications and My Posts
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.grey[600],
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: const [
                    Tab(
                      text: 'All Publications',
                      icon: Icon(Icons.public, size: 18),
                    ),
                    Tab(
                      text: 'My Posts',
                      icon: Icon(Icons.person, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Posts Feed
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
                            ? 'No posts yet'
                            : 'No posts match this filter',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_activeFilter != _FeedFilter.allPublications) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _activeFilter = _FeedFilter.allPublications),
                          child: const Text(
                            'Clear filter',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              TabBarView(
                controller: _tabController,
                children: [
                  // All Publications Tab
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = _visiblePosts[index];
                        return PublicationCard(
                          post: post,
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
                            final postId = (post['_id'] ?? '').toString();
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
                                content: Text('Author muted'),
                                backgroundColor: Color(0xFF4B63FF),
                              ),
                            );
                          },
                          onCopyLink: () async {
                            final postId = (post['_id'] ?? '').toString();
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
                    ),
                    childCount: _visiblePosts.length,
                  ),
                ),
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
              builder: (context) => const CreatePostScreen(),
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

// Menu option widget
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isActive;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? AppColors.primary : Colors.black.withValues(alpha: 0.08),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isActive ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.primary : const Color(0xFF1B2458),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isActive ? AppColors.primary : const Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
