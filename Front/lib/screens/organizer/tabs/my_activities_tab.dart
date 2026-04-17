import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../widgets/auto_image_carousel.dart';
import 'requests_tab.dart';
import '../../shared/activity_detail_screen.dart';
import '../verify_booking_screen.dart';
import '../create_activity_screen.dart';
import '../edit_activity_screen.dart';
import '../../notifications_screen.dart';

class MyActivitiesTab extends StatefulWidget {
  final bool showRequestsDot;
  final VoidCallback? onOpenRequests;

  const MyActivitiesTab({
    super.key,
    this.showRequestsDot = false,
    this.onOpenRequests,
  });

  @override
  State<MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends State<MyActivitiesTab> {
  List<ActivityModel> _activeActivities = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities({bool refresh = false}) async {
    try {
      final allActivities = await ActivityService.getAllMyActivities(refresh: refresh);
      debugPrint('Loaded ${allActivities.length} all my activities (refresh: $refresh)');

      if (mounted) {
        setState(() {
          _activeActivities = allActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh activities: $e')),
        );
      }
    }
  }

  List<String> get _tabs => ['Active (${_activeActivities.length})'];

  List<ActivityModel> get _currentActivities {
    return _activeActivitiesFiltered;
  }

  List<ActivityModel> get _activeActivitiesFiltered {
    List<ActivityModel> activities = _activeActivities;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      activities = activities
          .where(
            (a) =>
                a.titre.toLowerCase().contains(q) ||
                a.lieu.toLowerCase().contains(q) ||
                a.typeActivite.toLowerCase().contains(q) ||
                a.categorie.toLowerCase().contains(q),
          )
          .toList();
    }
    return activities;
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final reasonController = TextEditingController();
    String? inlineError;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete Activity?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deleting "${activity.titre}" will cancel all related bookings. Please provide a cancellation reason for tourists.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 280,
                  decoration: InputDecoration(
                    hintText:
                        'Example: Activity removed due to weather conditions.',
                    errorText: inlineError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(() {
                      inlineError = 'Reason is required';
                    });
                    return;
                  }
                  Navigator.pop(ctx, reason);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ActivityService.deleteActivity(
      activity.id,
      cancellationMessage: reason.trim(),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity deleted successfully.')),
        );
        _loadActivities(refresh: true);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete activity.')),
        );
      }
    }
  }

  Widget _buildBottomSearchDock() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search activities...',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activities',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Row(
                    children: [
                      // Notification icon
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              if (false) // TODO: Replace with actual unread count check
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '3',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onOpenRequests?.call();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RequestsTab(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Requests',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.showRequestsDot)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBottomSearchDock(),
            ),
            const SizedBox(height: 8),
            // Filter tabs
            Container(
              padding: const EdgeInsets.only(left: 16, top: 12),
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                itemBuilder: (ctx, i) {
                  const active = true;
                  return GestureDetector(
                    onTap: () {}, // Single tab, no action needed
                    child: Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _tabs[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                              ),
                            ),
                          ),
                          Container(
                            height: 2,
                            width: 60,
                            color: active
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Activity list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadActivities(refresh: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_currentActivities.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey[200],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No results for "$_searchQuery"'
                                    : 'No activities',
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._currentActivities.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ActivityCard(
                            activity: a,
                            onTap: () {
                              // 🚀 Navigate to detailed activity screen
                              print(
                                '🚀 [DEBUG] Activity card tapped: ${a.id} - ${a.titre}',
                              );

                              // Validate activity ID
                              if (a.id == null || a.id.isEmpty) {
                                print('❌ [DEBUG] Invalid activity ID');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID d\'activité invalide'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              try {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ActivityDetailScreen(
                                          activityId: a.id,
                                          viewOnly: true,
                                        ),
                                  ),
                                );
                              } catch (e) {
                                print('❌ [DEBUG] Navigation error: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur de navigation: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            onEditTap: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditActivityScreen(activity: a),
                                ),
                              );
                              if (updated == true)
                                _loadActivities(refresh: true);
                            },
                            onDeleteTap: () => _deleteActivity(a),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    if (_searchQuery.isEmpty)
                      Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_note,
                              size: 40,
                              color: AppColors.primary.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Planning more outings?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Boost your visibility by creating new experiences.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 2, right: 2),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          child: Row(
            children: [
              const Spacer(),
              Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerifyBookingScreen(),
                      ),
                    );
                  },
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF43B95B), Color(0xFF2E9D45)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E9D45).withOpacity(0.38),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Verify Booking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Hero(
                tag: 'organizer_fab',
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateActivityScreen(),
                        ),
                      );
                      if (created == true) _loadActivities(refresh: true);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.activity,
    required this.onEditTap,
    required this.onDeleteTap,
    this.onTap,
  });

  String _getTimelineBadge() {
    final status = activity.timelineStatus;
    switch (status) {
      case 'UPCOMING':
        return 'UPCOMING';
      case 'ONGOING':
        return 'ONGOING';
      case 'PAST':
        return 'COMPLETED';
      default:
        return activity.statut.toUpperCase();
    }
  }

  Color _getTimelineBadgeColor() {
    final status = activity.timelineStatus;
    switch (status) {
      case 'UPCOMING':
        return const Color(0xFF5D71FF);
      case 'ONGOING':
        return const Color(0xFF22C55E);
      case 'PAST':
        return const Color(0xFF94A3B8);
      default:
        return activity.statut == 'active'
            ? const Color(0xFF22C55E)
            : activity.statut == 'brouillon'
            ? const Color(0xFF94A3B8)
            : const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final numReservations = activity.nombreReservations;
    final capacity = activity.capaciteMax;
    final statusColor = _getTimelineBadgeColor();
    final durationHours = activity.duree ~/ 60;
    final durationMinutes = activity.duree % 60;
    final durationText = durationHours > 0
        ? '${durationHours}H ${durationMinutes}H'
        : '${durationMinutes}H';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Image with status badge
            GestureDetector(
              onTap: onTap,
              child: Stack(
                children: [
                  // Image carousel
                  AutoImageCarousel(
                    imageUrls: activity.photos,
                    aspectRatio: 16 / 9,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    fit: BoxFit.cover,
                    showIndicators: activity.photos.length > 1,
                    interval: const Duration(seconds: 3),
                  ),
                  // Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getTimelineBadge(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.confirmation_num_rounded,
                              size: 12,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$numReservations/$capacity PLACES BOOKED',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: activity.timelineStatus == 'ONGOING'
                            ? null
                            : onEditTap,
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: activity.timelineStatus == 'ONGOING'
                              ? Colors.grey.shade400
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: onDeleteTap,
                        child: const Icon(
                          Icons.delete_rounded,
                          size: 18,
                          color: Color(0xFFDC2248),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    activity.titre,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E225E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Description (if available)
                  if ((activity.description ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        activity.description ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Duration and price
                  Row(
                    children: [
                      // Duration
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            durationText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Price
                      Text(
                        activity.prixFormatted,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Reviews and Rating section (show for completed activities)
                  if (activity.timelineStatus == 'PAST' || activity.statut == 'completed')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E9F7)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber[600],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activity.noteMoyenne > 0
                                ? '${activity.noteMoyenne.toStringAsFixed(1)} (${activity.nombreAvis} review${activity.nombreAvis == 1 ? '' : 's'})'
                                : 'No reviews yet',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.rate_review,
                            color: const Color(0xFF4B63FF),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View Reviews',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B63FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
