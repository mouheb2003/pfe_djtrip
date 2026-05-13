import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/activity_service.dart';
import '../../services/inscription_service.dart';
import '../../theme/app_theme.dart';
import 'booking_detail_screen.dart';
import '../shared/activity_detail_screen.dart';
import 'booking_selection_screen.dart';
import 'bookings_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  int _tabIndex = 0; // 0 All, 1 Upcoming, 2 Ongoing, 3 Past
  bool _isLoading = true;
  String? _errorMessage;
<<<<<<< HEAD
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
=======
  String _searchQuery = '';
  late TextEditingController _searchController;
>>>>>>> 0a1c8878fc3e1c950514c5997940ad7019f78f8a
  Map<String, List<ActivityModel>> _buckets = {
    'all': [],
    'upcoming': [],
    'ongoing': [],
    'past': [],
  };
  Map<String, String> _bookingStatusByActivityId = {};
  Map<String, InscriptionModel> _latestBookingByActivityId = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ActivityModel> _sortMostRecentFirst(List<ActivityModel> items) {
    final sorted = List<ActivityModel>.from(items);
    sorted.sort((a, b) {
      final dateA = _displayActivityDate(a);
      final dateB = _displayActivityDate(b);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      // Full DateTime compare keeps second/millisecond precision.
      return dateB.compareTo(dateA);
    });
    return sorted;
  }

  Map<String, List<ActivityModel>> _buildUniqueBuckets(
    Map<String, List<ActivityModel>> source,
  ) {
    final uniqueById = <String, ActivityModel>{};

    for (final activity in [
      ...?source['upcoming'],
      ...?source['ongoing'],
      ...?source['past'],
    ]) {
      if (activity.id.isEmpty) continue;
      uniqueById[activity.id] = activity;
    }

    final upcoming = <ActivityModel>[];
    final ongoing = <ActivityModel>[];
    final past = <ActivityModel>[];

    // Reclassify each unique activity into exactly one bucket.
    for (final activity in uniqueById.values) {
      switch (activity.timelineStatus) {
        case 'UPCOMING':
          upcoming.add(activity);
          break;
        case 'ONGOING':
          ongoing.add(activity);
          break;
        case 'PAST':
          past.add(activity);
          break;
        default:
          // Keep unknown dates out of timeline tabs.
          break;
      }
    }

    return {
      'all': _sortMostRecentFirst(uniqueById.values.toList()),
      'upcoming': _sortMostRecentFirst(upcoming),
      'ongoing': _sortMostRecentFirst(ongoing),
      'past': _sortMostRecentFirst(past),
    };
  }

  Future<void> _load() async {
    try {
      print('DEBUG: Loading activities timeline...');
      final results = await Future.wait([
        ActivityService.getActivitiesByTimeline(),
        InscriptionService.getMyBookings(),
      ]);

      final result = results[0] as Map<String, List<ActivityModel>>;
      final bookings = results[1] as Map<String, List<InscriptionModel>>;
      if (!mounted) return;

      final filteredResult = _buildUniqueBuckets(result);
      final bookingStatus = _buildBookingStatusMap(bookings);

      print(
        'DEBUG: Activity timeline filtered. Counts: '
        'All=${filteredResult['all']?.length}, '
        'Upcoming=${filteredResult['upcoming']?.length}, '
        'Ongoing=${filteredResult['ongoing']?.length}, '
        'Past=${filteredResult['past']?.length}',
      );
      setState(() {
        _buckets = filteredResult;
        _bookingStatusByActivityId = bookingStatus;
        _latestBookingByActivityId = _buildLatestBookingMap(bookings);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      print('DEBUG: Error loading activities: $e');
      if (!mounted) return;
      final rawMessage = e.toString().replaceAll('Exception: ', '').trim();
      final safeMessage =
          rawMessage.startsWith('{') || rawMessage.startsWith('[')
          ? 'Unable to refresh activities. Please try again.'
          : (rawMessage.isEmpty
                ? 'Unable to refresh activities. Please try again.'
                : rawMessage);
      setState(() {
        _isLoading = false;
        _errorMessage = safeMessage;
      });
    }
  }

  bool _matchesSearch(ActivityModel activity) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final values = <String>[
      activity.titre,
      activity.description,
      activity.lieu,
      activity.categorie,
      activity.typeActivite,
      activity.formattedLieu,
    ];

    return values.any((value) => value.toLowerCase().contains(query));
  }

  int _searchRank(ActivityModel activity) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return 0;

    final title = activity.titre.toLowerCase();
    if (title.contains(query)) return 0;

    final otherFields = <String>[
      activity.description,
      activity.lieu,
      activity.categorie,
      activity.typeActivite,
      activity.formattedLieu,
    ];

    if (otherFields.any((value) => value.toLowerCase().contains(query))) {
      return 1;
    }

    return 2;
  }

  List<ActivityModel> _activitiesForCurrentTab() {
    final items = switch (_tabIndex) {
      1 => _buckets['upcoming'] ?? const <ActivityModel>[],
      2 => _buckets['ongoing'] ?? const <ActivityModel>[],
      3 => _buckets['past'] ?? const <ActivityModel>[],
      _ => _buckets['all'] ?? const <ActivityModel>[],
    };

    final filtered = items.where(_matchesSearch).toList(growable: false);
    if (_searchQuery.trim().isEmpty) return filtered;

    filtered.sort((a, b) {
      final rankCompare = _searchRank(a).compareTo(_searchRank(b));
      if (rankCompare != 0) return rankCompare;
      final dateA =
          _displayActivityDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          _displayActivityDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  void _updateSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  DateTime? _displayActivityDate(ActivityModel activity) {
    return activity.dateDebut ?? DateTime.now();
  }

  Map<String, String> _buildBookingStatusMap(
    Map<String, List<InscriptionModel>> bookings,
  ) {
    final latestByActivityId = _buildLatestBookingMap(bookings);

    return latestByActivityId.map((key, value) {
      // Return the status even if cancelled so the button shows "Check reservation status"
      return MapEntry(key, value.statut);
    });
  }

  Map<String, InscriptionModel> _buildLatestBookingMap(
    Map<String, List<InscriptionModel>> bookings,
  ) {
    final latestByActivityId = <String, InscriptionModel>{};
    print(
      '🔍 [MY ACTIVITIES] Building booking map from: pending=${bookings['pending']?.length ?? 0}, confirmed=${bookings['confirmed']?.length ?? 0}, cancelled=${bookings['cancelled']?.length ?? 0}',
    );

    void collect(List<InscriptionModel> items, String bucket) {
      print(
        '🔍 [MY ACTIVITIES] Collecting from $bucket: ${items.length} items',
      );
      for (final item in items) {
        final activityId = (item.activite?['_id'] ?? '').toString();
        print(
          '🔍 [MY ACTIVITIES] $bucket item: ActivityID="$activityId", Inscription=${item.id}, Status=${item.statut}',
        );
        if (activityId.isEmpty) {
          print('🔍 [MY ACTIVITIES] Skipping: empty activity ID');
          continue;
        }

        final previous = latestByActivityId[activityId];
        final currentDate = item.dateDemande;
        final previousDate = previous?.dateDemande;

        if (previous == null) {
          latestByActivityId[activityId] = item;
          print(
            '🔍 [MY ACTIVITIES] Set first booking for activity $activityId',
          );
          continue;
        }

        if (currentDate == null && previousDate != null) continue;
        if (currentDate != null && previousDate == null) {
          latestByActivityId[activityId] = item;
          print(
            '🔍 [MY ACTIVITIES] Updated to newer booking for activity $activityId',
          );
          continue;
        }
        if (currentDate != null && previousDate != null) {
          if (currentDate.isAfter(previousDate)) {
            latestByActivityId[activityId] = item;
            print(
              '🔍 [MY ACTIVITIES] Updated to newer booking (by date) for activity $activityId',
            );
          }
        }
      }
    }

    collect(bookings['pending'] ?? const <InscriptionModel>[], 'pending');
    collect(bookings['confirmed'] ?? const <InscriptionModel>[], 'confirmed');
    collect(bookings['cancelled'] ?? const <InscriptionModel>[], 'cancelled');

    print(
      '✅ [MY ACTIVITIES] Final booking map has ${latestByActivityId.length} activities',
    );
    for (final entry in latestByActivityId.entries) {
      print(
        '  - Activity ${entry.key}: Booking ${entry.value.id} (Status: ${entry.value.statut})',
      );
    }
    return latestByActivityId;
  }

  int _bookingsTabIndexForStatus(String statut) {
    switch (statut) {
      case 'en_attente':
        return 0;
      case 'approuvee':
        return 1;
      case 'refusee':
      case 'annulee':
      default:
        return 2;
    }
  }

  String _buttonLabelFor(ActivityModel activity) {
    final status = _bookingStatusByActivityId[activity.id];
    if (status != null && status.isNotEmpty) {
      return 'Check reservation status';
    }
    return activity.isUpcoming ? 'Participate' : 'View Details';
  }

  void _onPrimaryAction(ActivityModel activity) {
    final status = _bookingStatusByActivityId[activity.id];
    if (status != null && status.isNotEmpty) {
      final booking = _latestBookingByActivityId[activity.id];
      if (booking == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(inscription: booking),
        ),
      );
      return;
    }
    if (activity.isUpcoming) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSelectionScreen(activity: activity),
        ),
      );
      return;
    }

    _openDetails(activity);
  }

