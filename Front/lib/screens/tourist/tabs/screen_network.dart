import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/auto_image_carousel.dart';

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
        post['liked_local'] = local.liked;
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
      _posts[index]['liked_local'] = liked;
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
                  (context, index) => _NetworkPostCard(
                    post: _visiblePosts[index],
                    currentUserId: _currentUserId,
                    onLikeChanged: _onLikeChanged,
                  ),
                  childCount: _visiblePosts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Post Model ───────────────────────────────────────────────────────────────

// ── Post Card ────────────────────────────────────────────────────────────────

class _NetworkPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentUserId;
  final void Function(String postId, bool liked, int likesCount) onLikeChanged;

  const _NetworkPostCard({
    required this.post,
    required this.currentUserId,
    required this.onLikeChanged,
  });

  @override
  State<_NetworkPostCard> createState() => _NetworkPostCardState();
}

class _NetworkPostCardState extends State<_NetworkPostCard> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLikeLoading = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.post['likes_count'] as num?)?.toInt() ?? 0;
    _commentsCount = (widget.post['comments_count'] as num?)?.toInt() ?? 0;
    _isLiked = _computeIsLiked();
  }

  @override
  void didUpdateWidget(covariant _NetworkPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPostId = (oldWidget.post['_id'] ?? '').toString();
    final newPostId = (widget.post['_id'] ?? '').toString();

    if (oldPostId != newPostId || oldWidget.post != widget.post) {
      _likesCount = (widget.post['likes_count'] as num?)?.toInt() ?? 0;
      _commentsCount = (widget.post['comments_count'] as num?)?.toInt() ?? 0;
      _isLiked = _computeIsLiked();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool _computeIsLiked() {
    final local = widget.post['liked_local'];
    if (local is bool) {
      return local;
    }

    final likedBy = widget.post['liked_by'];
    if (likedBy is! List || widget.currentUserId.isEmpty) {
      return false;
    }

    return likedBy.any((entry) {
      if (entry == null) return false;
      if (entry is String) return entry == widget.currentUserId;
      if (entry is Map<String, dynamic>) {
        return (entry['_id'] ?? entry['id'] ?? '').toString() ==
            widget.currentUserId;
      }
      return entry.toString() == widget.currentUserId;
    });
  }

  List<Map<String, dynamic>> _extractEmbeddedComments() {
    final raw = widget.post['comments'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    final items = raw
        .whereType<Map<String, dynamic>>()
        .where((c) {
          return c['is_active'] != false;
        })
        .map((c) {
          final author = c['author_id'];
          final authorMap = author is Map<String, dynamic>
              ? author
              : <String, dynamic>{'_id': author?.toString() ?? ''};

          return <String, dynamic>{
            '_id': (c['_id'] ?? '').toString(),
            'content': (c['content'] ?? '').toString(),
            'createdAt': c['createdAt']?.toString(),
            'updatedAt': c['updatedAt']?.toString(),
            'author_id': authorMap,
          };
        })
        .toList();

    items.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    return items;
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading) return;

    final postId = (widget.post['_id'] ?? '').toString();
    if (postId.isEmpty) return;

    final previousLiked = _isLiked;
    final previousCount = _likesCount;

    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likesCount = (_likesCount + (_isLiked ? 1 : -1)).clamp(0, 1 << 30);
    });
    widget.onLikeChanged(postId, _isLiked, _likesCount);

    final result = await PostService.togglePostLike(postId);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isLiked = result['liked'] == true;
        _likesCount = (result['likesCount'] as num?)?.toInt() ?? _likesCount;
        _isLikeLoading = false;
      });
      widget.post['likes_count'] = _likesCount;
      widget.post['liked_local'] = _isLiked;
      widget.onLikeChanged(postId, _isLiked, _likesCount);
      return;
    }

    final errorMessage = (result['message']?.toString() ?? '').toLowerCase();
    if (errorMessage.contains('route not found')) {
      setState(() {
        _isLikeLoading = false;
      });
      widget.post['liked_local'] = _isLiked;
      widget.onLikeChanged(postId, _isLiked, _likesCount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Like endpoint is missing on this server. Deploy backend updates.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLiked = previousLiked;
      _likesCount = previousCount;
      _isLikeLoading = false;
    });
    widget.post['liked_local'] = _isLiked;
    widget.onLikeChanged(postId, _isLiked, _likesCount);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Unable to update like'),
      ),
    );
  }

  Future<void> _openCommentsSheet() async {
    final postId = (widget.post['_id'] ?? '').toString();
    if (postId.isEmpty) return;

    final embeddedComments = _extractEmbeddedComments();
    var workingComments = List<Map<String, dynamic>>.from(embeddedComments);
    final apiComments = await PostService.getPostComments(postId);
    if (apiComments.isNotEmpty || workingComments.isEmpty) {
      workingComments = apiComments;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var isSending = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendComment() async {
              final text = _commentController.text.trim();
              if (text.isEmpty || isSending) return;

              setSheetState(() => isSending = true);
              final result = await PostService.addPostComment(
                postId: postId,
                content: text,
              );

              if (!context.mounted) return;

              if (result['success'] == true) {
                final serverComments = result['comments'];
                if (serverComments is List) {
                  workingComments = serverComments
                      .whereType<Map<String, dynamic>>()
                      .toList();
                } else {
                  final latest = await PostService.getPostComments(postId);
                  if (latest.isNotEmpty || workingComments.isEmpty) {
                    workingComments = latest;
                  }
                }

                _commentController.clear();
                setState(() {
                  _commentsCount = workingComments.length;
                  widget.post['comments_count'] = _commentsCount;
                });
                setSheetState(() => isSending = false);
                return;
              }

              setSheetState(() => isSending = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result['message']?.toString() ?? 'Unable to add comment',
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F235F),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${workingComments.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: workingComments.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 14, thickness: 0.6),
                        itemBuilder: (context, index) {
                          final comment = workingComments[index];
                          final author =
                              comment['author_id'] is Map<String, dynamic>
                              ? comment['author_id'] as Map<String, dynamic>
                              : <String, dynamic>{};
                          final authorName =
                              (author['fullname'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? (author['fullname'] as String)
                              : 'Traveler';
                          final content =
                              (comment['content'] as String?)?.trim() ?? '';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  (author['avatar'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? NetworkImage(author['avatar'] as String)
                                  : null,
                              child:
                                  ((author['avatar'] as String?) ?? '')
                                      .trim()
                                      .isEmpty
                                  ? const Icon(Icons.person, size: 17)
                                  : null,
                            ),
                            title: Text(
                              authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              content,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              filled: true,
                              fillColor: const Color(0xFFF3F4FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSending ? null : sendComment,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Recently';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final imageHeight = compact ? 320.0 : 380.0;

    final author = widget.post['author_id'] is Map<String, dynamic>
        ? widget.post['author_id'] as Map<String, dynamic>
        : <String, dynamic>{};
    final username = (author['fullname'] as String?) ?? 'Traveler';
    final avatar = (author['avatar'] as String?) ?? '';
    final imageUrls =
        (widget.post['image_urls'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final imageUrl = imageUrls.isNotEmpty
        ? imageUrls.first
        : (widget.post['image_url'] as String?) ?? '';
    final description = (widget.post['content'] as String?) ?? '';
    final locationLabel = (widget.post['location_label'] as String?) ?? '';
    final hashtags =
        (widget.post['hashtags'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final shares =
        (widget.post['shares_count'] as num?)?.toInt() ??
        (widget.post['share_count'] as num?)?.toInt() ??
        (widget.post['shares'] as num?)?.toInt() ??
        0;
    final created = DateTime.tryParse(
      widget.post['createdAt']?.toString() ?? '',
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time, Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: compact ? 16 : 18,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 14 : 15,
                          color: const Color(0xFF1F235F),
                        ),
                      ),
                      Text(
                        _timeAgo(created),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A81A8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF565D8B)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          if (description.isNotEmpty ||
              locationLabel.isNotEmpty ||
              hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (locationLabel.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2E3464),
                              ),
                              children: [
                                TextSpan(text: '$username is at '),
                                TextSpan(
                                  text: locationLabel,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (locationLabel.isNotEmpty) const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF232B57),
                      ),
                    ),
                  if (hashtags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: hashtags
                          .map(
                            (tag) => Text(
                              tag.startsWith('#') ? tag : '#$tag',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 6),
          // Image
          if (imageUrl.isNotEmpty)
            AutoImageCarousel(
              height: imageHeight,
              imageUrls: imageUrls,
              showIndicators: imageUrls.length > 1,
            ),
          // Interaction Bar: Likes, Comments, Shares
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isLiked
                            ? const Color(0xFF1F235F)
                            : const Color(0xFF4E567E),
                        size: 23,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_likesCount',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2F3566),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                GestureDetector(
                  onTap: _openCommentsSheet,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mode_comment_rounded,
                        size: 22,
                        color: Color(0xFF4E567E),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_commentsCount',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2F3566),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      size: 22,
                      color: Color(0xFF4E567E),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$shares',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF2F3566),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(
                  Icons.bookmark_rounded,
                  size: 23,
                  color: Color(0xFF4E567E),
                ),
              ],
            ),
          ),
          if (_commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: GestureDetector(
                onTap: _openCommentsSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VIEW ALL $_commentsCount COMMENTS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5E6290),
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

class _LocalLikeState {
  final bool liked;
  final int likesCount;

  const _LocalLikeState({required this.liked, required this.likesCount});
}

enum _FeedFilter { all, recent24h, withPhotos, withLocation, withHashtags }
