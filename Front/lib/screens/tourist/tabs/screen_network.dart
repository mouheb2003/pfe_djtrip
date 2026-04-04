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
    this.title = 'DISCOVER Network',
    this.showOnlyMyPosts = false,
  });

  @override
  State<ScreenNetwork> createState() => _ScreenNetworkState();
}

class _ScreenNetworkState extends State<ScreenNetwork> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final currentUserId = await AuthService.getUserId();
    final feedPosts = await PostService.getFeedPosts();
    final myPosts = await PostService.getMyPosts();

    final posts =
        (widget.showOnlyMyPosts
              ? (myPosts.isNotEmpty
                    ? myPosts
                    : feedPosts.where((post) {
                        final author = post['author_id'];
                        final authorId = author is Map<String, dynamic>
                            ? (author['_id'] ?? author['id'] ?? '').toString()
                            : author?.toString() ?? '';
                        return currentUserId != null &&
                            currentUserId.isNotEmpty &&
                            authorId == currentUserId;
                      }).toList())
              : feedPosts.where((post) {
                  final author = post['author_id'];
                  final authorId = author is Map<String, dynamic>
                      ? (author['_id'] ?? author['id'] ?? '').toString()
                      : author?.toString() ?? '';
                  if (currentUserId == null || currentUserId.isEmpty) {
                    return true;
                  }
                  return authorId != currentUserId;
                }).toList())
          ..sort((a, b) {
            final aDate =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  Future<void> _refreshFeed() async {
    await _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final titleSize = w >= 420 ? 36.0 : 30.0;

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
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'DISCOVER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Network',
                        style: TextStyle(
                          fontSize: titleSize,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1F235F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              expandedHeight: 120,
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
                  (context, index) => _NetworkPostCard(post: _posts[index]),
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
  const _NetworkPostCard({required this.post});

  @override
  State<_NetworkPostCard> createState() => _NetworkPostCardState();
}

class _NetworkPostCardState extends State<_NetworkPostCard> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
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
    final likes = (widget.post['likes_count'] as num?)?.toInt() ?? 0;
    final comments = (widget.post['comments_count'] as num?)?.toInt() ?? 0;
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
            color: Colors.black.withOpacity(0.06),
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
                  onTap: () => setState(() => _isLiked = !_isLiked),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likes',
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
                    const Icon(
                      Icons.chat_bubble,
                      size: 20,
                      color: Color(0xFF5B5E8A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$comments',
                      style: const TextStyle(
                        fontSize: 19,
                        color: Color(0xFF2F3566),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
          if (comments > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Text(
                'VIEW ALL $comments COMMENTS',
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F74A3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
