import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/inscription_service.dart';
import '../../../services/lieu_service.dart';
import '../../../services/post_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auto_image_carousel.dart';
import '../../../widgets/guide_arrow_button.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
import '../place_detail_screen_v2.dart';
import '../all_places_simple.dart';
import '../../../widgets/mention_text_widget.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../services/follow_service.dart';
import '../../shared/relations_screen.dart';
import '../../shared/settings_screen.dart';

class TouristProfileTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const TouristProfileTab({super.key, this.onNavigateToTab});

  @override
  State<TouristProfileTab> createState() => _TouristProfileTabState();
}

class _TouristProfileTabState extends State<TouristProfileTab> {
  UserModel? _user;
  int _bookingsCount = 0;
  int _postsCount = 0;
  int _reviewsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingAll = false;

  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _featuredPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is List<Map<String, dynamic>>) return value;
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  Future<void> _loadAll() async {
    if (_isLoadingAll) {
      if (kDebugMode) {
        debugPrint(
          '[REBUILD] TouristProfileTab skip _loadAll (already loading)',
        );
      }
      return;
    }

    _isLoadingAll = true;
    try {
      if (kDebugMode) {
        debugPrint('[API CALL] TouristProfileTab _loadAll');
      }

      final results = await Future.wait([
        UserService.getProfile(forceRefresh: true),
        InscriptionService.getTouristStats(),
        PostService.getMyPosts(),
        AuthService.getUser(),
        PostService.getFeedPosts(),
        LieuService.getFeaturedLieuxAsMap(),
      ]);

      if (!mounted) return;

      final apiUserData = results[0] as Map<String, dynamic>?;
      final cachedUserData = results[3] as Map<String, dynamic>?;
      final userData = apiUserData ?? cachedUserData;
      final user = userData != null ? UserModel.fromJson(userData) : null;
      final stats = _toMap(results[1]);
      final myPostsFromApi = _toMapList(results[2]);
      final feedPosts = _toMapList(results[4]);
      final featuredPlaces = _toMapList(results[5]);
      final currentUserId = (userData?['_id'] ?? '').toString();

      final myPosts =
          (myPostsFromApi.isNotEmpty
                  ? myPostsFromApi.where((p) {
                      final hiddenProfiles = (p['hidden_from_profiles'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      return !hiddenProfiles.contains(currentUserId);
                    }).toList()
                  : feedPosts.where((p) {
                      final author = p['author_id'];
                      final authorId = author is Map<String, dynamic>
                          ? (author['_id'] ?? author['id'] ?? '').toString()
                          : author?.toString() ?? '';
                      final hiddenProfiles = (p['hidden_from_profiles'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      if (hiddenProfiles.contains(currentUserId)) {
                        return false;
                      }
                      final mentions = (p['mentions'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      return currentUserId.isNotEmpty &&
                          (authorId == currentUserId || mentions.contains(currentUserId));
                    }).toList())
              .take(12)
              .toList();
      final reviewsFromStats = (stats['totalReviews'] as num?)?.toInt();
      final reviewsFromSnake = (userData?['nombre_avis'] as num?)?.toInt();
      final reviewsFromCamel = (userData?['nombreAvis'] as num?)?.toInt();

      setState(() {
        _user = user;
        _bookingsCount = (stats['totalBookings'] as num?)?.toInt() ?? 0;
        _postsCount = myPosts.length;
        _reviewsCount =
            reviewsFromStats ??
            reviewsFromSnake ??
            reviewsFromCamel ??
            user?.nombreAvis ??
            0;
        _myPosts = myPosts;
        _featuredPlaces = featuredPlaces.take(6).toList();
      });

      if (currentUserId.isNotEmpty) {
        final followers = await FollowService.getFollowersCount(currentUserId);
        final following = await FollowService.getFollowingCount(currentUserId);
        if (mounted) {
          setState(() {
            _followersCount = followers;
            _followingCount = following;
          });
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TouristProfileTab] load failed: $e');
        debugPrintStack(stackTrace: st);
      }
      if (!mounted) return;
      setState(() {
        _bookingsCount = 0;
        _postsCount = 0;
        _reviewsCount = 0;
        _followersCount = 0;
        _followingCount = 0;
        _myPosts = <Map<String, dynamic>>[];
        _featuredPlaces = <Map<String, dynamic>>[];
      });
    } finally {
      _isLoadingAll = false;
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }


  void _showAvatarFullScreen(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Avatar Full Screen',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                  Center(
                    child: Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.70,
                        height: MediaQuery.of(context).size.width * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _isOrganizer {
    return _user?.isOrganisator ?? false;
  }

  Future<void> _openCreatePostDialog() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(user: _user)),
    );
    if (!mounted || created != true) return;
    await _loadAll();
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete post',
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (context, _, __) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Center(
            child: Container(
              width: 320,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1616) : const Color(0xFFFFF2F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 28,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Title
                  Text(
                    'Delete Post',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Description
                  Text(
                    'This post will be permanently deleted.\nYou won\'t be able to recover it later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Buttons
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // Delete button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final result = await PostService.deletePost(postId);
    if (!mounted) return;

    if (result['success'] == true) {
      await _loadAll();
      SnackbarUtils.showSuccess(context, 'Post deleted successfully');
      return;
    }

    SnackbarUtils.showError(
      context, 
      result['message']?.toString() ?? 'Unable to delete post.'
    );
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );

    if (!mounted || updated != true) return;
    await _loadAll();
    if (!mounted) return;
    SnackbarUtils.showSuccess(context, 'Post updated.');
  }

  Future<void> _showPostActions(Map<String, dynamic> post) async {
    final postId = (post['_id'] ?? post['id'] ?? '').toString();
    if (postId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.22),
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: 30),
              child: Container(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 26),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3E3E4A) : const Color(0xFFB6B6CC),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _ActionRow(
                      icon: Icons.edit_rounded,
                      label: 'Edit Post',
                      iconColor: const Color(0xFF2051F2),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _editPost(post);
                      },
                    ),
                    _ActionRow(
                      icon: Icons.share_rounded,
                      label: 'Share Post',
                      iconColor: const Color(0xFF2051F2),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final content =
                            (post['content'] as String?)?.trim() ??
                            'Post from DJTrip';
                        await Share.share(content);
                      },
                    ),
                    Divider(height: 26, color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E1EF)),
                    _ActionRow(
                      icon: Icons.delete_rounded,
                      label: 'Delete Post',
                      iconColor: const Color(0xFFC00445),
                      textColor: const Color(0xFFC00445),
                      destructive: true,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _deletePost(postId);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCommentsSheet(Map<String, dynamic> post) async {
    final postId = (post['_id'] ?? post['id'] ?? '').toString();
    if (postId.isEmpty) return;

    final comments = await PostService.getPostComments(postId);
    if (!mounted) return;

    // Get current user ID
    final currentUser = AuthService.currentUser;
    final currentUserId = (currentUser?['_id'] ?? '').toString();

    final inputCtrl = TextEditingController();
    String? replyToId;
    String replyToName = '';
    var workingComments = List<Map<String, dynamic>>.from(comments);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F6FD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final byParent = <String, List<Map<String, dynamic>>>{};
            for (final c in workingComments) {
              final key = (c['parent_comment_id'] ?? '').toString();
              byParent.putIfAbsent(key, () => []).add(c);
            }

            List<Map<String, dynamic>> tree(String parentId) {
              return byParent[parentId] ?? const [];
            }

            Future<void> submit() async {
              final text = inputCtrl.text.trim();
              if (text.isEmpty) return;

              final result = await PostService.addPostComment(
                postId: postId,
                content: text,
                parentCommentId: replyToId,
              );
              if (result['success'] != true) {
                if (!mounted) return;
                SnackbarUtils.showError(context, result['message']?.toString() ?? 'Unable to add comment.');
                return;
              }

              final latest = await PostService.getPostComments(postId);
              setModalState(() {
                workingComments = latest;
                replyToId = null;
                replyToName = '';
              });
              inputCtrl.clear();
              await _loadAll();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.76,
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D245E),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${workingComments.length}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6770A3),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Expanded(
                        child: ListView(
                          children: [
                            ...tree('').map(
                              (c) => _CommentTile(
                                comment: c,
                                timeAgo: _timeAgo,
                                onReply: (id, authorName) {
                                  setModalState(() {
                                    replyToId = id;
                                    replyToName = authorName;
                                  });
                                },
                                replies: tree(c['_id']?.toString() ?? ''),
                                currentUserId: currentUserId,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (replyToId != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Replying to $replyToName',
                                    style: TextStyle(
                                      color: Color(0xFF636CA0),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setModalState(() {
                                      replyToId = null;
                                      replyToName = '';
                                    });
                                  },
                                  icon: Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: inputCtrl,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(18.r),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          FilledButton(
                            onPressed: submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: Text('Send'),
                          ),
                        ],
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
  }

  void _navigateToPlaceDetails(Map<String, dynamic> place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceDetailScreenV2(place: place)),
    );
  }

  void _navigateToAllPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllPlacesSimpleScreen()),
    );
  }

  Future<void> _openPostDetailsSheet(Map<String, dynamic> post) async {
    final imageUrls =
        (post['image_urls'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final imageUrl = imageUrls.isNotEmpty
        ? imageUrls.first
        : (post['image_url'] as String?)?.trim() ?? '';
    final galleryUrls = <String>[
      ...imageUrls,
      if (imageUrls.isEmpty && imageUrl.isNotEmpty) imageUrl,
    ];
    final author = post['author_id'] is Map<String, dynamic>
        ? post['author_id'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name = (author['fullname'] as String?) ?? 'Traveler';
    final avatar = (author['avatar'] as String?) ?? '';
    final content = (post['content'] as String?)?.trim() ?? '';
    final locationLabel = (post['location_label'] as String?)?.trim() ?? '';
    final hashtags =
        (post['hashtags'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final likes = (post['likes_count'] as num?)?.toInt() ?? 0;
    final commentsCount = (post['comments_count'] as num?)?.toInt() ?? 0;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Post details',
      barrierColor: Colors.black.withOpacity(0.24),
      pageBuilder: (dialogContext, _, __) {
        final postedAt = post['created_at'] ?? post['createdAt'];
        DateTime? parsedDate;
        if (postedAt is String) {
          parsedDate = DateTime.tryParse(postedAt);
        }

        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.84;
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 390,
                    maxHeight: maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2FA),
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16.sp,
                                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF2C3360),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(parsedDate).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFFB2B5CA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (locationLabel.isNotEmpty) ...[
                            SizedBox(height: 10.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2B2545) : const Color(0xFFE6E1FA),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Color(0xFF6D5FD8),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    locationLabel,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFAFA3E8) : const Color(0xFF5F53BA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (content.isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            Text(
                              content,
                              style: TextStyle(
                                fontSize: 15.sp,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF263165),
                              ),
                            ),
                          ],
                          if (hashtags.isNotEmpty) ...[
                            SizedBox(height: 10.h),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: hashtags
                                  .map(
                                    (tag) => Text(
                                      tag,
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF6B9CFF) : const Color(0xFF1B66E5),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          SizedBox(height: 14.h),
                          if (galleryUrls.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18.r),
                              child: AutoImageCarousel(
                                imageUrls: galleryUrls,
                                height: 340,
                                showIndicators: galleryUrls.length > 1,
                              ),
                            ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              _DetailAction(
                                icon: Icons.favorite,
                                label: '$likes',
                              ),
                              SizedBox(width: 18.w),
                              _DetailAction(
                                icon: Icons.chat_bubble,
                                label: '$commentsCount',
                              ),
                              const Spacer(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _displayLocation() {
    final parts = <String>[];

    if (_user?.paysOrigine?.isNotEmpty == true) {
      final countryName = _user!.paysOrigine!;
      final flag = _getCountryFlag(countryName);
      parts.add('$flag $countryName');
    }

    return parts.join(' • ');
  }

  String _getCountryFlag(String country) {
    if (country.isEmpty) return '�';

    // Clean the country name - remove extra spaces and lowercase
    final cleanCountry = country.trim().toLowerCase();

    // Common country codes to flag emojis
    final countryFlags = {
      // Tunisia variations
      'tn': '🇹🇳',
      'tunisia': '🇹🇳',
      'tunisie': '🇹🇳',
      'tunisian': '🇹🇳',
      // France variations
      'fr': '🇫🇷',
      'france': '🇫🇷',
      // USA variations
      'us': '🇺🇸',
      'usa': '🇺🇸',
      'united states': '🇺🇸',
      'united states of america': '🇺🇸',
      'america': '🇺🇸',
      // UK variations
      'gb': '🇬🇧',
      'uk': '🇬🇧',
      'united kingdom': '🇬🇧',
      'britain': '🇬🇧',
      'great britain': '🇬🇧',
      'england': '🇬🇧',
      // Germany
      'de': '🇩🇪',
      'germany': '🇩🇪',
      'allemagne': '🇩🇪',
      // Italy
      'it': '🇮🇹',
      'italy': '🇮🇹',
      'italie': '🇮🇹',
      // Spain
      'es': '🇪🇸',
      'spain': '🇪🇸',
      'espagne': '🇪🇸',
      // Morocco
      'ma': '🇲🇦',
      'morocco': '🇲🇦',
      'maroc': '🇲🇦',
      // Algeria
      'dz': '🇩🇿',
      'algeria': '🇩🇿',
      'algerie': '🇩🇿',
      // Egypt
      'eg': '🇪🇬',
      'egypt': '🇪🇬',
      'egypte': '🇪🇬',
      // Libya
      'ly': '🇱🇾',
      'libya': '🇱🇾',
      'libye': '🇱🇾',
      // Saudi Arabia
      'sa': '🇸🇦',
      'saudi arabia': '🇸🇦',
      'arabie saoudite': '🇸🇦',
      // UAE
      'ae': '🇦🇪',
      'uae': '🇦🇪',
      'emirates': '🇦🇪',
      'united arab emirates': '🇦🇪',
      // Qatar
      'qa': '🇶🇦',
      'qatar': '🇶🇦',
      // Canada
      'ca': '🇨🇦',
      'canada': '🇨🇦',
      // Australia
      'au': '🇦🇺',
      'australia': '🇦🇺',
      'australie': '🇦🇺',
      // Japan
      'jp': '🇯🇵',
      'japan': '🇯🇵',
      'japon': '🇯🇵',
      // China
      'cn': '🇨🇳',
      'china': '🇨🇳',
      'chine': '🇨🇳',
      // India
      'in': '🇮🇳',
      'india': '🇮🇳',
      'inde': '🇮🇳',
      // Brazil
      'br': '🇧🇷',
      'brazil': '🇧🇷',
      'bresil': '🇧🇷',
      // Mexico
      'mx': '🇲🇽',
      'mexico': '🇲🇽',
      'mexique': '🇲🇽',
      // Argentina
      'ar': '🇦🇷',
      'argentina': '🇦🇷',
      'argentine': '🇦🇷',
      // South Africa
      'za': '🇿🇦',
      'south africa': '🇿🇦',
      'afrique du sud': '🇿🇦',
      // Nigeria
      'ng': '🇳🇬',
      'nigeria': '🇳🇬',
      // Kenya
      'ke': '🇰🇪',
      'kenya': '🇰🇪',
      // Turkey
      'tr': '🇹🇷',
      'turkey': '🇹🇷',
      'turquie': '🇹🇷',
      // Greece
      'gr': '🇬🇷',
      'greece': '🇬🇷',
      'grece': '🇬🇷',
      // Netherlands
      'nl': '🇳🇱',
      'netherlands': '🇳🇱',
      'pays-bas': '🇳🇱',
      'pays bas': '🇳🇱',
      // Belgium
      'be': '🇧🇪',
      'belgium': '🇧🇪',
      'belgique': '🇧🇪',
      // Switzerland
      'ch': '🇨🇭',
      'switzerland': '🇨🇭',
      'suisse': '🇨🇭',
      // Sweden
      'se': '🇸🇪',
      'sweden': '🇸🇪',
      'suede': '🇸🇪',
      // Norway
      'no': '🇳🇴',
      'norway': '🇳🇴',
      'norvege': '🇳🇴',
      // Denmark
      'dk': '🇩🇰',
      'denmark': '🇩🇰',
      'danemark': '🇩🇰',
      // Finland
      'fi': '🇫🇮',
      'finland': '🇫🇮',
      'finlande': '🇫🇮',
      // Poland
      'pl': '🇵🇱',
      'poland': '🇵🇱',
      'pologne': '🇵🇱',
      // Czech Republic
      'cz': '🇨🇿',
      'czech': '🇨🇿',
      'czech republic': '🇨🇿',
      'republique tcheque': '🇨🇿',
      // Austria
      'at': '🇦🇹',
      'austria': '🇦🇹',
      'autriche': '🇦🇹',
      // Hungary
      'hu': '🇭🇺',
      'hungary': '🇭🇺',
      'hongrie': '🇭🇺',
      // Portugal
      'pt': '🇵🇹',
      'portugal': '🇵🇹',
      // Russia
      'ru': '🇷🇺',
      'russia': '🇷🇺',
      'russie': '🇷🇺',
      // Ukraine
      'ua': '🇺🇦',
      'ukraine': '🇺🇦',
      // Romania
      'ro': '🇷🇴',
      'romania': '🇷🇴',
      'roumanie': '🇷🇴',
      // Bulgaria
      'bg': '🇧🇬',
      'bulgaria': '🇧🇬',
      'bulgarie': '🇧🇬',
      // Croatia
      'hr': '🇭🇷',
      'croatia': '🇭🇷',
      'croatie': '🇭🇷',
      // Slovenia
      'si': '🇸🇮',
      'slovenia': '🇸🇮',
      'slovenie': '🇸🇮',
      // Slovakia
      'sk': '🇸🇰',
      'slovakia': '🇸🇰',
      'slovaquie': '🇸🇰',
      // Estonia
      'ee': '🇪🇪',
      'estonia': '🇪🇪',
    };

    return countryFlags[cleanCountry] ?? '🌍';
  }

  String _safeBio() {
    final bio = _user?.bio?.trim() ?? '';
    if (bio.isNotEmpty) return bio;
    return 'Curating unique experiences across Djerba.';
  }

  // ─── Cover Photo URL ──────────────────────────────────────────────
  String _getCoverPhotoUrl() {
    final coverPhoto = _user?.coverPhoto;
    if (coverPhoto != null && coverPhoto.isNotEmpty) {
      return coverPhoto;
    }
    // Fallback to default image
    return 'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1400&q=80';
  }

  List<String> _profileInterests() {
    final raw = _user?.centresInteret ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('[REBUILD] TouristProfileTab build');
    }

    final user = _user;
    final interests = _profileInterests();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F1FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onNavigateToTab?.call(0),
                    icon: Icon(Icons.arrow_back),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.settings_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              // ── Cover Photo + Avatar ────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Cover photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22.r),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Image.network(
                        _getCoverPhotoUrl(),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4D74F5), Color(0xFF7B93FF)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Avatar overlapping the cover (Instagram style with blurred glow)
                  Positioned(
                    bottom: -50,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Blurred Glow Background
                        if (_user?.avatar != null)
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 12,
                              sigmaY: 12,
                            ),
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.15),
                                image: DecorationImage(
                                  image: NetworkImage(_user!.avatar!),
                                  fit: BoxFit.cover,
                                  opacity: 0.6,
                                ),
                              ),
                            ),
                          ),

                        // Main Avatar with White Border
                        GestureDetector(
                          onTap: () => _showAvatarFullScreen(_user?.avatar),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 3),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Hero(
                              tag: 'profile_avatar',
                              child: ClipOval(
                                child: _user?.avatar != null
                                    ? Image.network(
                                        _user!.avatar!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _DefaultAvatar(),
                                      )
                                    : _DefaultAvatar(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 56.h),
              // ── Badge ───────────────────────────────────────────────
              if (user != null)
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A264F) : const Color(0xFFE8EDFF),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _isOrganizer ? 'ORGANIZER' : 'TOURIST',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 18.h),
              Text(
                user?.fullname ?? 'Traveler',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1B2458),
                ),
              ),
              SizedBox(height: 2.h),

              Text(
                _displayLocation(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _safeBio(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.35,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF56608B),
                  ),
                ),
              ),
              if (!_isOrganizer && interests.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: interests
                        .map(
                          (interest) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                           decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A264F) : const Color(0xFFE8EDFF),
                              borderRadius: BorderRadius.circular(999.r),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFA2B4FF) : const Color(0xFF3B4A8F),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              // Unified stats bar: Posts | Reservations | Relations
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8F6),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        value: '$_postsCount',
                        label: 'Posts',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: '$_bookingsCount',
                        label: 'Reservations',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          final userId = (_user?.id ?? '').toString();
                          if (userId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RelationsScreen(userId: userId),
                              ),
                            );
                          }
                        },
                        child: _StatItem(
                          value: '${_followersCount + _followingCount}',
                          label: 'Relations',
                          icon: Icons.people_alt_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;

  const _StatItem({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primary),
              SizedBox(width: 3.w),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : const Color(0xFF6F7396),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String? label;

  const _DetailAction({required this.icon, this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF7D7FA4)),
        if (label != null) ...[
          SizedBox(width: 5.w),
          Text(
            label!,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7D7FA4),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? textColor;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.textColor,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: destructive
              ? (isDark ? const Color(0xFF4A1A24) : const Color(0xFFF7DFE8))
              : (isDark ? const Color(0xFF2B2B4A) : const Color(0xFFE2E1FA)),
          borderRadius: BorderRadius.circular(17.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5.sp,
          fontWeight: FontWeight.w700,
          color: textColor ?? (isDark ? Colors.white : const Color(0xFF1D245D)),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: destructive ? const Color(0xFFC00445) : const Color(0xFF8C93BE),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;
  final String Function(DateTime?) timeAgo;
  final void Function(String id, String authorName) onReply;
  final String currentUserId;

  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.timeAgo,
    required this.onReply,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = comment['author_id'] is Map<String, dynamic>
        ? comment['author_id'] as Map<String, dynamic>
        : <String, dynamic>{};
    final authorName = (author['fullname'] as String?) ?? 'Traveler';
    final authorId = (author['_id'] ?? author['id'] ?? '').toString();
    final authorAvatar = (author['avatar'] as String?) ?? '';
    final content = (comment['content'] as String?)?.trim() ?? '';
    final id = (comment['_id'] ?? '').toString();
    final created = DateTime.tryParse(comment['createdAt']?.toString() ?? '');

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: authorAvatar.isNotEmpty
                      ? NetworkImage(authorAvatar)
                      : null,
                  child: authorAvatar.isEmpty
                      ? Icon(Icons.person, size: 16)
                      : null,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              authorId == currentUserId ? 'You' : authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1D245D),
                              ),
                            ),
                          ),
                          Text(
                            timeAgo(created),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF8A8FBA),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        content,
                        style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF40497C)),
                      ),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () => onReply(
                          id,
                          authorId == currentUserId ? 'You' : authorName,
                        ),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 24, top: 8),
              child: Column(
                children: replies
                    .map(
                      (r) => _CommentTile(
                        comment: r,
                        replies: const [],
                        timeAgo: timeAgo,
                        onReply: onReply,
                        currentUserId: currentUserId,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E7F6),
      child: Icon(Icons.person, size: 42, color: Color(0xFF8892AE)),
    );
  }
}

class _EditBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.edit, size: 15, color: Colors.white),
    );
  }
}
