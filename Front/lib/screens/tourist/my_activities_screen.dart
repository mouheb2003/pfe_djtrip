import 'package:flutter/material.dart';

import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../../theme/app_theme.dart';
import '../shared/activity_detail_screen.dart';
import 'bookings_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  int _tabIndex = 0; // 0 Upcoming, 1 Ongoing, 2 Past
  bool _isLoading = true;
  String? _errorMessage;
  List<InscriptionModel> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await InscriptionService.getMyInscriptions();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  DateTime _now() => DateTime.now();

  DateTime? _activityStart(InscriptionModel inscription) {
    final activity = inscription.activite ?? const {};
    final raw = activity['date_debut'] ?? activity['dateDebut'];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _activityEnd(InscriptionModel inscription) {
    final activity = inscription.activite ?? const {};
    final raw = activity['date_fin'] ?? activity['dateFin'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  DateTime? _displayActivityDate(InscriptionModel inscription) {
    return _activityStart(inscription) ?? inscription.dateDemande;
  }

  bool _isInProgress(InscriptionModel inscription) {
    if (inscription.statut != 'approuvee') return false;
    final start = _activityStart(inscription);
    final end = _activityEnd(inscription);
    final now = _now();

    if (start == null || end == null) return false;

    // Exact rule: start <= now < end
    return !now.isBefore(start) && now.isBefore(end);
  }

  List<InscriptionModel> get _upcoming {
    return _all.where((item) {
      if (item.statut == 'en_attente') return true;
      if (item.statut != 'approuvee') return false;
      if (_isInProgress(item)) return false;
      final start = _activityStart(item);
      if (start != null) return _now().isBefore(start);
      final end = _activityEnd(item);
      if (end != null) return _now().isBefore(end);
      // If approved but dates are missing, keep it visible in upcoming.
      return true;
    }).toList();
  }

  List<InscriptionModel> get _ongoing {
    return _all.where(_isInProgress).toList();
  }

  List<InscriptionModel> get _past {
    return _all.where((item) {
      if (item.statut != 'approuvee') return false;
      if (_isInProgress(item)) return false;
      final end = _activityEnd(item);
      if (end != null) return !_now().isBefore(end);
      final start = _activityStart(item);
      if (start != null) return !_now().isBefore(start);
      return false;
    }).toList();
  }

  List<InscriptionModel> get _currentItems {
    switch (_tabIndex) {
      case 0:
        return _upcoming;
      case 1:
        return _ongoing;
      case 2:
        return _past;
      default:
        return _upcoming;
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

  String _titleFor(InscriptionModel inscription) {
    final activity = inscription.activite ?? const {};
    final title = (activity['titre'] as String?)?.trim() ?? '';
    return title.isNotEmpty ? title : 'Activity';
  }

  String _imageUrlFor(InscriptionModel inscription) {
    final activity = inscription.activite ?? const {};
    final photos = activity['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return '';
  }

  String _typeFor(InscriptionModel inscription) {
    final activity = inscription.activite ?? const {};
    final raw =
        activity['type_activite'] ??
        activity['typeActivite'] ??
        activity['categorie'] ??
        activity['category'] ??
        activity['type'];
    final type = raw?.toString().trim() ?? '';
    if (type.isEmpty) return 'Activity';
    return type;
  }

  void _openActivity(InscriptionModel inscription) {
    final activityId = ((inscription.activite ?? const {})['_id'] ?? '')
        .toString();
    if (activityId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ActivityDetailScreen(activityId: activityId, viewOnly: true),
      ),
    );
  }

  String _buttonLabelForTab() {
    return _tabIndex == 2 ? 'View Details' : 'Book Now';
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
                  onTapActivity: _openActivity,
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                  titleFor: _titleFor,
                  imageUrlFor: _imageUrlFor,
                  typeFor: _typeFor,
                  activityDate: _displayActivityDate,
                  buttonLabel: _buttonLabelForTab(),
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
  final List<InscriptionModel> items;
  final Future<void> Function() onRefresh;
  final void Function(InscriptionModel) onTapActivity;
  final String Function(DateTime?) dateLabel;
  final String Function(DateTime?) timeLabel;
  final String Function(InscriptionModel) titleFor;
  final String Function(InscriptionModel) imageUrlFor;
  final String Function(InscriptionModel) typeFor;
  final DateTime? Function(InscriptionModel) activityDate;
  final String buttonLabel;

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
            dateText: [
              dateLabel(activityDate(hero)),
              timeLabel(activityDate(hero)),
            ].where((e) => e.isNotEmpty).join('  •  '),
            buttonLabel: buttonLabel,
            onTap: () => onTapActivity(hero),
          ),
          const SizedBox(height: 16),
          ...rest.map(
            (inscription) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ActivityCard(
                title: titleFor(inscription),
                imageUrl: imageUrlFor(inscription),
                typeLabel: typeFor(inscription),
                dateLabel: dateLabel(activityDate(inscription)),
                timeLabel: timeLabel(activityDate(inscription)),
                buttonLabel: buttonLabel,
                onTap: () => onTapActivity(inscription),
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
  final String dateText;
  final String buttonLabel;
  final VoidCallback onTap;

  const _FeaturedActivityCard({
    required this.title,
    required this.imageUrl,
    required this.typeLabel,
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
  final String dateLabel;
  final String timeLabel;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.imageUrl,
    required this.typeLabel,
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
