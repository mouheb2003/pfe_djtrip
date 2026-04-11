import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/review_queue_provider.dart';

/// Badge indicateur de reviews en attente
/// Peut être affiché sur différents écrans (home, bookings, etc.)
class ReviewBadge extends StatelessWidget {
  final Widget child;
  final Color badgeColor;
  final double badgeSize;
  final EdgeInsets? padding;
  final bool showZero;

  const ReviewBadge({
    super.key,
    required this.child,
    this.badgeColor = Colors.red,
    this.badgeSize = 18.0,
    this.padding,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewQueueProvider>(
      builder: (context, provider, _) {
        final count = provider.pendingCount;

        if (!showZero && count == 0) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: padding?.right ?? -8,
                top: padding?.top ?? -8,
                child: _buildBadge(count),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 6 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: count > 9 ? 10 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Widget de badge simplifié pour les icônes de navigation
class ReviewIconBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  const ReviewIconBadge({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ReviewBadge(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge horizontal pour les headers de navigation
class ReviewHeaderBadge extends StatelessWidget {
  final Widget child;
  final Alignment alignment;

  const ReviewHeaderBadge({
    super.key,
    required this.child,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return ReviewBadge(
      padding: const EdgeInsets.only(right: 0, top: 0),
      child: child,
    );
  }
}
