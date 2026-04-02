import 'package:flutter/material.dart';

import '../../../models/inscription_model.dart';
import '../../../services/inscription_service.dart';
import '../../../theme/app_theme.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  int _tabIndex = 0;
  List<InscriptionModel> _inscriptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await InscriptionService.getOrganizerAllRequests();
      if (!mounted) return;
      setState(() {
        _inscriptions = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String _normalizeStatus(String rawStatus) {
    final s = rawStatus.trim().toLowerCase();
    if (s == 'approved') return 'approuvee';
    if (s == 'pending') return 'en_attente';
    if (s == 'rejected') return 'refusee';
    if (s == 'cancelled' || s == 'canceled') return 'annulee';
    return s;
  }

  List<InscriptionModel> get _filteredRequests {
    return _inscriptions.where((item) {
      final status = _normalizeStatus(item.statut);
      if (_tabIndex == 0) return status == 'en_attente';
      if (_tabIndex == 1) return status == 'approuvee';
      if (_tabIndex == 2) return status == 'annulee' || status == 'refusee';
      return false;
    }).toList();
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return 'Pending';
      case 1:
        return 'Approved';
      default:
        return 'Cancelled';
    }
  }

  Color _tabColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF315CFF);
      case 1:
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _badgeText(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'en_attente') return 'PENDING';
    if (status == 'approuvee') return 'APPROVED';
    if (status == 'annulee') return 'CANCELLED';
    if (status == 'refusee') return 'REJECTED';
    return status.toUpperCase();
  }

  Color _badgeColor(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'en_attente') return const Color(0xFFF59E0B);
    if (status == 'approuvee') return const Color(0xFF22C55E);
    if (status == 'annulee') return const Color(0xFF94A3B8);
    return const Color(0xFFEF4444);
  }

  Color _borderColor(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'en_attente') return const Color(0xFF315CFF);
    if (status == 'approuvee') return const Color(0xFF22C55E);
    if (status == 'annulee') return const Color(0xFFCBD5E1);
    return const Color(0xFFEF4444);
  }

  Future<void> _approve(String id) async {
    final ok = await InscriptionService.approveInscription(id);
    if (ok && mounted) _loadRequests();
  }

  Future<void> _reject(String id) async {
    final ok = await InscriptionService.rejectInscription(id);
    if (ok && mounted) _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Text(
                    'DJTrip',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.message_rounded, color: cs.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.notifications_none_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Icon(Icons.person, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reservation Requests',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Manage participants and confirmations',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: List.generate(3, (index) {
                    final active = index == _tabIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Text(
                            _tabLabel(index),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: active
                                  ? _tabColor(index)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _RequestsErrorState(
                      message: _errorMessage!,
                      onRetry: _loadRequests,
                    )
                  : _filteredRequests.isEmpty
                  ? const _RequestsEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: _filteredRequests.length,
                      itemBuilder: (_, index) {
                        final item = _filteredRequests[index];
                        return _RequestCard(
                          inscription: item,
                          statusLabel: _badgeText(item),
                          statusColor: _badgeColor(item),
                          borderColor: _borderColor(item),
                          onApprove:
                              _normalizeStatus(item.statut) == 'en_attente'
                              ? () => _approve(item.id)
                              : null,
                          onReject:
                              _normalizeStatus(item.statut) == 'en_attente'
                              ? () => _reject(item.id)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final InscriptionModel inscription;
  final String statusLabel;
  final Color statusColor;
  final Color borderColor;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.inscription,
    required this.statusLabel,
    required this.statusColor,
    required this.borderColor,
    this.onApprove,
    this.onReject,
  });

  String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
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
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]}, ${value.year}';
  }

  String _timeRange(Map<String, dynamic>? activite) {
    final start = activite?['heure_debut']?.toString();
    final end = activite?['heure_fin']?.toString();
    if ((start ?? '').isEmpty && (end ?? '').isEmpty) return 'N/A';
    if ((end ?? '').isEmpty) return start ?? 'N/A';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final tourist = inscription.touriste ?? const {};
    final activity = inscription.activite ?? const {};
    final avatar = tourist['avatar']?.toString() ?? '';
    final name = (tourist['fullname'] ?? 'Unknown').toString();
    final activityTitle = (activity['titre'] ?? 'Activity').toString();
    final price = (activity['prix'] ?? inscription.prixTotal).toString();
    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String
        ? DateTime.tryParse(activityDateRaw)
        : null;
    final date = _formatDate(inscription.dateDemande ?? activityDate);
    final time = _timeRange(activity);
    final message = (inscription.messageTouriste ?? '').trim();

    final isPending = onApprove != null && onReject != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 74,
                        height: 74,
                        color: const Color(0xFFEDEFF5),
                        child: avatar.isNotEmpty
                            ? Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Color(0xFF64748B),
                                  size: 32,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Color(0xFF64748B),
                                size: 32,
                              ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          statusLabel == 'PENDING'
                              ? Icons.schedule_rounded
                              : statusLabel == 'APPROVED'
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF18213A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activityTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6A00),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: date,
                          ),
                          _InfoChip(
                            icon: Icons.access_time_rounded,
                            label: time,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$price TND',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF18213A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.grey.withOpacity(0.15), height: 1),
              const SizedBox(height: 14),
              Text(
                '"$message"',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF5C647A),
                  height: 1.35,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF315CFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF18213A),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 34,
                color: Color(0xFF315CFF),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No requests in this tab',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'When matching requests exist, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RequestsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 10),
            const Text(
              'Unable to load requests',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF315CFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
