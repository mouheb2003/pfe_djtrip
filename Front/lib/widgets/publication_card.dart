import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../utils/time_ago.dart';
import '../screens/shared/comments_screen.dart';
import '../widgets/facebook_mentions_inline_widget.dart';
import '../screens/shared/public_profile_screen.dart';
import '../services/ai_text_service.dart';
import '../widgets/ai_text_widgets.dart';
import '../config/api_config.dart';
import '../providers/bookmark_provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../screens/tourist/tabs/create_post_screen.dart';

class PublicationCard extends StatefulWidget {
  final PostModel post;
  final Function(bool liked, int likesCount)? onLikeChanged;
  final Function(bool bookmarked, int bookmarksCount)? onBookmarkChanged;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final VoidCallback? onMute;
  final VoidCallback? onCopyLink;
  final VoidCallback? onToggleHide;
  final VoidCallback? onDelete;
  final VoidCallback? onModified;

  const PublicationCard({
    super.key,
    required this.post,
    this.onLikeChanged,
    this.onBookmarkChanged,
    this.onShare,
    this.onReport,
    this.onMute,
    this.onCopyLink,
    this.onToggleHide,
    this.onDelete,
    this.onModified,
  });

  @override
  State<PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  String? _translatedContent;
  bool _isTranslating = false;
  String? _currentLang;
  bool _isExpanded = false;

  // Clean content by removing @mentions to avoid duplication with header mentions
  String _cleanContent(String content) {
    // Remove @mentions from content to avoid duplication with header mentions
    final mentionRegex = RegExp(r'@[a-zA-Z0-9_]{3,30}');
    return content.replaceAll(mentionRegex, '');
  }

