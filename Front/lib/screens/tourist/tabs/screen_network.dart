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
  final Map<String, _LocalLikeState> _localLikeStateByPost = {};

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
    _loadFeed();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadFeed(showLoader: false);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFFF3F2FA),
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: widget.showBackButton,
              iconTheme: const IconThemeData(color: AppColors.primary),
              centerTitle: false,
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF1F235F),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // Posts Feed
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No posts yet.')),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _NetworkPostCard(
                    post: _posts[index],
                    currentUserId: _currentUserId,
                    onLikeChanged: _onLikeChanged,
                  ),
                  childCount: _posts.length,
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
      margin: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, compact ? 12 : 16, 14),
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
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
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_likesCount',
                        style: const TextStyle(
                          fontSize: 19,
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
                        Icons.chat_bubble,
                        size: 20,
                        color: Color(0xFF5B5E8A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_commentsCount',
                        style: const TextStyle(
                          fontSize: 19,
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
                    const Icon(Icons.share, size: 20, color: Color(0xFF5B5E8A)),
                    const SizedBox(width: 6),
                    Text(
                      '$shares',
                      style: const TextStyle(
                        fontSize: 19,
                        color: Color(0xFF2F3566),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.bookmark, size: 21, color: Color(0xFF5B5E8A)),
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
