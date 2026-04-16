import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/auto_image_carousel.dart';
import '../../../widgets/publication_card.dart';
import '../../../models/post_model.dart';
import '../../../screens/shared/share_post_to_conversation_screen.dart';

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

class _ScreenNetworkState extends State<ScreenNetwork> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isFetching = false;
  String _currentUserId = '';
  Timer? _autoRefreshTimer;
  late final ScrollController _scrollController;
  bool _isScrolled = false;
  final Map<String, _LocalLikeState> _localLikeStateByPost = {};
  _FeedFilter _activeFilter = _FeedFilter.all;

  List<Map<String, dynamic>> get _visiblePosts {
    switch (_activeFilter) {
      case _FeedFilter.all:
        return _posts;
      case _FeedFilter.recent24h:
        final threshold = DateTime.now().subtract(const Duration(hours: 24));
        return _posts.where((post) {
          final created = DateTime.tryParse(
            post['createdAt']?.toString() ?? '',
          );
          return created != null && created.isAfter(threshold);
        }).toList();
      case _FeedFilter.withPhotos:
        return _posts.where(_hasPhotos).toList();
      case _FeedFilter.withLocation:
        return _posts.where((post) {
          final location = (post['location_label'] as String?)?.trim() ?? '';
          return location.isNotEmpty;
        }).toList();
      case _FeedFilter.withHashtags:
        return _posts.where((post) {
          final hashtags =
              (post['hashtags'] as List?)?.whereType<String>().toList() ??
              const <String>[];
          return hashtags.any((tag) => tag.trim().isNotEmpty);
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
      case _FeedFilter.all:
        return 'All publications';
      case _FeedFilter.recent24h:
        return 'Last 24 hours';
      case _FeedFilter.withPhotos:
        return 'With photos';
      case _FeedFilter.withLocation:
        return 'With location';
      case _FeedFilter.withHashtags:
        return 'With hashtags';
    }
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<_FeedFilter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var localFilter = _activeFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter publications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F235F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Filters apply to real posts loaded from the database.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A81A8)),
                    ),
                    const SizedBox(height: 12),
                    ..._FeedFilter.values.map((filter) {
                      return RadioListTile<_FeedFilter>(
                        dense: true,
                        activeColor: AppColors.primary,
                        title: Text(_feedFilterLabel(filter)),
                        value: filter,
                        groupValue: localFilter,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => localFilter = value);
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, localFilter),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply filter',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
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

  String _feedFilterLabel(_FeedFilter filter) {
    switch (filter) {
      case _FeedFilter.all:
        return 'All publications';
      case _FeedFilter.recent24h:
        return 'Last 24 hours';
      case _FeedFilter.withPhotos:
        return 'With photos';
      case _FeedFilter.withLocation:
        return 'With location';
      case _FeedFilter.withHashtags:
        return 'With hashtags';
    }
  }

  String _extractAuthorId(Map<String, dynamic> post) {
    final author = post['author_id'];
    if (author is Map<String, dynamic>) {
      return (author['_id'] ?? author['id'] ?? '').toString();
    }
    return author?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _loadFeed();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadFeed(showLoader: false);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
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
      final currentUserId = _currentUserId.isNotEmpty
          ? _currentUserId
          : (await AuthService.getUserId() ?? '');
      final feedPosts = await PostService.getFeedPosts();
      final myPosts = await PostService.getMyPosts();

      final onlyOthers = feedPosts.where((post) {
        if (currentUserId.isEmpty) return true;
        return _extractAuthorId(post) != currentUserId;
      }).toList();

      final posts =
          (widget.showOnlyMyPosts
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

        final local = _localLikeStateByPost[postId];
        if (local == null) continue;

        post['likes_count'] = local.likesCount;
        post['isLiked'] = local.liked;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: widget.showBackButton,
              iconTheme: const IconThemeData(color: AppColors.primary),
              centerTitle: false,
              toolbarHeight: 62,
              forceElevated: _isScrolled,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isScrolled ? 18 : 10,
                    sigmaY: _isScrolled ? 18 : 10,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: _isScrolled
                          ? Colors.white.withValues(alpha: 0.68)
                          : Colors.white.withValues(alpha: 0.44),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: _isScrolled ? 18 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF1F235F),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openFilterSheet,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(
                              0xFFD62976,
                            ).withValues(alpha: 0.28),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFD62976,
                              ).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.filter_alt_outlined,
                              color: Color(0xFF1F235F),
                              size: 19,
                            ),
                            if (_activeFilter != _FeedFilter.all)
                              const Positioned(
                                top: 7,
                                right: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 7, height: 7),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(
                  _activeFilterLabel,
                  style: const TextStyle(
                    color: Color(0xFF6F76A0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // Posts Feed
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_visiblePosts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _activeFilter == _FeedFilter.all
                        ? 'No posts yet.'
                        : 'No posts match this filter.',
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final postData = _visiblePosts[index];
                    final postModel = PostModel.fromJson(postData);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PublicationCard(
                        post: postModel,
                        onLike: () async {
                          final postId = (postData['_id'] ?? '').toString();
                          if (postId.isEmpty) return;
                          // Optimistically update like state
                          final currentLiked = postData['isLiked'] ?? false;
                          final currentCount = (postData['likes_count'] as num?)?.toInt() ?? 0;
                          setState(() {
                            postData['isLiked'] = !currentLiked;
                            postData['likes_count'] = !currentLiked ? currentCount + 1 : currentCount - 1;
                            _localLikeStateByPost[postId] = _LocalLikeState(
                              liked: !currentLiked,
                              likesCount: !currentLiked ? currentCount + 1 : currentCount - 1,
                            );
                          });
                          final result = await PostService.togglePostLike(postId);
                          // Update state based on backend response
                          if (result['success'] == true) {
                            final liked = result['liked'] == true;
                            final likesCount = (result['likesCount'] as num?)?.toInt() ?? currentCount;
                            setState(() {
                              postData['isLiked'] = liked;
                              postData['likes_count'] = likesCount;
                              _localLikeStateByPost[postId] = _LocalLikeState(
                                liked: liked,
                                likesCount: likesCount,
                              );
                            });
                          }
                        },
                        onBookmark: () {
                          // TODO: Implement bookmark
                        },
                        onShare: () {
                          final postId = (postData['_id'] ?? '').toString();
                          final content = (postData['content'] ?? '').toString();
                          final imageUrl = (postData['image_url'] ?? postData['imageUrl'] ?? '').toString();
                          if (postId.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SharePostToConversationScreen(
                                postId: postId,
                                postContent: content,
                                postImageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: _visiblePosts.length,
                ),
              ),
          ],
        ),
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

enum _FeedFilter { all, recent24h, withPhotos, withLocation, withHashtags }
