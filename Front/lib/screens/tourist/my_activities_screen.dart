import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../theme/app_theme.dart';
import '../shared/activity_detail_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  int _tabIndex = 0; // 0 Upcoming, 1 Ongoing, 2 Past
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<ActivityModel>> _buckets = {
    'upcoming': [],
    'ongoing': [],
    'past': [],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ActivityService.getActivitiesByTimeline();
      if (!mounted) return;
      setState(() {
        _buckets = result;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  DateTime? _displayActivityDate(ActivityModel activity) {
    return activity.dateDebut ?? DateTime.now();
  }

  List<ActivityModel> get _currentItems {
    switch (_tabIndex) {
      case 0:
        return _buckets['upcoming']!;
      case 1:
        return _buckets['ongoing']!;
      case 2:
        return _buckets['past']!;
      default:
        return _buckets['upcoming']!;
    }
  }

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

  String _typeFor(ActivityModel activity) {
    return activity.typeActivite.isNotEmpty ? activity.typeActivite : 'Event';
  }

  void _openDetails(ActivityModel activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activity: activity.toJson()),
      ),
    );
  }

  // Always show 'View Details' — the tourist already has a booking for these.
  String _buttonLabelForTab() => 'View Details';

  String _statusBadgeFor(ActivityModel activity) {
    switch (_tabIndex) {
      case 0: return 'Upcoming';
      case 1: return 'Ongoing';
      case 2: return 'Completed';
      default: return 'Active';
    }
  }

  Color _statusColorFor(ActivityModel activity) {
    switch (_tabIndex) {
      case 0: return const Color(0xFF5D71FF); // blue for upcoming
      case 1: return const Color(0xFF22C55E); // green for ongoing
      case 2: return const Color(0xFF94A3B8); // grey for completed
      default: return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _currentItems;

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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
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
                              fontSize: 30,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                  titleFor: _titleFor,
                  imageUrlFor: _imageUrlFor,
                  typeFor: _typeFor,
                  activityDate: _displayActivityDate,
                  buttonLabel: _buttonLabelForTab(),
                  statusBadgeFor: _statusBadgeFor,
                  statusColorFor: _statusColorFor,
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
        children: List.generate(3, (index) {
          final label = ['Upcoming', 'Ongoing', 'Past'][index];
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
  final String Function(DateTime?) dateLabel;
  final String Function(DateTime?) timeLabel;
  final String Function(ActivityModel) titleFor;
  final String Function(ActivityModel) imageUrlFor;
  final String Function(ActivityModel) typeFor;
  final DateTime? Function(ActivityModel) activityDate;
  final String buttonLabel;
  final String Function(ActivityModel) statusBadgeFor;
  final Color Function(ActivityModel) statusColorFor;

  const _ActivitiesFeed({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
    required this.onRefresh,
    required this.onTapActivity,
    required this.dateLabel,
    required this.timeLabel,
    required this.titleFor,
    required this.imageUrlFor,
    required this.typeFor,
    required this.activityDate,
    required this.buttonLabel,
    required this.statusBadgeFor,
    required this.statusColorFor,
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
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_off_rounded,
                    size: 44,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No activities yet',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final hero = items.first;
    final rest = items.skip(1).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _FeaturedActivityCard(
            title: titleFor(hero),
            imageUrl: imageUrlFor(hero),
            typeLabel: typeFor(hero),
            statusBadge: statusBadgeFor(hero),
            statusColor: statusColorFor(hero),
            dateText: [
              dateLabel(activityDate(hero)),
              timeLabel(activityDate(hero)),
            ].where((e) => e.isNotEmpty).join('  •  '),
            buttonLabel: buttonLabel,
            onTap: () => onTapActivity(hero),
          ),
          const SizedBox(height: 16),
          ...rest.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ActivityCard(
                title: titleFor(activity),
                imageUrl: imageUrlFor(activity),
                typeLabel: typeFor(activity),
                statusBadge: statusBadgeFor(activity),
                statusColor: statusColorFor(activity),
                dateLabel: dateLabel(activityDate(activity)),
                timeLabel: timeLabel(activityDate(activity)),
                buttonLabel: buttonLabel,
                onTap: () => onTapActivity(activity),
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
  final String typeLabel;
  final String statusBadge;
  final Color statusColor;
  final String dateText;
  final String buttonLabel;
  final VoidCallback onTap;

  const _FeaturedActivityCard({
    required this.title,
    required this.imageUrl,
    required this.typeLabel,
    required this.statusBadge,
    required this.statusColor,
    required this.dateText,
    required this.buttonLabel,
    required this.onTap,
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
              if (imageUrl.isNotEmpty)
                Image.network(imageUrl, fit: BoxFit.cover)
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F5A7A), Color(0xFF10163F)],
                    ),
                  ),
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
                          onPressed: onTap,
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

class _ActivityCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String typeLabel;
  final String statusBadge;
  final Color statusColor;
  final String dateLabel;
  final String timeLabel;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.imageUrl,
    required this.typeLabel,
    required this.statusBadge,
    required this.statusColor,
    required this.dateLabel,
    required this.timeLabel,
    required this.buttonLabel,
    required this.onTap,
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
              if (imageUrl.isNotEmpty)
                Image.network(imageUrl, fit: BoxFit.cover)
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F5A7A), Color(0xFF10163F)],
                    ),
                  ),
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
                          onPressed: onTap,
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
