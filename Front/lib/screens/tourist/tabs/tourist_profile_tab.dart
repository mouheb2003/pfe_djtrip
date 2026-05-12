import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../../shared/edit_profile_screen.dart';
import '../../shared/settings_screen.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
import '../place_detail_screen.dart';
import '../all_places_simple.dart';
import '../../../widgets/mention_text_widget.dart';
import 'screen_network.dart';

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
                  ? myPostsFromApi
                  : feedPosts.where((p) {
                      final author = p['author_id'];
                      final authorId = author is Map<String, dynamic>
                          ? (author['_id'] ?? author['id'] ?? '').toString()
                          : author?.toString() ?? '';
                      return currentUserId.isNotEmpty && authorId == currentUserId;
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

  void _copyUsername(String username) {
    Clipboard.setData(ClipboardData(text: '@$username'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Username @$username copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                      icon: const Icon(
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
        return SafeArea(
          child: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
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
                      color: const Color(0xFFFFF2F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Title
                  const Text(
                    'Delete Post',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  const Text(
                    'This post will be permanently deleted.\nYou won\'t be able to recover it later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Delete button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Unable to delete post.',
        ),
        backgroundColor: const Color(0xFFDC2626),
      ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post updated.')));
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
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB6B6CC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                                        const Divider(height: 26, color: Color(0xFFE0E1EF)),
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
      backgroundColor: const Color(0xFFF6F6FD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message']?.toString() ?? 'Unable to add comment.',
                    ),
                  ),
                );
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D245E),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${workingComments.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6770A3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Replying to $replyToName',
                                    style: const TextStyle(
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
                                  icon: const Icon(Icons.close, size: 18),
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
                              decoration: const InputDecoration(
                                hintText: 'Write a comment...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(18),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Send'),
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
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: place),
      ),
    );
  }

  void _navigateToAllPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AllPlacesSimpleScreen(),
      ),
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

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2FA),
                        borderRadius: BorderRadius.circular(22),
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
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Color(0xFF2C3360),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(parsedDate).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
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
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6E1FA),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Color(0xFF6D5FD8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    locationLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5F53BA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (content.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF263165),
                              ),
                            ),
                          ],
                          if (hashtags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: hashtags
                                  .map(
                                    (tag) => Text(
                                      tag,
                                      style: const TextStyle(
                                        color: Color(0xFF1B66E5),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (galleryUrls.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: AutoImageCarousel(
                                imageUrls: galleryUrls,
                                height: 340,
                                showIndicators: galleryUrls.length > 1,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DetailAction(
                                icon: Icons.favorite,
                                label: '$likes',
                              ),
                              const SizedBox(width: 18),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            elevation: 6,
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
              if (created == true) _loadAll();
            },
            child: const Icon(Icons.add, size: 28, color: Colors.white),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onNavigateToTab?.call(0),
                    icon: const Icon(Icons.arrow_back),
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
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    icon: const Icon(Icons.settings),
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── Cover Photo + Avatar ────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Cover photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Image.network(
                        _getCoverPhotoUrl(),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
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
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
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
              const SizedBox(height: 56),
              // ── Badge ───────────────────────────────────────────────
              if (user != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _isOrganizer ? 'ORGANIZER' : 'TOURIST',
                          style: const TextStyle(
                            fontSize: 10,
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
              const SizedBox(height: 18),
              Text(
                user?.fullname ?? 'Traveler',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2458),
                ),
              ),
              const SizedBox(height: 2),

              // ── Username ───────────────────────────────────
              if (user?.username != null && user!.username!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alternate_email,
                        size: 16,
                        color: const Color(0xFF6C757D),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '@${user!.username}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF495057),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          _copyUsername(user!.username!);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D6EFD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (user?.username != null && user!.username!.isNotEmpty)
                const SizedBox(height: 8),
              Text(
                _displayLocation(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _safeBio(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF56608B),
                  ),
                ),
              ),
              if (!_isOrganizer && interests.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: interests
                        .map(
                          (interest) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EDFF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              interest,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B4A8F),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        value: '$_bookingsCount',
                        label: 'Bookings',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: _StatItem(value: '$_postsCount', label: 'Posts'),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: const Color(0xFFD8D9EC),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: '$_reviewsCount',
                        label: 'Reviews',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ).then((_) => _loadAll()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8E8F6),
                        side: BorderSide.none,
                        foregroundColor: const Color(0xFF46508A),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Settings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _openCreatePostDialog,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: _user?.avatar != null
                            ? NetworkImage(_user!.avatar!)
                            : null,
                        child: _user?.avatar == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tap to create a new post',
                          style: TextStyle(
                            color: Color(0xFF8C90B3),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MANAGED',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text(
                    'My Posts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2458),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScreenNetwork(
                            showBackButton: true,
                            title: 'My Posts',
                            showOnlyMyPosts: true,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'VIEW ALL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_myPosts.isEmpty)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'No posts yet',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _myPosts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final post = _myPosts[index];
                    return _PostCard(
                      post: post,
                      onMore: () => _showPostActions(post),
                      onOpenDetails: () => _openPostDetailsSheet(post),
                    );
                  },
                ),
            const SizedBox(height: 20),
            // Favorites Places Section
            const Text(
              'FAVORITES PLACES',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Text(
                  'Your Favorite Places',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2458),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _navigateToAllPlaces,
                  child: const Text(
                    'SEE ALL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_featuredPlaces.isEmpty)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'No favorite places yet',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _featuredPlaces.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final place = _featuredPlaces[index];
                  return _PlaceCard(
                    place: place,
                    onTap: () => _navigateToPlaceDetails(place),
                  );
                },
              ),
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

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6F7396),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onMore;
  final VoidCallback onOpenDetails;

  const _PostCard({
    required this.post,
    required this.onMore,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onOpenDetails,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8E8F6),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Color(0xFF8C93BE),
                            size: 38,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE8E8F6),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xFF8C93BE),
                          size: 38,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onMore,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
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
          const SizedBox(width: 5),
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFF7DFE8)
              : const Color(0xFFE2E1FA),
          borderRadius: BorderRadius.circular(17),
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
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: textColor ?? const Color(0xFF1D245D),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
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
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              authorId == currentUserId ? 'You' : authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D245D),
                              ),
                            ),
                          ),
                          Text(
                            timeAgo(created),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A8FBA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: const TextStyle(color: Color(0xFF40497C)),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => onReply(id, authorId == currentUserId ? 'You' : authorName),
                        child: const Text(
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
              padding: const EdgeInsets.only(left: 24, top: 8),
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
      child: const Icon(Icons.person, size: 42, color: Color(0xFF8892AE)),
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
      child: const Icon(Icons.edit, size: 15, color: Colors.white),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.onTap,
  });

  String get _name => (place['name'] ?? place['title'] ?? place['titre'] ?? 'Place').toString();
  String get _image => (place['main_image'] ?? place['image'] ?? place['imagePortrait'] ?? '').toString();
  String get _city => (place['city'] ?? '').toString();
  String get _rating => (place['rating'] ?? '0.0').toString();
  bool get _isFeatured => place['is_featured'] == true || place['top_destination'] == true || place['topDestination'] == true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: const Color(0xFFF5F5F5),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: _image.isNotEmpty
                          ? Image.network(
                              _image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8E8F6),
                                child: const Center(
                                  child: Icon(
                                    Icons.location_on,
                                    size: 40,
                                    color: Color(0xFFB8BCC8),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFE8E8F6),
                              child: const Center(
                                child: Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: Color(0xFFB8BCC8),
                                ),
                              ),
                            ),
                    ),
                  ),
                  // Featured badge
                  if (_isFeatured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Guide arrow
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GuideArrowButton(onTap: onTap),
                  ),
                ],
              ),
            ),
            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _city.isNotEmpty ? _city : 'Location',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _rating,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
