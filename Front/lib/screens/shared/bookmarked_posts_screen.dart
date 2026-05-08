import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/post_service.dart';
import '../../widgets/publication_card.dart';
import '../../models/post_model.dart';

class BookmarkedPostsScreen extends StatefulWidget {
  const BookmarkedPostsScreen({super.key});

  @override
  State<BookmarkedPostsScreen> createState() => _BookmarkedPostsScreenState();
}

class _BookmarkedPostsScreenState extends State<BookmarkedPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  final Map<String, _LocalBookmarkState> _localBookmarkStateByPost = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarkedPosts();
  }

  Future<void> _loadBookmarkedPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await PostService.getBookmarkedPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshBookmarks() async {
    await _loadBookmarkedPosts();
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
      _posts[index]['isBookmarked'] = bookmarked;
      _posts[index]['bookmarks_count'] = bookmarksCount;
    });

    // If bookmark was removed, remove from list after a short delay
    if (!bookmarked) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _posts.removeAt(index);
          });
        }
      });
    }
  }

  void _onLikeChanged(String postId, bool liked, int likesCount) {
    final index = _posts.indexWhere(
      (p) => (p['_id'] ?? '').toString() == postId,
    );
    if (index == -1 || !mounted) return;

    setState(() {
      _posts[index]['isLiked'] = liked;
      _posts[index]['likes_count'] = likesCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: RefreshIndicator(
        onRefresh: _refreshBookmarks,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Modern Header with Gradient
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              automaticallyImplyLeading: true,
              iconTheme: const IconThemeData(color: AppColors.primary),
              centerTitle: false,
              toolbarHeight: 70,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE8F4FD),
                          const Color(0xFFF0F4FF),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
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
                    child: const Text(
                      'Saved Posts',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your bookmarked publications',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              actions: [
                // Bookmark count badge
                if (_posts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bookmark_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_posts.length}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Posts List
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_border_rounded,
                          size: 64,
                          color: Color(0xFF4B63FF),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No saved posts yet',
                        style: TextStyle(
                          color: Color(0xFF1B2458),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bookmark posts to save them for later',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Explore Posts'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final postData = _posts[index];
                      final postModel = PostModel.fromJson(postData);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PublicationCard(
                          post: postModel,
                          onLike: () async {
                            final postId = (postData['_id'] ?? '').toString();
                            if (postId.isEmpty) return;
                            final currentLiked = postData['isLiked'] ?? false;
                            final currentCount = (postData['likes_count'] as num?)?.toInt() ?? 0;
                            setState(() {
                              postData['isLiked'] = !currentLiked;
                              postData['likes_count'] = !currentLiked ? currentCount + 1 : currentCount - 1;
                            });
                            final result = await PostService.togglePostLike(postId);
                            if (result['success'] == true) {
                              final liked = result['liked'] == true;
                              final likesCount = (result['likesCount'] as num?)?.toInt() ?? currentCount;
                              _onLikeChanged(postId, liked, likesCount);
                            }
                          },
                          onBookmark: () async {
                            final postId = (postData['_id'] ?? '').toString();
                            if (postId.isEmpty) return;
                            final currentBookmarked = postData['isBookmarked'] ?? true;
                            final currentCount = (postData['bookmarks_count'] as num?)?.toInt() ?? 0;
                            setState(() {
                              postData['isBookmarked'] = !currentBookmarked;
                              postData['bookmarks_count'] = !currentBookmarked ? currentCount + 1 : currentCount - 1;
                            });
                            final result = await PostService.togglePostBookmark(postId);
                            if (result['success'] == true) {
                              final bookmarked = result['bookmarked'] == true;
                              final bookmarksCount = (result['bookmarksCount'] as num?)?.toInt() ?? currentCount;
                              _onBookmarkChanged(postId, bookmarked, bookmarksCount);
                            }
                          },
                          onShare: () {
                            // Share functionality
                          },
                          onReport: () {
                            // Report functionality
                          },
                          onMute: () {
                            // Mute functionality
                          },
                          onCopyLink: () async {
                            // Copy link functionality
                          },
                        ),
                      );
                    },
                    childCount: _posts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Classes ─────────────────────────────────────────────────────────────

class _LocalBookmarkState {
  final bool bookmarked;
  final int bookmarksCount;

  const _LocalBookmarkState({required this.bookmarked, required this.bookmarksCount});
}
