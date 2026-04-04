import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import 'requests_tab.dart';

import '../create_activity_screen.dart';
import '../edit_activity_screen.dart';

class MyActivitiesTab extends StatefulWidget {
  const MyActivitiesTab({super.key});

  @override
  State<MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends State<MyActivitiesTab> {
  int _tabIndex = 0;
  List<ActivityModel> _activeActivities = [];
  List<ActivityModel> _archivedActivities = [];
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

  Future<void> _loadActivities() async {
    try {
      final active = await ActivityService.getMyActivities();
      final archived = await ActivityService.getArchivedActivities();

      // Apply client-side timeline filtering to ensure correctness
      final now = DateTime.now();
      final upcoming = <ActivityModel>[];
      final ongoing = <ActivityModel>[];
      final past = <ActivityModel>[];

      // Process active activities (should be upcoming/ongoing)
      for (final activity in active) {
        final status = activity.timelineStatus;
        if (status == 'UPCOMING') {
          upcoming.add(activity);
        } else if (status == 'ONGOING') {
          ongoing.add(activity);
        } else if (status == 'PAST') {
          past.add(activity);
        }
      }

      // Add archived activities to past
      past.addAll(archived);

      // Combine upcoming and ongoing as "active" for the organizer
      final combinedActive = <ActivityModel>[];
      combinedActive.addAll(upcoming);
      combinedActive.addAll(ongoing);

      if (mounted) {
        setState(() {
          _activeActivities = combinedActive;
          _archivedActivities = past;
          _isLoading = false;
        });
      }
    } catch (e) {
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

  List<ActivityModel> get _currentActivities {
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

  List<String> get _tabs => ['Active (${_activeActivities.length})'];

  Widget _buildBottomSearchDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: AppColors.primary, size: 20),
          ),
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
                hintText: 'Search activity, place, type...',
                border: InputBorder.none,
                isDense: true,
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
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'My Activities',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RequestsTab()),
                      );
                    },
                    icon: const Icon(Icons.assignment_turned_in, size: 18),
                    label: const Text('Requests'),
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
                  final active = i == _tabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _tabIndex = i),
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
                onRefresh: _loadActivities,
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
                            onTap: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditActivityScreen(activity: a),
                                ),
                              );
                              if (updated == true) _loadActivities();
                            },
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
      floatingActionButton: Hero(
        tag: 'organizer_fab',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
              );
              if (created == true) _loadActivities();
            },
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail with badge
            Stack(
              children: [
                Hero(
                  tag: 'activity_img_${activity.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 85,
                      height: 85,
                      child: Image.network(
                        activity.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getTimelineBadgeColor(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getTimelineBadge(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 14,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.nombreReservations}/${activity.capaciteMax} places',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activity.prixFormatted,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
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
