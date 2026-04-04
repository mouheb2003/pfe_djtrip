import 'package:flutter/material.dart';

import '../../../models/inscription_model.dart';
import '../../../services/inscription_service.dart';
import '../../../theme/app_theme.dart';
import '../../tourist/booking_detail_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _tabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<InscriptionModel>> _buckets = {
    'pending': [],
    'confirmed': [],
    'cancelled': [],
  };

  @override
  void initState() {
    super.initState();
    _loadInscriptions();
  }

  Future<void> _loadInscriptions() async {
    try {
      final result = await InscriptionService.getMyBookings();
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

  List<InscriptionModel> get _currentItems {
    switch (_tabIndex) {
      case 0:
        return _buckets['pending']!;
      case 1:
        return _buckets['confirmed']!;
      case 2:
        return _buckets['cancelled']!;
      default:
        return _buckets['pending']!;
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

  DateTime? _activityDate(InscriptionModel inscription) {
    final activity = inscription.activite ?? {};
    final raw = activity['date_debut'] ?? activity['dateDebut'];
    if (raw is String) return DateTime.tryParse(raw);
    return inscription.dateDemande;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${_monthName(date.month)} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:$minute ${isPm ? 'PM' : 'AM'}';
  }

  String _titleFor(InscriptionModel inscription) {
    final activity = inscription.activite ?? {};
    final title = (activity['titre'] as String?)?.trim() ?? '';
    return title.isNotEmpty ? title : 'Activity';
  }

  String _imageUrlFor(InscriptionModel inscription) {
    final activity = inscription.activite ?? {};
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

  void _openDetails(InscriptionModel inscription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(inscription: inscription),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInscriptions,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 8),
          _BookingsSegmentedControl(
            currentIndex: _tabIndex,
            onChanged: (value) => setState(() => _tabIndex = value),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4B4F73)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadInscriptions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_currentItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 70),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
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
                        Icons.event_busy_rounded,
                        size: 44,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No reservations',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._currentItems.map(
              (inscription) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BookingCard(
                  typeLabel: _typeFor(inscription),
                  status: inscription.statusLabel,
                  statusColor: inscription.statusColor,
                  title: _titleFor(inscription),
                  date: _formatDate(_activityDate(inscription)),
                  time: _formatTime(_activityDate(inscription)),
                  imageUrl: _imageUrlFor(inscription),
                  primary: inscription.statut == 'approuvee',
                  onTap: () => _openDetails(inscription),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingsSegmentedControl extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BookingsSegmentedControl({
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
          final label = ['Pending', 'Confirmed', 'Cancelled'][index];
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

class _BookingCard extends StatelessWidget {
  final String typeLabel;
  final String status;
  final Color statusColor;
  final String title;
  final String date;
  final String time;
  final String imageUrl;
  final bool primary;
  final VoidCallback onTap;

  const _BookingCard({
    required this.typeLabel,
    required this.status,
    required this.statusColor,
    required this.title,
    required this.date,
    required this.time,
    required this.imageUrl,
    required this.primary,
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
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.toUpperCase(),
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
                                  date.isNotEmpty ? date : 'Date not available',
                                  time.isNotEmpty ? time : 'Any time',
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
                            backgroundColor: primary
                                ? const Color(0xFF5D71FF)
                                : const Color(0xFF7487FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
