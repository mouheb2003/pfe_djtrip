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
      final active = await ActivityService.getMyActivities(refresh: refresh);
      debugPrint('Loaded ${active.length} my activities (refresh: $refresh)');

      if (mounted) {
        setState(() {
          _activeActivities = active;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text(
          'Are you sure you want to delete "${activity.titre}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final success = await ActivityService.deleteActivity(activity.id);

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
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search activity, place, type...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textGrey,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      const Text(
                        'My Activities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          widget.onOpenRequests?.call();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RequestsTab(),
                            ),
                          );
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.assignment_turned_in, size: 18),
                            if (widget.showRequestsDot)
                              const Positioned(
                                top: -2,
                                right: -4,
                                child: _RedDot(),
                              ),
                          ],
                        ),
                        label: const Text('Requests'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Search bar moved here (between title and active tab)
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
                          padding: const EdgeInsets.only(bottom: 12),
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
                                        ActivityDetailScreen(activityId: a.id),
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
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 278),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered over bottom nav (Network zone)
                Align(
                  alignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerifyBookingScreen(),
                          ),
                        );
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 22,
                            ),
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
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Hero(
                    tag: 'organizer_fab',
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
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
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final VoidCallback? onTap; // 🚀 NEW: Add main tap callback

  const _ActivityCard({
    required this.activity,
    required this.onEditTap,
    required this.onDeleteTap,
    this.onTap, // 🚀 NEW: Optional main tap
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
        return const Color(0xFF5D71FF); // blue
      case 'ONGOING':
        return const Color(0xFF22C55E); // green
      case 'PAST':
        return const Color(0xFF94A3B8); // grey
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
        ? '${durationHours}h ${durationMinutes}m'
        : '${durationMinutes}m';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image header - make it tappable
          GestureDetector(
            onTap: onTap, // 🚀 NEW: Handle main card tap on image
            child: AutoImageCarousel(
              imageUrls: activity.photos,
              aspectRatio: 16 / 9,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              fit: BoxFit.cover,
              showIndicators: activity.photos.length > 1,
              interval: const Duration(seconds: 3),
            ),
          ),
          // Content - make it tappable
          GestureDetector(
            onTap: onTap, // 🚀 NEW: Handle main card tap on content
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activity.titre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Status label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTimelineBadge().toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Booking status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Status',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$numReservations/$capacity places booked',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Duration and price row
                  Row(
                    children: [
                      // Duration
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            durationText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // Price
                      Text(
                        activity.prixFormatted,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ), // 🚀 FIX: Close the GestureDetector for content
          // Action buttons - separate from main tap area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Delete button
                InkWell(
                  onTap: onDeleteTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Modify button
                InkWell(
                  onTap: activity.timelineStatus == 'ONGOING'
                      ? null
                      : onEditTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activity.timelineStatus == 'ONGOING'
                          ? Colors.grey.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: activity.timelineStatus == 'ONGOING'
                          ? Colors.grey.shade400
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