<<<<<<< HEAD
=======
  List<ActivityModel> get _currentItems {
    final List<ActivityModel> allItems;
    switch (_tabIndex) {
      case 0:
        allItems = _buckets['upcoming'] ?? [];
        break;
      case 1:
        allItems = _buckets['ongoing'] ?? [];
        break;
      case 2:
        allItems = _buckets['past'] ?? [];
        break;
      default:
        allItems = _buckets['upcoming'] ?? [];
    }

    // Apply search filter
    if (_searchQuery.isEmpty) {
      return allItems;
    }

    return allItems.where((activity) {
      final titleMatches = activity.titre.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final locationMatches = activity.lieu.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return titleMatches || locationMatches;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

>>>>>>> 0a1c8878fc3e1c950514c5997940ad7019f78f8a
  String _monthName(int month) {
    const months = [
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
    return months[(month - 1).clamp(0, 11)];
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    return '${_monthName(date.month)} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:$minute ${isPm ? 'PM' : 'AM'}';
  }

  String _titleFor(ActivityModel activity) {
    return activity.titre.isNotEmpty ? activity.titre : 'Activity';
  }

  String _imageUrlFor(ActivityModel activity) {
    return activity.thumbnailUrl;
  }

  List<String> _imageUrlsFor(ActivityModel activity) {
    final urls = <String>[];
    if (activity.thumbnailUrl.isNotEmpty) {
      urls.add(activity.thumbnailUrl);
    }
    for (final photo in activity.photos) {
      final value = photo.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        urls.add(value);
      }
    }
    return urls.toSet().toList(growable: false);
  }

  String _typeFor(ActivityModel activity) {
    return activity.typeActivite.isNotEmpty ? activity.typeActivite : 'Event';
  }

  void _openDetails(ActivityModel activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activityId: activity.id,
          viewOnly: !activity.isUpcoming,
        ),
      ),
    );
  }

  String _statusBadgeFor(ActivityModel activity) {
    switch (activity.timelineStatus) {
      case 'UPCOMING':
        return 'Upcoming';
      case 'ONGOING':
        return 'Ongoing';
      case 'PAST':
        return 'Completed';
      default:
        return 'Active';
    }
  }

  Color _statusColorFor(ActivityModel activity) {
    switch (_tabIndex) {
      case 0:
        return const Color(0xFF5D71FF); // blue for upcoming
      case 1:
        return const Color(0xFF22C55E); // green for ongoing
      case 2:
        return const Color(0xFF94A3B8); // grey for completed
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _activitiesForCurrentTab();
    final hasFilters = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FE),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F5FF), Color(0xFFF1F0FD)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR JOURNEY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'My Activities',
                            style: TextStyle(
                              fontSize: 31,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F235F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _TopActionPill(
                      label: 'My Bookings',
                      icon: Icons.confirmation_num_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Search Bar
              Padding(
<<<<<<< HEAD
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: _updateSearch,
                  onClear: () {
                    _searchController.clear();
                    _updateSearch('');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
=======
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search activities, locations...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
>>>>>>> 0a1c8878fc3e1c950514c5997940ad7019f78f8a
                child: _ActivitiesSegmentedControl(
                  currentIndex: _tabIndex,
                  onChanged: (value) => setState(() => _tabIndex = value),
                ),
              ),
              Expanded(
                child: _ActivitiesFeed(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  items: items,
                  onRefresh: _load,
                  onTapActivity: _openDetails,
                  onPrimaryAction: _onPrimaryAction,
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                  titleFor: _titleFor,
                  imageUrlFor: _imageUrlFor,
                  imageUrlsFor: _imageUrlsFor,
                  typeFor: _typeFor,
                  activityDate: _displayActivityDate,
                  buttonLabelFor: _buttonLabelFor,
                  statusBadgeFor: _statusBadgeFor,
                  statusColorFor: _statusColorFor,
                  emptyTitle: hasFilters
                      ? 'No matching activities'
                      : 'No activities yet',
                  emptySubtitle: hasFilters
                      ? 'Try a different keyword or clear the search.'
                      : 'Your activities will appear here once they are available.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TopActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitiesSegmentedControl extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  static const List<String> _labels = ['All', 'Upcoming', 'Ongoing', 'Past'];

  const _ActivitiesSegmentedControl({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEAFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2DDFF)),
      ),
      child: Row(
        children: List.generate(_labels.length, (index) {
          final label = _labels[index];
          final active = currentIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 42,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primary
                          : const Color(0xFF696D8D),
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActivitiesFeed extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<ActivityModel> items;
  final Future<void> Function() onRefresh;
  final void Function(ActivityModel) onTapActivity;
  final void Function(ActivityModel) onPrimaryAction;
  final String Function(DateTime?) dateLabel;
  final String Function(DateTime?) timeLabel;
  final String Function(ActivityModel) titleFor;
  final String Function(ActivityModel) imageUrlFor;
  final List<String> Function(ActivityModel) imageUrlsFor;
  final String Function(ActivityModel) typeFor;
  final DateTime? Function(ActivityModel) activityDate;
  final String Function(ActivityModel) buttonLabelFor;
  final String Function(ActivityModel) statusBadgeFor;
  final Color Function(ActivityModel) statusColorFor;
  final String emptyTitle;
  final String emptySubtitle;

  const _ActivitiesFeed({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
    required this.onRefresh,
    required this.onTapActivity,
    required this.onPrimaryAction,
    required this.dateLabel,
    required this.timeLabel,
    required this.titleFor,
    required this.imageUrlFor,
    required this.imageUrlsFor,
    required this.typeFor,
    required this.activityDate,
    required this.buttonLabelFor,
    required this.statusBadgeFor,
    required this.statusColorFor,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4B4F73)),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.explore_off_rounded,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sortedItems = List<ActivityModel>.from(items)
      ..sort((a, b) {
        final dateA = activityDate(a);
        final dateB = activityDate(b);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

    final hero = sortedItems.first;
    final rest = sortedItems.skip(1).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _FeaturedActivityCard(
            title: titleFor(hero),
            imageUrl: imageUrlFor(hero),
            imageUrls: imageUrlsFor(hero),
            typeLabel: typeFor(hero),
            statusBadge: statusBadgeFor(hero),
            statusColor: statusColorFor(hero),
            dateText: [
              dateLabel(activityDate(hero)),
              timeLabel(activityDate(hero)),
            ].where((e) => e.isNotEmpty).join('  •  '),
            buttonLabel: buttonLabelFor(hero),
            onTap: () => onTapActivity(hero),
            onButtonTap: () => onPrimaryAction(hero),
          ),
          const SizedBox(height: 16),
          ...rest.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ActivityCard(
                title: titleFor(activity),
                imageUrl: imageUrlFor(activity),
                imageUrls: imageUrlsFor(activity),
                typeLabel: typeFor(activity),
                statusBadge: statusBadgeFor(activity),
                statusColor: statusColorFor(activity),
                dateLabel: dateLabel(activityDate(activity)),
                timeLabel: timeLabel(activityDate(activity)),
                buttonLabel: buttonLabelFor(activity),
                onTap: () => onTapActivity(activity),
                onButtonTap: () => onPrimaryAction(activity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedActivityCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final List<String> imageUrls;
  final String typeLabel;
  final String statusBadge;
  final Color statusColor;
  final String dateText;
  final String buttonLabel;
  final VoidCallback onTap;
  final VoidCallback onButtonTap;

  const _FeaturedActivityCard({
    required this.title,
    required this.imageUrl,
    required this.imageUrls,
    required this.typeLabel,
    required this.statusBadge,
    required this.statusColor,
    required this.dateText,
    required this.buttonLabel,
    required this.onTap,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CardImageCarousel(
                imageUrls: imageUrls,
                fallbackImageUrl: imageUrl,
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xD1000000), Color(0x2E000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF1FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            typeLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4352B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusBadge.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  height: 0.86,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dateText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: onButtonTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5D71FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            buttonLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              height: 1.0,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by title, location or category',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF5F678A),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF5F678A),
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _BadgeChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTopGlow extends StatelessWidget {
  const _CardTopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.18), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final List<String> imageUrls;
  final String typeLabel;
  final String statusBadge;
  final Color statusColor;
  final String dateLabel;
  final String timeLabel;
  final String buttonLabel;
  final VoidCallback onTap;
  final VoidCallback onButtonTap;

  const _ActivityCard({
    required this.title,
    required this.imageUrl,
    required this.imageUrls,
    required this.typeLabel,
    required this.statusBadge,
    required this.statusColor,
    required this.dateLabel,
    required this.timeLabel,
    required this.buttonLabel,
    required this.onTap,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CardImageCarousel(
                imageUrls: imageUrls,
                fallbackImageUrl: imageUrl,
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xD1000000), Color(0x2E000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF1FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            typeLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4352B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusBadge.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  height: 0.86,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                [
                                  dateLabel.isNotEmpty
                                      ? dateLabel
                                      : 'Date not available',
                                  timeLabel.isNotEmpty ? timeLabel : 'Any time',
                                ].join('  •  '),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: onButtonTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5D71FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            buttonLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              height: 1.0,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _CardImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String fallbackImageUrl;

  const _CardImageCarousel({
    required this.imageUrls,
    required this.fallbackImageUrl,
  });

  @override
  State<_CardImageCarousel> createState() => _CardImageCarouselState();
}

class _CardImageCarouselState extends State<_CardImageCarousel> {
  int _currentIndex = 0;
  late final PageController _pageController;
  Timer? _autoSlideTimer;

  List<String> get _images {
    final list = <String>[];
    if (widget.fallbackImageUrl.isNotEmpty) {
      list.add(widget.fallbackImageUrl);
    }
    list.addAll(widget.imageUrls);
    return list.toSet().toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restartAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _CardImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.imageUrls.length;
    final newCount = widget.imageUrls.length;
    if (oldCount != newCount ||
        oldWidget.fallbackImageUrl != widget.fallbackImageUrl) {
      _currentIndex = 0;
      _restartAutoSlide();
    }
  }

  void _restartAutoSlide() {
    _autoSlideTimer?.cancel();
    final count = _images.length;
    if (count <= 1) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F5A7A), Color(0xFF10163F)],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (_, index) {
            return Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F5A7A), Color(0xFF10163F)],
                  ),
                ),
              ),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
