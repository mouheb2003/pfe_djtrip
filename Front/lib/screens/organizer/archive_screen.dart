import 'package:flutter/material.dart';
import '../../models/activite.dart';
import '../../models/user.dart';
import '../../models/organisator.dart';
import '../../services/activity_service.dart';
import '../../widgets/enhanced_activity_card.dart';
import '../../utils/notification_helper.dart';

class ArchiveScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onUserDataChanged;

  const ArchiveScreen({super.key, required this.user, this.onUserDataChanged});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Activite> _archivedActivities = [];
  List<Activite> _allActivities = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy = 'recent'; // recent, oldest, revenue, rating

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void didUpdateWidget(ArchiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when user data changes
    if (oldWidget.user != widget.user) {
      setState(() {});
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Load both archived and all activities
    final archivedResult = await ActivityService.getArchivedActivities();
    final allResult = await ActivityService.getMyActivities();

    if (!mounted) return;

    if (archivedResult['success'] && allResult['success']) {
      setState(() {
        _archivedActivities = archivedResult['activities'] as List<Activite>;
        _allActivities = allResult['activities'] as List<Activite>;
        _sortActivities();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = archivedResult['message'] ?? allResult['message'];
        _isLoading = false;
      });
    }
  }

  void _sortActivities() {
    switch (_sortBy) {
      case 'recent':
        _archivedActivities.sort((a, b) => b.dateFin.compareTo(a.dateFin));
        break;
      case 'oldest':
        _archivedActivities.sort((a, b) => a.dateFin.compareTo(b.dateFin));
        break;
      case 'revenue':
        _archivedActivities.sort((a, b) {
          final revenueA = a.prix * a.nombreReservations;
          final revenueB = b.prix * b.nombreReservations;
          return revenueB.compareTo(revenueA);
        });
        break;
      case 'rating':
        _archivedActivities.sort(
          (a, b) => b.noteMoyenne.compareTo(a.noteMoyenne),
        );
        break;
    }
  }

  Future<void> _deleteArchivedActivity(String activityId, String titre) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text(
          'Are you sure you want to delete "$titre"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final result = await ActivityService.deleteActivity(activityId);

      if (!mounted) return;

      if (result['success']) {
        NotificationHelper.showSuccess(
          context,
          'Activity deleted successfully',
        );
        _loadActivities();
        widget.onUserDataChanged?.call();
      } else {
        NotificationHelper.showError(context, result['message']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        color: Colors.grey[800],
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: Colors.grey[800],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Archive',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.grey[800]!, Colors.grey[700]!],
                    ),
                  ),
                ),
              ),
            ),

            // Statistics Summary
            if (!_isLoading && _archivedActivities.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[800]!, Colors.grey[700]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Statistiques de toutes vos activités (actives, terminées, futures)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Activities',
                              (widget.user as Organisator).listeActivites.length
                                  .toString(),
                              Icons.event,
                              Colors.blue,
                              subtitle: 'Créées',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Places',
                              // Combine archived + active activities for total count
                              ([
                                    ..._archivedActivities,
                                    ..._allActivities,
                                  ].fold<int>(
                                    0,
                                    (sum, a) => sum + a.nombreReservations,
                                  ))
                                  .toString(),
                              Icons.people,
                              Colors.green,
                              subtitle: 'Toutes activités',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Revenue',
                              // Combine archived + active activities for total revenue
                              '${([..._archivedActivities, ..._allActivities].fold<double>(0, (sum, a) => sum + (a.prix * a.nombreReservations))).toStringAsFixed(0)} DT',
                              Icons.attach_money,
                              Colors.orange,
                              subtitle: 'Toutes activités',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: () {
                              final allActivitiesCombined = [
                                ..._archivedActivities,
                                ..._allActivities,
                              ];
                              return _buildStatCard(
                                'Avg Rating',
                                (allActivitiesCombined.isEmpty
                                        ? 0.0
                                        : allActivitiesCombined.fold<double>(
                                                0,
                                                (sum, a) => sum + a.noteMoyenne,
                                              ) /
                                              allActivitiesCombined.length)
                                    .toStringAsFixed(1),
                                Icons.star,
                                Colors.amber,
                                subtitle: 'Toutes activités',
                              );
                            }(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Sort Dropdown
            if (!_isLoading && _archivedActivities.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_archivedActivities.length} archived activities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.sort, size: 20),
                          items: const [
                            DropdownMenuItem(
                              value: 'recent',
                              child: Text('Most Recent'),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text('Oldest'),
                            ),
                            DropdownMenuItem(
                              value: 'revenue',
                              child: Text('Highest Revenue'),
                            ),
                            DropdownMenuItem(
                              value: 'rating',
                              child: Text('Best Rating'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortBy = value;
                                _sortActivities();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadActivities,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_archivedActivities.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No archived activities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed activities will appear here',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final activity = _archivedActivities[index];
                    return EnhancedActivityCard(
                      activity: activity,
                      user: widget.user,
                      onUpdate: _loadActivities,
                      onDelete: () =>
                          _deleteArchivedActivity(activity.id, activity.titre),
                      isArchived: true, // Hide Edit button in archive
                    );
                  }, childCount: _archivedActivities.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchiveCard(Activite activity) {
    final revenue = activity.prix * activity.nombreReservations;
    final occupancyRate = activity.capaciteMax > 0
        ? (activity.nombreReservations / activity.capaciteMax) * 100
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Opacity(
        opacity: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header with Archived Badge
            Stack(
              children: [
                if (activity.photos.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.grey.withOpacity(0.3),
                        BlendMode.saturation,
                      ),
                      child: Image.network(
                        activity.photos.first,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.photo,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.archive, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Archived',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activity.titre,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // End Date
                  Row(
                    children: [
                      Icon(Icons.event_busy, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Ended: ${_formatDate(activity.dateFin)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(
                          'Places',
                          '${activity.nombreReservations}/${activity.capaciteMax}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildMetric(
                          'Revenue',
                          '${revenue.toStringAsFixed(0)} DT',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetric(
                          'Rating',
                          '${activity.noteMoyenne.toStringAsFixed(1)} (${activity.nombreAvis})',
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                      Expanded(
                        child: _buildMetric(
                          'Occupancy',
                          '${occupancyRate.toStringAsFixed(0)}%',
                          Icons.trending_up,
                          occupancyRate >= 80
                              ? Colors.green
                              : occupancyRate >= 50
                              ? Colors.orange
                              : Colors.red,
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

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
