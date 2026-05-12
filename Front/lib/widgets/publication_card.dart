import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../utils/time_ago.dart';
import '../screens/shared/comments_screen.dart';
import '../widgets/facebook_mentions_inline_widget.dart';
import '../screens/shared/public_profile_screen.dart';

class PublicationCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final VoidCallback? onMute;
  final VoidCallback? onCopyLink;

  const PublicationCard({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onShare,
    this.onReport,
    this.onMute,
    this.onCopyLink,
  });

  @override
  State<PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  // Clean content by removing @mentions to avoid duplication with header mentions
  String _cleanContent(String content) {
    // Remove @mentions from content to avoid duplication with header mentions
    final mentionRegex = RegExp(r'@[a-zA-Z0-9_]{3,30}');
    return content.replaceAll(mentionRegex, '');
  }

  @override
  void initState() {
    super.initState();
    if (widget.post.imageUrls.length > 1) {
      _startAutoScroll();
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E225E),
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
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: const Color(0xFF4B63FF),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                widget.post.locationLabel!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4B63FF),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cleanContent(widget.post.content),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w500,
            ),
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
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hashtag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B63FF),
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
                      images[index],
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF4B63FF),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Color(0xFF94A3B8), size: 48),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          // Like
          _buildActionButton(
            icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
            count: widget.post.likesCount,
            color: widget.post.isLiked ? const Color(0xFFFF4757) : const Color(0xFF6B7280),
            onTap: widget.onLike,
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
          
          // Bookmark
          Container(
            decoration: BoxDecoration(
              color: widget.post.isBookmarked 
                  ? const Color(0xFFF0F4FF) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                widget.post.isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                color: widget.post.isBookmarked ? const Color(0xFF4B63FF) : const Color(0xFF6B7280),
                size: 22,
              ),
              onPressed: widget.onBookmark,
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color == const Color(0xFFFF4757) 
              ? const Color(0xFFFFF5F5) 
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Report option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFFFF4757),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Report post',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReport?.call();
                },
              ),
              
              // Mute author option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.block_outlined,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Mute author',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMute?.call();
                },
              ),
              
              // Copy link option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link_outlined,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Copy link',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCopyLink?.call();
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
