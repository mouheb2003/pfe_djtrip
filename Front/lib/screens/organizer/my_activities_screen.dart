import 'package:flutter/material.dart';
import '../../models/activite.dart';
import '../../models/user.dart';
import '../../services/activity_service.dart';
import '../../utils/notification_helper.dart';
import '../activity_form_screen.dart';
import '../../widgets/enhanced_activity_card.dart';

class MyActivitiesScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onUserDataChanged;

  const MyActivitiesScreen({
    super.key,
    required this.user,
    this.onUserDataChanged,
  });

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  List<Activite> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy =
      'upcoming'; // upcoming, recent, revenue, rating, alphabetical

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ActivityService.getMyActivities();

    if (!mounted) return;

    if (result['success']) {
      final activities = result['activities'] as List<Activite>;
      print('📋 Loaded ${activities.length} activities');
      setState(() {
        _activities = activities;
        _sortActivities();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  void _sortActivities() {
    switch (_sortBy) {
      case 'upcoming':
        _activities.sort((a, b) => a.dateDebut.compareTo(b.dateDebut));
        break;
      case 'recent':
        _activities.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        break;
      case 'revenue':
        _activities.sort((a, b) {
          final revenueA = a.prix * a.nombreReservations;
          final revenueB = b.prix * b.nombreReservations;
          return revenueB.compareTo(revenueA);
        });
        break;
      case 'rating':
        _activities.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        break;
      case 'alphabetical':
        _activities.sort(
          (a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()),
        );
        break;
    }
  }

  Future<void> _handleActivityUpdate() async {
    await _loadActivities();
    widget.onUserDataChanged?.call();
  }

  Future<void> _deleteActivity(String activityId, String titre) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 40,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Delete Activity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Are you sure you want to delete "$titre"? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        color: const Color(0xFF2D5016),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: const Color(0xFF2D5016),
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'My Activities',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2D5016),
                        const Color(0xFF2D5016).withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sort Dropdown
            if (!_isLoading && _activities.isNotEmpty)
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
                        '${_activities.length} active activit${_activities.length > 1 ? "ies" : "y"}',
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
                              value: 'upcoming',
                              child: Text('Upcoming First'),
                            ),
                            DropdownMenuItem(
                              value: 'recent',
                              child: Text('Most Recent'),
                            ),
                            DropdownMenuItem(
                              value: 'revenue',
                              child: Text('Highest Revenue'),
                            ),
                            DropdownMenuItem(
                              value: 'rating',
                              child: Text('Best Rating'),
                            ),
                            DropdownMenuItem(
                              value: 'alphabetical',
                              child: Text('A-Z'),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2D5016),
                    ),
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
                          backgroundColor: const Color(0xFF2D5016),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_activities.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No activities yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first activity!',
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
                    final activity = _activities[index];
                    return EnhancedActivityCard(
                      activity: activity,
                      user: widget.user,
                      onUpdate: _handleActivityUpdate,
                      onDelete: () =>
                          _deleteActivity(activity.id, activity.titre),
                    );
                  }, childCount: _activities.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivityFormScreen(user: widget.user),
            ),
          );

          if (result == true) {
            _loadActivities();
            widget.onUserDataChanged?.call();
          }
        },
        backgroundColor: const Color(0xFFFF6B1A),
        icon: const Icon(Icons.add),
        label: const Text('New Activity'),
      ),
    );
  }

  Widget _buildActivityCard(Activite activity) {
    final now = DateTime.now();
    final isActive = activity.dateFin.isAfter(now);
    final daysLeft = activity.dateFin.difference(now).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ActivityFormScreen(user: widget.user, activity: activity),
            ),
          );

          if (result == true) {
            _loadActivities();
            widget.onUserDataChanged?.call();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            if (activity.photos.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  activity.photos.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.photo, size: 50, color: Colors.grey[400]),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.titre,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Ended',
                          style: TextStyle(
                            color: isActive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    activity.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Info Row
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.lieu,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      Text(
                        '${activity.prix.toStringAsFixed(0)} DT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF6B1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatChip(
                        Icons.people,
                        '${activity.nombreReservations}/${activity.capaciteMax}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        Icons.star,
                        activity.noteMoyenne.toStringAsFixed(1),
                        Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      if (isActive && daysLeft <= 7)
                        _buildStatChip(
                          Icons.access_time,
                          '$daysLeft days left',
                          Colors.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ActivityFormScreen(
                                  user: widget.user,
                                  activity: activity,
                                ),
                              ),
                            );

                            if (result == true) {
                              _loadActivities();
                              widget.onUserDataChanged?.call();
                            }
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D5016),
                            side: const BorderSide(color: Color(0xFF2D5016)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _deleteActivity(activity.id, activity.titre),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
