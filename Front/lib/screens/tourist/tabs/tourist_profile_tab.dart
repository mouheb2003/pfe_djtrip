import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/inscription_service.dart';
import '../../../services/post_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/app_theme.dart';
import '../../shared/edit_profile_screen.dart';
import '../../shared/settings_screen.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
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
        UserService.getProfile(),
        InscriptionService.getTouristStats(),
        PostService.getMyPosts(),
        AuthService.getUser(),
        PostService.getFeedPosts(),
      ]);

      if (!mounted) return;

      final apiUserData = results[0] as Map<String, dynamic>?;
      final cachedUserData = results[3] as Map<String, dynamic>?;
      final userData = apiUserData ?? cachedUserData;
      final user = userData != null ? UserModel.fromJson(userData) : null;
      final stats = _toMap(results[1]);
      final myPostsFromApi = _toMapList(results[2]);
      final feedPosts = _toMapList(results[4]);
      final currentUserId = (userData?['_id'] ?? '').toString();

      final myPosts =
          (myPostsFromApi.isNotEmpty
                  ? myPostsFromApi
                  : feedPosts.where((p) {
                      final author = p['author_id'];
                      final authorId = author is Map<String, dynamic>
                          ? (author['_id'] ?? author['id'] ?? '').toString()
                          : author?.toString() ?? '';
                      return currentUserId.isNotEmpty &&
                          authorId == currentUserId;
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
      barrierColor: Colors.black.withOpacity(0.25),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.84,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5D5E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever,
                      color: Color(0xFFC00445),
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Delete Post?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F245A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Are you sure you want to permanently delete this post?\nThis action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF555C8F),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC00445),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1853E5),
                        side: const BorderSide(
                          color: Color(0xFFD1D4E7),
                          width: 1.6,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
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

    if (confirmed != true) return;

    final result = await PostService.deletePost(postId);
    if (!mounted) return;

    if (result['success'] == true) {
      await _loadAll();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Unable to delete post.',
        ),
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
                    _ActionRow(
                      icon: Icons.inventory_2_rounded,
                      label: 'Archive Post',
                      iconColor: const Color(0xFF2051F2),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Archive coming soon.')),
                        );
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
                inputCtrl.clear();
              });
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
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.more_horiz_rounded),
                                iconSize: 20,
                                color: const Color(0xFF8B8FAE),
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
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: AspectRatio(
                                aspectRatio: 0.9,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
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
                              const SizedBox(width: 18),
                              const _DetailAction(icon: Icons.share_rounded),
                              const Spacer(),
                              const _DetailAction(
                                icon: Icons.bookmark_border_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _openCommentsSheet(post);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE7E3F4),
                                foregroundColor: const Color(0xFF4B4F73),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Voir les commentaires',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
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
    final raw = _user?.paysOrigine?.trim() ?? '';
    if (raw.isEmpty) return 'DJERBA, TN';
    return raw.toUpperCase();
  }

  String _safeBio() {
    final bio = _user?.bio?.trim() ?? '';
    if (bio.isNotEmpty) return bio;
    return 'Curating unique experiences across Djerba.';
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('[REBUILD] TouristProfileTab build');
    }

    final user = _user;
    final interests = user?.centresInteret ?? const <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
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
                  const Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131A4A),
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
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD0D8FF),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: user?.avatar != null
                            ? Image.network(
                                user!.avatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 42,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 42,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -16,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          // Empty box for spacing
                          const SizedBox(width: 74, height: 12),
                          // Badge with user type
                          if (user != null)
                            Container(
                              width: 74,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EDFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _isOrganizer ? 'ORGANIZER' : 'TOURIST',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: 58,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ).then((_) => _loadAll()),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
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
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: interests
                      .take(6)
                      .map((i) => _InterestChip(label: i))
                      .toList(),
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
                            title: 'Network Posts',
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

class _InterestChip extends StatelessWidget {
  final String label;

  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFCACEF8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2B3470),
        ),
      ),
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

  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.timeAgo,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final author = comment['author_id'] is Map<String, dynamic>
        ? comment['author_id'] as Map<String, dynamic>
        : <String, dynamic>{};
    final authorName = (author['fullname'] as String?) ?? 'Traveler';
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
                              authorName,
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
                        onTap: () => onReply(id, authorName),
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