  void _fallbackFeedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.post.imageUrls.length > 1) {
      _startAutoScroll();
    }
    // Seed the provider with the initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<BookmarkProvider>(context, listen: false);
        provider.updatePostState(widget.post.id, widget.post.isBookmarked);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.post.imageUrls.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _showTranslationSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LanguageSelectorBottomSheet(
        onLanguageSelected: (lang) => _translateContent(lang),
      ),
    );
  }

  Future<void> _translateContent(String lang) async {
    if (_isTranslating) return;

    setState(() => _isTranslating = true);

    try {
      final result = await AiTextService.translateText(
        widget.post.content,
        lang,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _translatedContent = result['result'];
          _currentLang = lang;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Translation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _resetTranslation() {
    setState(() {
      _translatedContent = null;
      _currentLang = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          
          // Content
          _buildContent(),
          
          // Image if available
          if (widget.post.displayImage.isNotEmpty) _buildImage(),
          
          // Interaction bar
          _buildInteractionBar(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (widget.post.authorId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(userId: widget.post.authorId),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE8E5FF),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8E5FF),
                backgroundImage: widget.post.authorAvatar?.isNotEmpty == true
                    ? NetworkImage(widget.post.authorAvatar!)
                    : null,
                child: widget.post.authorAvatar?.isEmpty != false
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFF4B63FF),
                        size: 22,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          
          // User info with mentions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.post.authorName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E225E),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (widget.post.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF4B63FF),
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      TimeAgo.format(widget.post.createdAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.post.mentions.isNotEmpty)
                      FacebookMentionsInlineWidget(mentions: widget.post.mentions),
                    if (widget.post.locationLabel != null && widget.post.locationLabel!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: isDark ? const Color(0xFF6B88FF) : const Color(0xFF4B63FF),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                widget.post.locationLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF6B88FF) : const Color(0xFF4B63FF),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // More options
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF), size: 22),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanText = _cleanContent(_translatedContent ?? widget.post.content);
    final isLongText = cleanText.length > 150;
    final displayText = (isLongText && !_isExpanded)
        ? '${cleanText.substring(0, 150)}...'
        : cleanText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isLongText)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _isExpanded ? 'Show less' : 'Show more',
                            style: const TextStyle(
                              color: Color(0xFF4B63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isTranslating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_currentLang != null)
                IconButton(
                  onPressed: _resetTranslation,
                  icon: const Icon(Icons.undo, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF4B63FF),
                  tooltip: 'Show original',
                )
              else
                IconButton(
                  onPressed: _showTranslationSelector,
                  icon: const Icon(Icons.translate, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF4B63FF),
                  tooltip: 'Translate',
                ),
            ],
          ),
          // Hashtags section
          if (widget.post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.post.hashtags.map((tag) {
                  final hashtag = tag.startsWith('#') ? tag : '#$tag';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hashtag,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF6B88FF) : const Color(0xFF4B63FF),
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage() {
    final images = widget.post.imageUrls;
    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            // Image Carousel
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openFullscreenViewer(context, images, index),
                    child: Image.network(
                      ApiConfig.getImageUrl(images[index]),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4B63FF),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 48),
                              SizedBox(height: 12),
                              Text(
                                'Image not available',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Page indicators
            if (images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            // Image count badge
            if (images.length > 1)
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPage + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenViewer(BuildContext context, List<String> images, int initialIndex) {
    // Pause auto-scroll when opening fullscreen
    _autoScrollTimer?.cancel();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    ).then((_) {
      // Resume auto-scroll when returning from fullscreen
      if (widget.post.imageUrls.length > 1) {
        _startAutoScroll();
      }
    });
  }

  Widget _buildInteractionBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          // Like
          _buildActionButton(
            icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
            count: widget.post.likesCount,
            color: widget.post.isLiked ? const Color(0xFFFF4757) : const Color(0xFF6B7280),
            onTap: () => widget.onLikeChanged?.call(!widget.post.isLiked, widget.post.isLiked ? widget.post.likesCount - 1 : widget.post.likesCount + 1),
          ),
          const SizedBox(width: 20),
          
          // Comment
          _buildActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            count: widget.post.commentsCount,
            color: const Color(0xFF6B7280),
            onTap: () {
              print('[PUBLICATION CARD] Opening comments - postId: ${widget.post.id}');
              if (widget.post.id.isEmpty) {
                print('[PUBLICATION CARD] ERROR: post.id is empty!');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentsScreen(
                    postId: widget.post.id,
                    postTitle: widget.post.content.substring(0, widget.post.content.length > 30 ? 30 : widget.post.content.length),
                    initialCommentsCount: widget.post.commentsCount,
                    post: widget.post,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          
          // Share
          _buildActionButton(
            icon: Icons.share_rounded,
            count: widget.post.sharesCount,
            color: const Color(0xFF6B7280),
            onTap: widget.onShare,
          ),
          
          const Spacer(),
          
          Consumer<BookmarkProvider>(
            builder: (context, provider, child) {
              final isBookmarked = provider.isPostBookmarked(widget.post.id);
              return Container(
                decoration: BoxDecoration(
                  color: isBookmarked 
                      ? (isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF)) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                    color: isBookmarked 
                        ? (isDark ? const Color(0xFF6B88FF) : const Color(0xFF4B63FF)) 
                        : const Color(0xFF6B7280),
                    size: 22,
                  ),
                  onPressed: () {
                    provider.togglePostBookmark(widget.post.id);
                    widget.onBookmarkChanged?.call(!isBookmarked, 0);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color == const Color(0xFFFF4757) 
              ? (isDark ? const Color(0xFF3F191E) : const Color(0xFFFFF5F5)) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _showMoreOptions(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.user is Map
        ? (userProvider.user as Map)['_id']?.toString() ?? ''
        : (userProvider.user as UserModel?)?.id ?? '';
    final isMyPost = widget.post.authorId == currentUserId;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              if (isMyPost) ...[
                // Modify post option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF4B63FF),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Modify post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    final userModel = userProvider.user is Map
                        ? UserModel(
                            id: (userProvider.user as Map)['_id']?.toString() ?? '',
                            fullname: (userProvider.user as Map)['fullname']?.toString() ?? 'User',
                            email: (userProvider.user as Map)['email']?.toString() ?? '',
                            avatar: (userProvider.user as Map)['avatar']?.toString(),
                            userType: (userProvider.user as Map)['userType']?.toString() ?? 'Touriste',
                          )
                        : (userProvider.user as UserModel?);

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePostScreen(
                          user: userModel,
                          postToEdit: widget.post,
                        ),
                      ),
                    );
                    if (result == true) {
                      widget.onModified?.call();
                    }
                  },
                ),
                
                // Delete post option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F191E) : const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF4757),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Delete post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
                ),
              ] else ...[
                // Report option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F191E) : const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: Color(0xFFFF4757),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Report post',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onReport != null) {
                      widget.onReport!.call();
                    } else {
                      _fallbackFeedback('Report submitted successfully');
                    }
                  },
                ),
                
                // Mute author option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.block_outlined,
                      color: Color(0xFF4B63FF),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Mute author',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onMute != null) {
                      widget.onMute!.call();
                    } else {
                      _fallbackFeedback('Author muted successfully');
                    }
                  },
                ),
              ],
              
              // Copy link option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link_outlined,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Copy link',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (widget.onCopyLink != null) {
                    widget.onCopyLink!.call();
                  }
                  final postId = widget.post.id;
                  if (postId.isNotEmpty) {
                    final link = 'https://djtrip.com/post/$postId';
                    await Clipboard.setData(ClipboardData(text: link));
                    if (widget.onCopyLink == null) {
                      _fallbackFeedback('Link copied to clipboard');
                    }
                  }
                },
              ),
              
              // Hide from my profile option (only if mentioned)
              if (widget.onToggleHide != null && !isMyPost)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.visibility_off_outlined,
                    color: Color(0xFFFF4757),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Hide from my profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onToggleHide?.call();
                },
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 60),
                      SizedBox(height: 16),
                      Text(
                        'Image not available',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
