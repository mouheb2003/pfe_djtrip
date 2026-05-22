import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../providers/bookmark_provider.dart';

class ActivityCard extends StatefulWidget {
  final ActivityModel activity;
  final bool isCompact;
  final double? width;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool? isFavorite; // Changed to nullable

  const ActivityCard({
    super.key,
    required this.activity,
    this.isCompact = false,
    this.width,
    this.onTap,
    this.onFavorite,
    this.isFavorite,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Seed the provider with the initial state if it's the first time seeing this activity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<BookmarkProvider>(context, listen: false);
        // If we have an explicit isFavorite, use it to seed
        if (widget.isFavorite != null) {
          provider.updateActivityState(widget.activity.id, widget.isFavorite!);
        } else {
          provider.updateActivityState(widget.activity.id, widget.activity.isBookmarked);
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _toggleFavorite() {
    HapticFeedback.selectionClick();
    final provider = Provider.of<BookmarkProvider>(context, listen: false);
    provider.toggleActivityBookmark(widget.activity.id);
    widget.onFavorite?.call();
  }

  Widget _buildCardImage({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    final imageUrl = widget.activity.imageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty && imageUrl.toLowerCase() != 'null';

    return ClipRRect(
      borderRadius: borderRadius,
      child: hasImage
          ? Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: width,
                  height: height,
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4B63FF),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                width: width,
                height: height,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8E9EFF), Color(0xFFA5B4FC)],
                  ),
                ),
                child: const Icon(
                  Icons.broken_image_rounded,
                  size: 32,
                  color: Colors.white70,
                ),
              ),
            )
          : Container(
              width: width,
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8E9EFF), Color(0xFFA5B4FC)],
                ),
              ),
              child: const Icon(
                Icons.image_not_supported_rounded,
                size: 36,
                color: Colors.white70,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard();
    } else {
      return _buildFullCard();
    }
  }

  Widget _buildCompactCard() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: widget.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                     BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Expanded(
                      flex: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildCardImage(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          // Status Badge
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.activity.timelineStatus.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          // Favorite Button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _toggleFavorite,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Consumer<BookmarkProvider>(
                                  builder: (context, provider, child) {
                                    final isFavorite = provider.isActivityBookmarked(widget.activity.id);
                                    return Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? const Color(0xFFFF4757) : const Color(0xFF6C757D),
                                      size: 16,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          
                          // Price Badge
                          if (widget.activity.price != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B894),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '\$${widget.activity.price}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              widget.activity.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E225E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Location
                            Text(
                              widget.activity.location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6C757D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const Spacer(),
                            
                            // Rating and Duration
                            Row(
                              children: [
                                if (widget.activity.rating != null) ...[
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFFFA502),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.activity.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E225E),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (widget.activity.duration != null)
                                  Text(
                                    widget.activity.duration!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6C757D),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullCard() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Image
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildCardImage(
                            width: 120,
                            height: 120,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          ),
                          // Status Badge
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.activity.timelineStatus.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          // Price Badge
                          if (widget.activity.price != null)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B894),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '\$${widget.activity.price}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.activity.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E225E),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _toggleFavorite,
                                child: Consumer<BookmarkProvider>(
                                  builder: (context, provider, child) {
                                    final isFavorite = provider.isActivityBookmarked(widget.activity.id);
                                    return Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? const Color(0xFFFF4757) : const Color(0xFF6C757D),
                                      size: 20,
                                    );
                                  },
                                ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Location
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF6C757D),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.activity.location,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6C757D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Description
                            Expanded(
                              child: Text(
                                widget.activity.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6C757D),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Footer
                            Row(
                              children: [
                                if (widget.activity.rating != null) ...[
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFFFA502),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.activity.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E225E),
                                    ),
                                  ),
                                ],
                                
                                const Spacer(),
                                
                                // Duration
                                if (widget.activity.duration != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4B63FF).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.activity.duration!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4B63FF),
                                      ),
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
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.activity.timelineStatus.toUpperCase()) {
      case 'UPCOMING':
        return const Color(0xFF10B981); // Green
      case 'ONGOING':
        return const Color(0xFFF59E0B); // Orange
      case 'CANCELLED':
        return const Color(0xFFEF4444); // Red
      case 'COMPLETED':
        return const Color(0xFF6B7280); // Grey
      default:
        return const Color(0xFF6B7280);
    }
  }
}
