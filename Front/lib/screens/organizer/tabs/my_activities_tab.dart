import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/api_client.dart';
import '../../shared/activity_detail_screen.dart';
import '../../notifications_screen.dart';
import '../create_activity_screen.dart';
import '../edit_activity_screen.dart';
import '../verify_booking_screen.dart';
import '../my_reservations_screen.dart';
import '../../shared/ai_chat_screen.dart';
import '../../../services/booking_service.dart';

class MyActivitiesTab extends StatefulWidget {
  const MyActivitiesTab({super.key});

  @override
  State<MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends State<MyActivitiesTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  List<ActivityModel> _activities = [];
  final Set<String> _selectedActivityIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _unreadNotificationCount = 0;
  int _pendingReservationsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadActivities();
    _loadUnreadCount();
    _fetchPendingCount();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
      if (_isSelectionMode) {
        setState(() {
          _isSelectionMode = false;
          _selectedActivityIds.clear();
        });
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedActivityIds.contains(id)) {
        _selectedActivityIds.remove(id);
        if (_selectedActivityIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedActivityIds.add(id);
        _isSelectionMode = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAll(List<ActivityModel> activities) {
    setState(() {
      if (_selectedActivityIds.length == activities.length) {
        _selectedActivityIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedActivityIds.clear();
        for (var a in activities) {
          _selectedActivityIds.add(a.id);
        }
        _isSelectionMode = true;
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _bulkAction() async {
    if (_selectedActivityIds.isEmpty) return;

    final selectedActivities = _activities.where((a) => _selectedActivityIds.contains(a.id)).toList();
    final isArchiveTab = _tabController.index == 3;
    final hasReservations = selectedActivities.any((a) => (a.nombreReservations ?? 0) > 0);

    String? reason;
    if (!isArchiveTab && hasReservations) {
      final reasonController = TextEditingController();
      String? inlineError;

      reason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Cancel Selected Activities?', style: TextStyle(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Some selected activities have active bookings. Please provide a cancellation reason for all participants.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 280,
                    decoration: InputDecoration(
                      hintText: 'Example: Activities cancelled due to logistical issues.',
                      errorText: inlineError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back', style: TextStyle(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    final r = reasonController.text.trim();
                    if (r.isEmpty) {
                      setDialogState(() => inlineError = 'Reason is required');
                      return;
                    }
                    Navigator.pop(ctx, r);
                  },
                  child: const Text('Confirm', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        ),
      );
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isArchiveTab ? 'Delete Selected?' : 'Cancel Selected?'),
          content: Text('Are you sure you want to ${isArchiveTab ? 'permanently delete' : 'cancel'} ${_selectedActivityIds.length} activities?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isArchiveTab ? 'Delete' : 'Cancel', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);
    
    int successCount = 0;
    for (var id in _selectedActivityIds) {
      final success = await ActivityService.deleteActivity(id, cancellationMessage: reason);
      if (success) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount activities processed successfully.'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      setState(() {
        _isSelectionMode = false;
        _selectedActivityIds.clear();
      });
      _loadActivities(refresh: true);
    }
  }

  Future<void> _loadActivities({bool refresh = false}) async {
    if (!mounted) return;
    
    setState(() {
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final allActivities = await ActivityService.getAllMyActivities(refresh: refresh);
      allActivities.sort((a, b) {
        final aTime = a.createdAt ?? a.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? b.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      
      if (!mounted) return;
      
      setState(() {
        _activities = allActivities;
        _isLoading = false;
        _isRefreshing = false;
      });
      _fetchPendingCount();
    } catch (e) {
      debugPrint('❌ Error loading activities: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load activities: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await NotificationService.getUnreadCount(cacheFirst: false);
      if (mounted) {
        setState(() {
          _unreadNotificationCount = result['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }
  
  Future<void> _fetchPendingCount() async {
    try {
      final count = await BookingService.getPendingBookingsCount();
      if (mounted) {
        setState(() {
          _pendingReservationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending count: $e');
    }
  }

  List<ActivityModel> get _activeActivities {
    return _activities.where((a) => a.isUpcoming).toList();
  }

  List<ActivityModel> get _ongoingActivities {
    return _activities.where((a) => a.isOngoing).toList();
  }

  List<ActivityModel> get _pastActivities {
    return _activities.where((a) => a.isPast).toList();
  }

  List<ActivityModel> _getFilteredActivities(List<ActivityModel> source) {
    if (_searchQuery.isEmpty) return source;
    
    final q = _searchQuery.toLowerCase();
    return source.where((a) {
      return a.titre.toLowerCase().contains(q) ||
             a.lieu.toLowerCase().contains(q) ||
             a.typeActivite.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final isArchive = activity.isPast || activity.statut == 'cancelled';
    final hasReservations = activity.nombreReservations != null && activity.nombreReservations! > 0;
    
    // If no reservations, show simple confirmation dialog
    if (!hasReservations || isArchive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isArchive ? 'Delete Activity?' : 'Cancel Activity?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            isArchive 
              ? 'Are you sure you want to delete "${activity.titre}" permanently? This action cannot be undone.'
              : 'Are you sure you want to cancel "${activity.titre}"? It will be moved to Archive.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                isArchive ? 'Delete' : 'Cancel',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
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
            SnackBar(
              content: Text(isArchive ? 'Activity deleted permanently.' : 'Activity cancelled successfully.'),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
          _loadActivities(refresh: true);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action failed.'),
              backgroundColor: Color(0xFFFF4757),
            ),
          );
        }
      }
      return;
    }
    
    // If there are reservations and not archive, show reason dialog for cancellation
    final reasonController = TextEditingController();
    String? inlineError;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Cancel Activity?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cancelling "${activity.titre}" will cancel all related bookings (${activity.nombreReservations}). Please provide a cancellation reason for tourists.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 280,
                  decoration: InputDecoration(
                    hintText: 'Example: Activity removed due to weather conditions.',
                    errorText: inlineError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Back',
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
                  'Confirm Cancellation',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
          const SnackBar(
            content: Text('Activity cancelled successfully.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadActivities(refresh: true);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel activity.'),
            backgroundColor: Color(0xFFFF4757),
          ),
        );
      }
    }
  }

  void _showActivityOptions(ActivityModel activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  activity.titre,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                _OptionTile(
                  icon: Icons.visibility_outlined,
                  title: 'View Details',
                  subtitle: 'See full activity information',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailScreen(
                          activityId: activity.id,
                          viewOnly: true,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _OptionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Activity',
                  subtitle: 'Modify activity details',
                  iconColor: AppColors.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditActivityScreen(activity: activity),
                      ),
                    );
                    if (updated == true) _loadActivities(refresh: true);
                  },
                ),
                const Divider(height: 1),
                _OptionTile(
                  icon: (activity.isUpcoming || activity.isOngoing) && activity.statut != 'cancelled' 
                    ? Icons.cancel_outlined 
                    : Icons.delete_outline,
                  title: (activity.isUpcoming || activity.isOngoing) && activity.statut != 'cancelled' 
                    ? 'Cancel Activity' 
                    : 'Delete Activity',
                  subtitle: (activity.isUpcoming || activity.isOngoing) && activity.statut != 'cancelled' 
                    ? 'Mark this activity as cancelled' 
                    : 'Remove this activity permanently',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteActivity(activity);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'UPCOMING':
        return const Color(0xFF22C55E); // Green
      case 'ONGOING':
        return const Color(0xFFF59E0B); // Orange
      case 'PAST':
        return const Color(0xFF94A3B8); // Grey
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDate(ActivityModel activity) {
    if (activity.dateDebut == null) return 'Date TBD';
    final date = activity.dateDebut!;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTabActivities = _getFilteredActivities(
      _tabController.index == 0 ? _activities :
      _tabController.index == 1 ? _activeActivities :
      _tabController.index == 2 ? _ongoingActivities : _pastActivities
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // Selection Mode App Bar
              if (_isSelectionMode)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    color: AppColors.primary.withOpacity(0.05),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _isSelectionMode = false;
                            _selectedActivityIds.clear();
                          }),
                        ),
                        Text(
                          '${_selectedActivityIds.length} Selected',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _selectAll(currentTabActivities),
                          child: Text(
                            _selectedActivityIds.length == currentTabActivities.length ? 'Unselect All' : 'Select All',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _tabController.index == 3 ? Icons.delete_outline : Icons.cancel_outlined,
                            color: Colors.red,
                          ),
                          onPressed: _bulkAction,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Normal App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'My Activities',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your created experiences',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification Icon
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationsScreen(),
                              ),
                            );
                            _loadUnreadCount();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                if (_unreadNotificationCount > 0)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Reservations Management Icon
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MyReservationsScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.list_alt_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                if (_pendingReservationsCount > 0)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$_pendingReservationsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              // Search Bar & QR Scanner
              if (!_isSelectionMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search activities...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF6B7280),
                                  size: 22,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Color(0xFF9CA3AF),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Verify Booking QR Button next to Search
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VerifyBookingScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF43B95B), Color(0xFF2E9D45)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E9D45).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Tab Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: const Color(0xFF6B7280),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.all(4),
                      tabs: [
                        _buildTab('All', _activities.length),
                        _buildTab('Upcoming', _activeActivities.length),
                        _buildTab('Ongoing', _ongoingActivities.length),
                        _buildTab('Past', _pastActivities.length),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildActivityList(_getFilteredActivities(_activities), 'all'),
              _buildActivityList(_getFilteredActivities(_activeActivities), 'active'),
              _buildActivityList(_getFilteredActivities(_ongoingActivities), 'ongoing'),
              _buildActivityList(_getFilteredActivities(_pastActivities), 'past'),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<ActivityModel> activities, String type) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (activities.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: () => _loadActivities(refresh: true),
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _MyActivityCard(
              activity: activity,
              formattedDate: _formatDate(activity),
              statusColor: _getStatusColor(activity.timelineStatus),
              isSelected: _selectedActivityIds.contains(activity.id),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(activity.id);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityDetailScreen(
                        activityId: activity.id,
                        viewOnly: true,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () => _toggleSelection(activity.id),
              onOptionsTap: () => _showActivityOptions(activity),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String title;
    String subtitle;
    IconData icon;

    switch (type) {
      case 'active':
        title = 'No Active Activities';
        subtitle = 'Create a new activity to get started';
        icon = Icons.event_available_outlined;
        break;
      case 'ongoing':
        title = 'No Ongoing Activities';
        subtitle = 'Activities happening now will appear here';
        icon = Icons.event_busy_outlined;
        break;
      case 'past':
        title = 'No Archived or Passed Activities Found';
        subtitle = 'Past activities will appear here';
        icon = Icons.history_outlined;
        break;
      default:
        title = 'No Activities';
        subtitle = 'Start by creating your first activity';
        icon = Icons.event_note_outlined;
    }

    return RefreshIndicator(
      onRefresh: () => _loadActivities(refresh: true),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2458),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try adjusting your search'
                        : subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  if (type == 'active' && _searchQuery.isEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateActivityScreen(),
                          ),
                        );
                        if (created == true) _loadActivities(refresh: true);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Activity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Transform.translate(
      offset: const Offset(25, 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI Chatbot Button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiChatScreen(),
                  ),
                );
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B63FF).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Create Activity FAB
            Hero(
              tag: 'organizer_fab',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateActivityScreen(),
                      ),
                    );
                    if (created == true) _loadActivities(refresh: true);
                  },
                  borderRadius: BorderRadius.circular(26),
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
    );
  }


}

// Modern Airbnb-style Activity Card with CRUD actions
class _MyActivityCard extends StatefulWidget {
  final ActivityModel activity;
  final String formattedDate;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onOptionsTap;
  final bool isSelected;

  const _MyActivityCard({
    required this.activity,
    required this.formattedDate,
    required this.statusColor,
    required this.onTap,
    this.onLongPress,
    required this.onOptionsTap,
    this.isSelected = false,
  });

  @override
  State<_MyActivityCard> createState() => _MyActivityCardState();
}

class _MyActivityCardState extends State<_MyActivityCard> {
  int _currentImageIndex = 0;

  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '')}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.activity.photos;
    final hasMultiplePhotos = photos.length > 1;
    final numReservations = widget.activity.nombreReservations;
    final capacity = widget.activity.capaciteMax;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: widget.isSelected 
              ? Border.all(color: AppColors.primary, width: 2) 
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected 
                  ? AppColors.primary.withOpacity(0.2) 
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Cover Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Stack(
                  children: [
                    // Image or Placeholder
                    // ... existing image code ...
                    photos.isEmpty
                        ? Container(
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount: photos.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final resolvedUrl = _resolveImageUrl(photos[index]);
                              return CachedNetworkImage(
                                imageUrl: resolvedUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFF9CA3AF),
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),

                    // Status Badge (Top Left)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.activity.statut == 'cancelled' 
                              ? Colors.red 
                              : widget.statusColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.activity.statut == 'cancelled' 
                              ? 'CANCELLED' 
                              : widget.activity.timelineStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Selection Indicator (Top Right Overlays)
                    if (widget.isSelected)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        ),
                      )
                    else
                      // Options Button (Top Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: widget.onOptionsTap,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Color(0xFF1B2458),
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                    // Photo Counter (if multiple photos) - Below options button
                    if (hasMultiplePhotos)
                      Positioned(
                        top: 12,
                        right: 50,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    // Page Indicators
                    if (hasMultiplePhotos)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            photos.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _currentImageIndex == index ? 20 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _currentImageIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.activity.titre,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2458),
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // Location & Date Row
                  Row(
                    children: [
                      // Location
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.activity.formattedLieu,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Date
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stats Row (Bookings & Price)
                  Row(
                    children: [
                      // Bookings Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.confirmation_num_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$numReservations/$capacity',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.activity.prixFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Rating
                      if (widget.activity.noteMoyenne > 0) ...[
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.activity.noteMoyenne.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2458),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${widget.activity.nombreAvis})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
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

// Option tile for bottom sheet
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textColor ?? const Color(0xFF1B2458),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
        ),
      ),
      onTap: onTap,
    );
  }
}
