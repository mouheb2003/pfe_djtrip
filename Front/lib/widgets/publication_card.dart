import 'dart:async';

import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../utils/time_ago.dart';
import '../screens/shared/comments_screen.dart';

class PublicationCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;

  const PublicationCard({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onShare,
  });

  @override
  State<PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends State<PublicationCard> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8E5FF),
            backgroundImage: widget.post.authorAvatar?.isNotEmpty == true
                ? NetworkImage(widget.post.authorAvatar!)
                : null,
            child: widget.post.authorAvatar?.isEmpty != false
                ? const Icon(
                    Icons.person,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.post.authorName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E225E),
                      ),
                    ),
                    if (widget.post.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      TimeAgo.format(widget.post.createdAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.post.locationLabel != null && widget.post.locationLabel!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.post.locationLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // More options
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2D3748),
              height: 1.5,
            ),
          ),
          if (widget.post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.post.hashtags.map((tag) {
                final hashtag = tag.startsWith('#') ? tag : '#$tag';
                return Text(
                  hashtag,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B63FF),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
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
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 250,
        child: Stack(
          children: [
            // Image Carousel
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                      height: 250,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 250,
                          color: const Color(0xFFF0F4F8),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF4B63FF),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 250,
                        color: const Color(0xFFF0F4F8),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Color(0xFF94A3B8), size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Image not available',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
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
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _currentPage 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Image count badge
            if (images.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Like
          _buildActionButton(
            icon: widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
            count: widget.post.likesCount,
            color: widget.post.isLiked ? Colors.red : const Color(0xFF6B7280),
            onTap: widget.onLike,
          ),
          const SizedBox(width: 24),
          
          // Comment
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
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
          const SizedBox(width: 24),
          
          // Share
          _buildActionButton(
            icon: Icons.share,
            count: widget.post.sharesCount,
            color: const Color(0xFF6B7280),
            onTap: widget.onShare,
          ),
          
          const Spacer(),
          
          // Bookmark
          IconButton(
            icon: Icon(
              widget.post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: widget.post.isBookmarked ? const Color(0xFF4B63FF) : const Color(0xFF6B7280),
            ),
            onPressed: widget.onBookmark,
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
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
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
