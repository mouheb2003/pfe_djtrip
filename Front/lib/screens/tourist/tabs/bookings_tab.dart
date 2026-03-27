import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/inscription_model.dart';
import '../../../services/inscription_service.dart';
import '../booking_detail_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int _tabIndex = 0;
  List<InscriptionModel> _inscriptions = [];
  bool _isLoading = true;

  bool _isPending(InscriptionModel i) => i.statut == 'en_attente';

  bool _isConfirmed(InscriptionModel i) => i.statut == 'approuvee';

  @override
  void initState() {
    super.initState();
    _loadInscriptions();
  }

  Future<void> _loadInscriptions() async {
    try {
      final result = await InscriptionService.getMyInscriptions();
      if (mounted) {
        setState(() {
          _inscriptions = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  List<InscriptionModel> get _filteredInscriptions {
    switch (_tabIndex) {
      case 0:
        return _inscriptions.where(_isPending).toList();
      case 1:
        return _inscriptions.where(_isConfirmed).toList();
      case 2:
        return _inscriptions
            .where((i) => i.statut == 'refusee' || i.statut == 'annulee')
            .toList();
      default:
        return _inscriptions;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Reservations',
          style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Tab selector
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
                  _Tab(
                    label: 'Pending',
                    index: 0,
                    current: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                  _Tab(
                    label: 'Confirmed',
                    index: 1,
                    current: _tabIndex,
                    onTap: (i) => setState(() => _tabIndex = i),
                  ),
                  _Tab(
                    label: 'Cancelled',
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
                : _filteredInscriptions.isEmpty
                ? const Center(
                    child: Text(
                      'No reservations',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredInscriptions.length,
                    itemBuilder: (_, i) {
                      final ins = _filteredInscriptions[i];
                      final photos = ins.activite?['photos'];
                      final imageUrl = photos is List && photos.isNotEmpty
                          ? photos[0] as String
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BookingCard(
                          status: ins.statusLabel,
                          statusColor: ins.statusColor,
                          title:
                              ins.activite?['titre'] as String? ?? 'Activity',
                          date: _formatDate(ins.dateDemande),
                          imageUrl: imageUrl,
                          buttonLabel: 'Details',
                          primary: ins.statut == 'approuvee',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingDetailScreen(inscription: ins),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _Tab({
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
                color: isActive
                    ? AppColors.primary
                    : cs.onSurfaceVariant, // dark-mode safe
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final String status;
  final Color statusColor;
  final String title;
  final String date;
  final String imageUrl;
  final String buttonLabel;
  final bool primary;
  final VoidCallback onTap;

  const _BookingCard({
    required this.status,
    required this.statusColor,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.buttonLabel,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 13,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: primary
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: primary
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      buttonLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primary ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 128,
              height: 128,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: cs.surfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
