import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../shared/activity_detail_screen.dart';
import '../../widgets/review_bottom_sheet.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  int _tabIndex = 0;
  List<InscriptionModel> _all = [];
  bool _isLoading = true;

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _dateFromActivity(
    InscriptionModel i,
    String snakeKey,
    String camelKey,
  ) {
    final raw = i.activite?[snakeKey] ?? i.activite?[camelKey];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool _isInProgress(InscriptionModel i) {
    if (i.statut != 'approuvee') return false;
    final start = _dateFromActivity(i, 'date_debut', 'dateDebut');
    final end = _dateFromActivity(i, 'date_fin', 'dateFin');
    final today = _today();

    // If dates are missing, treat approved activities as ongoing by default.
    if (start == null && end == null) return true;

    final started = start == null || !today.isBefore(start);
    final notEnded = end == null || !today.isAfter(end);
    return started && notEnded;
  }

  List<InscriptionModel> get _upcoming => _all.where((i) {
    if (i.statut == 'en_attente') return true;
    if (i.statut != 'approuvee') return false;
    if (_isInProgress(i)) return false;
    final start = _dateFromActivity(i, 'date_debut', 'dateDebut');
    return start != null && _today().isBefore(start);
  }).toList();

  List<InscriptionModel> get _inProgress =>
      _all.where((i) => _isInProgress(i)).toList();

  List<InscriptionModel> get _past => _all.where((i) {
    if (i.statut != 'approuvee') return false;
    if (_isInProgress(i)) return false;
    final end = _dateFromActivity(i, 'date_fin', 'dateFin');
    return end != null && _today().isAfter(end);
  }).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceVariant,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Activities',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 31,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  _SegmentTab(
                    label: 'Upcoming',
                    index: 0,
                    current: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                  _SegmentTab(
                    label: 'Ongoing',
                    index: 1,
                    current: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                  _SegmentTab(
                    label: 'Past',
                    index: 2,
                    current: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tabIndex == 0
                ? _ActivityList(inscriptions: _upcoming, onRefresh: _load)
                : _tabIndex == 1
                ? _ActivityList(inscriptions: _inProgress, onRefresh: _load)
                : _ActivityList(inscriptions: _past, onRefresh: _load),
          ),
        ],
      ),
    );
  }
}

// ── List widget ──────────────────────────────────────────────────────────────

class _SegmentTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _SegmentTab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<InscriptionModel> inscriptions;
  final Future<void> Function() onRefresh;

  const _ActivityList({required this.inscriptions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (inscriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off, size: 48, color: AppColors.textGrey),
            SizedBox(height: 12),
            Text(
              'No activities yet',
              style: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: inscriptions.length,
        itemBuilder: (_, i) => _ActivityCard(
          inscription: inscriptions[i],
          isPast: inscriptions == (inscriptions.isNotEmpty ? inscriptions.first.statut == 'past' ? inscriptions : [] : []), // This is a bit complex, let's just pass a flag if needed or check statut
        ),
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final InscriptionModel inscription;
  final bool isPast;
  const _ActivityCard({required this.inscription, this.isPast = false});

  void _showReviewSheet(BuildContext context, String activityId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewBottomSheet(
        activiteId: activityId,
        activityTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final act = inscription.activite;
    final photos = act?['photos'] as List? ?? [];
    final imageUrl = photos.isNotEmpty ? photos.first as String : '';
    final title = act?['titre'] as String? ?? 'Activity';
    final prix = (act?['prix'] as num? ?? 0).toDouble();
    final rating = (act?['note_moyenne'] as num? ?? 0).toStringAsFixed(1);
    final activityId = act?['_id'] as String? ?? '';
    final d = inscription.dateDemande;
    final date = d != null ? '${_monthName(d.month)} ${d.day}, ${d.year}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          SizedBox(
            height: 180,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: cs.surfaceVariant),
                  )
                : Container(
                    color: cs.surfaceVariant,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: AppColors.primaryLight,
                      size: 48,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFBBF24),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                // Price + button
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${prix.toStringAsFixed(prix.truncateToDouble() == prix ? 0 : 2)} TND',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          const TextSpan(
                            text: ' / pers',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (inscription.statut == 'approuvee' && activityId.isNotEmpty)
                      ElevatedButton(
                        onPressed: () => _showReviewSheet(context, activityId, title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.surface,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Review',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: activityId.isNotEmpty
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityDetailScreen(
                                  activityId: activityId,
                                  viewOnly: true,
                                ),
                              ),
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
    );
  }

  String _monthName(int m) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m];
  }
}
