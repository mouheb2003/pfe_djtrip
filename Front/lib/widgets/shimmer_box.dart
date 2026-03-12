import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shimmer / skeleton placeholder for loading states.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                AppColors.outline.withOpacity(0.3),
                AppColors.outline.withOpacity(0.6),
                AppColors.outline.withOpacity(0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for an activity card in list.
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: double.infinity, height: 180, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: MediaQuery.sizeOf(context).width * 0.6, height: 20, borderRadius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 120, height: 14, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a conversation list tile.
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const ShimmerBox(width: 48, height: 48, borderRadius: 24),
      title: ShimmerBox(width: 140, height: 16, borderRadius: 4),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ShimmerBox(width: 200, height: 12, borderRadius: 4),
      ),
    );
  }
}
