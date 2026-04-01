import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';

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
  bool _isSearching = false;
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
      if (mounted) {
        setState(() {
          _activeActivities = active;
          _archivedActivities = archived;
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
    List<ActivityModel> activities;
    // Ne garder que les activités actives
    activities = _activeActivities.where((a) => a.statut == 'active').toList();

    if (_searchQuery.isNotEmpty) {
      activities = activities
          .where(
            (a) =>
                a.titre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                a.lieu.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return activities;
  }

  List<String> get _tabs => [
    'Active (${_activeActivities.where((a) => a.statut == 'active').length})',
  ];

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isSearching) ...[
                    const Spacer(),
                    const Text(
                      'My Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ] else
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search an activity...',
                            border: InputBorder.none,
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: AppColors.textGrey,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 20,
                                color: AppColors.textGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),
                  if (!_isSearching)
                    GestureDetector(
                      onTap: () => setState(() => _isSearching = true),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
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
                            imageUrl: a.thumbnailUrl,
                            badge: a.statut.toUpperCase(),
                            badgeColor: a.statut == 'active'
                                ? const Color(0xFF22C55E)
                                : a.statut == 'brouillon'
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF6B7280),
                            title: a.titre,
                            spots:
                                '${a.nombreReservations}/${a.capaciteMax} places',
                            price: a.prixFormatted,
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
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
          );
          if (created == true) _loadActivities();
        },
        backgroundColor: AppColors.primary,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String imageUrl;
  final String badge;
  final Color badgeColor;
  final String title;
  final String spots;
  final String price;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.imageUrl,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.spots,
    required this.price,
    required this.onTap,
  });

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
                  tag: 'activity_img_$title',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 85,
                      height: 85,
                      child: Image.network(
                        imageUrl,
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
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
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
                    title,
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
                        spots,
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
                        price,
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
