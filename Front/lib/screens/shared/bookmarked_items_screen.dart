import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/post_service.dart';
import '../../services/activity_service.dart';
import '../../services/lieu_service.dart';
import '../../widgets/publication_card.dart';
import '../../models/post_model.dart';
import '../../models/activity_model.dart';
import '../../models/lieu_model.dart';
import '../tourist/place_detail_screen_v2.dart';

enum BookmarkType { all, posts, activities, places }

class BookmarkedItemsScreen extends StatefulWidget {
  const BookmarkedItemsScreen({super.key});

  @override
  State<BookmarkedItemsScreen> createState() => _BookmarkedItemsScreenState();
}

class _BookmarkedItemsScreenState extends State<BookmarkedItemsScreen> {
  BookmarkType _selectedType = BookmarkType.all;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _places = [];
  bool _loading = true;
  final Map<String, _LocalBookmarkState> _localBookmarkStateByPost = {};
  final Map<String, _LocalBookmarkState> _localBookmarkStateByActivity = {};
  final Map<String, _LocalBookmarkState> _localBookmarkStateByPlace = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarkedItems();
  }

  Future<void> _loadBookmarkedItems() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        PostService.getBookmarkedPosts(),
        ActivityService.getBookmarkedActivities(),
        LieuService.getBookmarkedLieux(),
      ]);
      if (mounted) {
        setState(() {
          _posts = results[0];
          _activities = results[1];
          _places = results[2];
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
    await _loadBookmarkedItems();
  }

  int get _totalItems => _posts.length + _activities.length + _places.length;

  List<Map<String, dynamic>> get _filteredItems {
    switch (_selectedType) {
      case BookmarkType.posts:
        return _posts;
      case BookmarkType.activities:
        return _activities;
      case BookmarkType.places:
        return _places;
      case BookmarkType.all:
        return [..._posts, ..._activities, ..._places];
    }
  }

  void _onPostBookmarkChanged(
    String postId,
    bool bookmarked,
    int bookmarksCount,
  ) {
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

  void _onActivityBookmarkChanged(
    String activityId,
    bool bookmarked,
    int bookmarksCount,
  ) {
    _localBookmarkStateByActivity[activityId] = _LocalBookmarkState(
      bookmarked: bookmarked,
      bookmarksCount: bookmarksCount,
    );

    final index = _activities.indexWhere(
      (a) => (a['_id'] ?? '').toString() == activityId,
    );
    if (index == -1 || !mounted) return;

    setState(() {
      _activities[index]['isBookmarked'] = bookmarked;
      _activities[index]['bookmarks_count'] = bookmarksCount;
    });

    if (!bookmarked) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _activities.removeAt(index);
          });
        }
      });
    }
  }

  void _onPlaceBookmarkChanged(
    String lieuId,
    bool bookmarked,
    int bookmarksCount,
  ) {
    _localBookmarkStateByPlace[lieuId] = _LocalBookmarkState(
      bookmarked: bookmarked,
      bookmarksCount: bookmarksCount,
    );

    final index = _places.indexWhere(
      (p) => (p['_id'] ?? '').toString() == lieuId,
    );
    if (index == -1 || !mounted) return;

    setState(() {
      _places[index]['isBookmarked'] = bookmarked;
      _places[index]['bookmarks_count'] = bookmarksCount;
    });

    if (!bookmarked) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _places.removeAt(index);
          });
        }
      });
    }
  }

  void _onPostLikeChanged(String postId, bool liked, int likesCount) {
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
                      'Saved Items',
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
                    'Your bookmarked posts, activities & places',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              actions: [
                if (_totalItems > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                            '$_totalItems',
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
            // Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        count: _totalItems,
                        isSelected: _selectedType == BookmarkType.all,
                        onTap: () =>
                            setState(() => _selectedType = BookmarkType.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Posts',
                        count: _posts.length,
                        isSelected: _selectedType == BookmarkType.posts,
                        onTap: () =>
                            setState(() => _selectedType = BookmarkType.posts),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Activities',
                        count: _activities.length,
                        isSelected: _selectedType == BookmarkType.activities,
                        onTap: () => setState(
                          () => _selectedType = BookmarkType.activities,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Places',
                        count: _places.length,
                        isSelected: _selectedType == BookmarkType.places,
                        onTap: () =>
                            setState(() => _selectedType = BookmarkType.places),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Items List
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (_filteredItems.isEmpty)
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
                        'No saved items yet',
                        style: TextStyle(
                          color: Color(0xFF1B2458),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedType == BookmarkType.all
                            ? 'Bookmark posts, activities, or places to save them'
                            : 'Bookmark ${_selectedType.name} to save them',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _filteredItems[index];
                    final itemType = _getItemType(item);

                    if (itemType == 'post') {
                      final postModel = PostModel.fromJson(item);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PublicationCard(
                          post: postModel,
                          onLikeChanged: (liked, likesCount) async {
                            final postId = (item['_id'] ?? '').toString();
                            if (postId.isEmpty) return;
                            final currentLiked = item['isLiked'] ?? false;
                            final currentCount =
                                (item['likes_count'] as num?)?.toInt() ?? 0;
                            setState(() {
                              item['isLiked'] = !currentLiked;
                              item['likes_count'] = !currentLiked
                                  ? currentCount + 1
                                  : currentCount - 1;
                            });
                            final result = await PostService.togglePostLike(
                              postId,
                            );
                            if (result['success'] == true) {
                              final liked = result['liked'] == true;
                              final likesCount =
                                  (result['likesCount'] as num?)?.toInt() ??
                                  currentCount;
                              _onPostLikeChanged(postId, liked, likesCount);
                            }
                          },
                          onBookmarkChanged:
                              (bookmarked, bookmarksCount) async {
                                final postId = (item['_id'] ?? '').toString();
                                if (postId.isEmpty) return;
                                final currentBookmarked =
                                    item['isBookmarked'] ?? true;
                                final currentCount =
                                    (item['bookmarks_count'] as num?)
                                        ?.toInt() ??
                                    0;
                                setState(() {
                                  item['isBookmarked'] = !currentBookmarked;
                                  item['bookmarks_count'] = !currentBookmarked
                                      ? currentCount + 1
                                      : currentCount - 1;
                                });
                                final result =
                                    await PostService.togglePostBookmark(
                                      postId,
                                    );
                                if (result['success'] == true) {
                                  final bookmarked =
                                      result['bookmarked'] == true;
                                  final bookmarksCount =
                                      (result['bookmarksCount'] as num?)
                                          ?.toInt() ??
                                      currentCount;
                                  _onPostBookmarkChanged(
                                    postId,
                                    bookmarked,
                                    bookmarksCount,
                                  );
                                }
                              },
                          onShare: () {},
                          onReport: () {},
                          onMute: () {},
                          onCopyLink: () async {},
                        ),
                      );
                    } else if (itemType == 'activity') {
                      return _buildActivityCard(item);
                    } else if (itemType == 'place') {
                      return _buildPlaceCard(item);
                    }
                    return const SizedBox.shrink();
                  }, childCount: _filteredItems.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getItemType(Map<String, dynamic> item) {
    // Check for activity fields
    if (item.containsKey('titre') &&
        (item.containsKey('type_activite') || item.containsKey('typeActivite')))
      return 'activity';
    // Check for place fields
    if (item.containsKey('name') ||
        item.containsKey('titre') && item.containsKey('categorie'))
      return 'place';
    // Check for post fields
    if (item.containsKey('content') || item.containsKey('post_content'))
      return 'post';
    // Default to activity if it has titre but no content
    if (item.containsKey('titre') && !item.containsKey('content'))
      return 'activity';
    return 'post';
  }

  // Helper method to get timeline status
  String _getTimelineStatus(Map<String, dynamic> activityData) {
    final now = DateTime.now();
    final startDate = _parseDateTime(activityData['startDate']);
    final endDate = _parseDateTime(activityData['endDate']);

    if (startDate.isAfter(now)) {
      return 'UPCOMING';
    } else if (endDate.isAfter(now) || endDate.isAtSameMomentAs(now)) {
      return 'ONGOING';
    } else {
      return 'COMPLETED';
    }
  }

  // Helper method to parse datetime from various formats
  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    } else if (dateValue is DateTime) {
      return dateValue;
    }

    return DateTime.now();
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'UPCOMING':
        return const Color(0xFF10B981); // Green
      case 'ONGOING':
        return const Color(0xFFF59E0B); // Orange
      case 'COMPLETED':
        return const Color(0xFF6B7280); // Grey
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Helper method to get status text
  String _getStatusText(String status) {
    switch (status) {
      case 'UPCOMING':
        return 'ACTIVE';
      case 'ONGOING':
        return 'ONGOING';
      case 'COMPLETED':
        return 'COMPLETED';
      default:
        return 'UNKNOWN';
    }
  }

  // Helper method to format date
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';

    final dateTime = _parseDateTime(dateValue);
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  Widget _buildActivityCard(Map<String, dynamic> activityData) {
    final activityId = (activityData['_id'] ?? '').toString();
    final isBookmarked = activityData['isBookmarked'] ?? true;
    final bookmarksCount =
        (activityData['bookmarks_count'] as num?)?.toInt() ?? 0;

    // Get timeline status
    final timelineStatus = _getTimelineStatus(activityData);
    final statusColor = _getStatusColor(timelineStatus);
    final statusText = _getStatusText(timelineStatus);

    // Format dates
    final startDate = _formatDate(activityData['startDate']);
    final endDate = _formatDate(activityData['endDate']);

    // Get organizer info
    final organizerName =
        activityData['organisateur_id']?['fullname']?.toString() ??
        activityData['organisateur_id']?['name']?.toString() ??
        'Organizer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with status badge
            Stack(
              children: [
                if (activityData['photos'] != null &&
                    (activityData['photos'] as List).isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.network(
                      (activityData['photos'] as List).first.toString(),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF0F4FF), Color(0xFFE8F4FD)],
                          ),
                        ),
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Color(0xFF4B63FF),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF0F4FF), Color(0xFFE8F4FD)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Color(0xFF4B63FF),
                    ),
                  ),

                // Status badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Bookmark button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        final currentBookmarked =
                            activityData['isBookmarked'] ?? true;
                        final currentCount =
                            (activityData['bookmarks_count'] as num?)
                                ?.toInt() ??
                            0;
                        setState(() {
                          activityData['isBookmarked'] = !currentBookmarked;
                          activityData['bookmarks_count'] = !currentBookmarked
                              ? currentCount + 1
                              : currentCount - 1;
                        });
                        final result =
                            await ActivityService.toggleActivityBookmark(
                              activityId,
                            );
                        if (result['success'] == true) {
                          final bookmarked = result['bookmarked'] == true;
                          final bookmarksCount =
                              (result['bookmarksCount'] as num?)?.toInt() ??
                              currentCount;
                          _onActivityBookmarkChanged(
                            activityId,
                            bookmarked,
                            bookmarksCount,
                          );
                        }
                      },
                      icon: Icon(
                        isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border_rounded,
                        color: isBookmarked
                            ? const Color(0xFF4B63FF)
                            : const Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activityData['titre']?.toString() ?? 'Activity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2458),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Organizer name
                  Text(
                    organizerName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Location and dates row
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activityData['lieu']?.toString() ?? 'Location',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (startDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          startDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        if (endDate.isNotEmpty) ...[
                          const Text(
                            ' - ',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                          Text(
                            endDate,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom row with price and bookmarks
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activityData['prix'] ?? 0} TND',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4B63FF),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$bookmarksCount',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
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

  Widget _buildPlaceCard(Map<String, dynamic> placeData) {
    final lieuId = (placeData['_id'] ?? '').toString();
    final isBookmarked = placeData['isBookmarked'] ?? true;
    final bookmarksCount = (placeData['bookmarks_count'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlaceDetailScreenV2(place: placeData),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (placeData['main_image'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    placeData['main_image'].toString(),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: const Color(0xFFF0F4FF),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Color(0xFF4B63FF),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            placeData['name']?.toString() ?? 'Place',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2458),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final currentBookmarked =
                                placeData['isBookmarked'] ?? true;
                            final currentCount =
                                (placeData['bookmarks_count'] as num?)
                                    ?.toInt() ??
                                0;
                            setState(() {
                              placeData['isBookmarked'] = !currentBookmarked;
                              placeData['bookmarks_count'] = !currentBookmarked
                                  ? currentCount + 1
                                  : currentCount - 1;
                            });
                            final result = await LieuService.toggleLieuBookmark(
                              lieuId,
                            );
                            if (result['success'] == true) {
                              final bookmarked = result['bookmarked'] == true;
                              final bookmarksCount =
                                  (result['bookmarksCount'] as num?)?.toInt() ??
                                  currentCount;
                              _onPlaceBookmarkChanged(
                                lieuId,
                                bookmarked,
                                bookmarksCount,
                              );
                            }
                          },
                          icon: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border_rounded,
                            color: isBookmarked
                                ? const Color(0xFF4B63FF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      placeData['city']?.toString() ??
                          placeData['address']?.toString() ??
                          'Location',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          size: 16,
                          color: const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$bookmarksCount',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4B63FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4B63FF)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF4B63FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalBookmarkState {
  final bool bookmarked;
  final int bookmarksCount;

  const _LocalBookmarkState({
    required this.bookmarked,
    required this.bookmarksCount,
  });
}
