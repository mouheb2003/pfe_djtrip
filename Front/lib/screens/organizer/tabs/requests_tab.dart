import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inscription_model.dart';
import '../../../services/inscription_service.dart';
import '../../../services/activity_service.dart';
import '../../../theme/app_theme.dart';

// ── IMAGE UTILITIES ────────────────────────────────────────────────────────
const List<String> _fallbackImages = [
  'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?q=80&w=1600&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1516549655169-df83a0774514?q=80&w=1600&auto=format&fit=crop',
];

List<String> _extractImageUrls(dynamic rawData) {
  if (rawData == null) return _fallbackImages;
  final List<String> extracted = [];
  final urlRegExp = RegExp(r'https?://[^"\\]+');

  // Convert List or String to a single search string
  String input = '';
  if (rawData is List) {
    input = rawData.join(' ');
  } else {
    input = rawData.toString();
  }

  if (input.isEmpty || input == '[]') return [];

  final matches = urlRegExp.allMatches(input);
  for (final m in matches) {
    final url = m.group(0)!.replaceAll('\\/', '/');
    if (url.contains('cloudinary') ||
        url.contains('.jpg') ||
        url.contains('.png') ||
        url.contains('.jpeg') ||
        url.contains('unsplash.com')) {
      extracted.add(url);
    }
  }

  if (extracted.isEmpty) return _fallbackImages;

  // If only 1 image, add a fallback to allow swiping (premium feel)
  if (extracted.length == 1) {
    extracted.add(_fallbackImages[1]);
  }

  return extracted;
}

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
  final Map<String, List<String>> _activityPhotosCache = {};

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
      // Trigger background photo sync
      _syncActivityPhotos(result);
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

  Future<void> _syncActivityPhotos(List<InscriptionModel> items) async {
    // Collect unique activity IDs missing photos
    final missingIds = <String>{};
    for (final item in items) {
      final activity = item.activite ?? {};
      final id = (activity['_id'] ?? activity['id'] ?? '').toString();
      if (id.isNotEmpty) {
        // If photos field doesn't look like a real list with URLs
        final rawPhotos = activity['photos'] ?? activity['photos_activite'] ?? activity['images'];
        final clean = _extractImageUrls(rawPhotos);
        // Only fetch if it returned fallback images (which means real photos were not found)
        if (clean == _fallbackImages) {
          missingIds.add(id);
        }
      }
    }

    if (missingIds.isEmpty) return;

    // Fetch in parallel
    for (final id in missingIds) {
      ActivityService.getActivityById(id).then((fullActivity) {
        if (fullActivity != null && fullActivity.photos.isNotEmpty && mounted) {
          setState(() {
            _activityPhotosCache[id] = fullActivity.photos;
          });
        }
      });
    }
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
    final String todayLabel = "TODAY — ${DateFormat('d MMMM').format(DateTime.now()).toUpperCase()}";
    
    // Custom Header Logic per Tab
    String headerLabel = todayLabel;
    String headerTitle = "New Requests";
    
    if (_tabIndex == 1) {
      headerLabel = "CONFIRMED REQUESTS";
      headerTitle = ""; // Empty as per user request to remove it
    } else if (_tabIndex == 2) {
      headerLabel = "CANCELLATIONS";
      headerTitle = "Cancellation Requests";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF315CFF)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Booking Requests',
          style: TextStyle(
            color: Color(0xFF315CFF),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Custom Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(3, (index) {
                  final active = index == _tabIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF315CFF) : const Color(0xFFF1F4FF),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF315CFF).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          _tabLabel(index),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : const Color(0xFF717BBC),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 28),
            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF717BBC),
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (headerTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      headerTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B2452),
                      ),
                    ),
                  ],
                  if (_tabIndex == 2) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Review past cancellations and rejections.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717BBC),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
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
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: _filteredRequests.length,
                              itemBuilder: (_, index) {
                                final item = _filteredRequests[index];
                                return _RequestCard(
                                  inscription: item,
                                  cachedPhotos: _activityPhotosCache[(item.activite?['_id'] ?? item.activite?['id'] ?? '').toString()],
                                  onApprove: _normalizeStatus(item.statut) == 'en_attente' ? () => _approve(item.id) : null,
                                  onReject: _normalizeStatus(item.statut) == 'en_attente' ? () => _reject(item.id) : null,
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
  final List<String>? cachedPhotos;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.inscription,
    this.cachedPhotos,
    this.onApprove,
    this.onReject,
  });

  String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
    return DateFormat('d MMM yyyy').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final status = inscription.statut.trim().toLowerCase();

    if (status == 'approuvee') {
      return _buildApprovedCard(context);
    } else if (status == 'annulee' || status == 'refusee') {
      return _buildCancelledCard(context);
    } else {
      return _buildPendingCard(context);
    }
  }

  // ── PENDING CARD (IMAGE 1 STYLE) ──────────────────────────────────────────
  Widget _buildPendingCard(BuildContext context) {
    final tourist = inscription.touriste ?? const {};
    final activity = inscription.activite ?? const {};
    final avatar = tourist['avatar']?.toString() ?? '';
    final name = (tourist['fullname'] ?? 'Unknown').toString();
    final activityTitle = (activity['titre'] ?? 'Activity').toString();
    final nbParticipants = inscription.nombreParticipants ?? 1;

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String ? DateTime.tryParse(activityDateRaw) : null;
    final date = _formatDate(inscription.dateDemande ?? activityDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 85,
                        height: 85,
                        color: const Color(0xFFF3F5FF),
                        child: avatar.isNotEmpty
                            ? Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF717BBC), size: 40),
                              )
                            : const Icon(Icons.person, color: Color(0xFF717BBC), size: 40),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9F2089),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text('NEW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
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
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B2452),
                              ),
                            ),
                          ),
                          const Icon(Icons.verified, color: Color(0xFF315CFF), size: 16),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activityTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF717BBC),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          _InfoChip(icon: Icons.calendar_today_rounded, label: date),
                          _InfoChip(icon: Icons.people_rounded, label: '$nbParticipants Participants'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFFEE2E2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF315CFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0xFF315CFF).withOpacity(0.5),
                    ),
                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── APPROVED CARD (WITH IMAGE CAROUSEL) ──────────────────────────────────
  Widget _buildApprovedCard(BuildContext context) {
    final tourist = inscription.touriste ?? const {};
    final activity = inscription.activite ?? const {};
    
    // Prioritize cached full activity photos
    final List<String> photos = cachedPhotos ?? _extractImageUrls(
      activity['photos'] ?? activity['photos_activite'] ?? activity['images']
    );

    final avatar = tourist['avatar']?.toString() ?? '';
    final name = (tourist['fullname'] ?? 'Unknown').toString();
    final activityTitle = (activity['titre'] ?? 'Activity').toString();
    final nbParticipants = inscription.nombreParticipants ?? 1;

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String ? DateTime.tryParse(activityDateRaw) : null;
    final date = _formatDate(activityDate);
    final time = (activity['heure_debut'] ?? '00:00').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Carousel
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: photos.isEmpty
                      ? Container(
                          color: const Color(0xFFF3F5FF),
                          child: const Icon(Icons.image, color: Color(0xFF717BBC), size: 50),
                        )
                      : _ActivityCarousel(photos: photos),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'CONFIRMED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF22C55E),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF3F5FF),
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? const Icon(Icons.person, size: 20) : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1B2452)),
                        ),
                        Text(
                          '$nbParticipants people',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF717BBC), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  activityTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B2452)),
                ),
                const SizedBox(height: 12),
                _InfoChip(icon: Icons.calendar_today_rounded, label: '$date • $time'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CANCELLED CARD (IMAGE 2 IN SECOND REQUEST) ────────────────────────────
  Widget _buildCancelledCard(BuildContext context) {
    final status = inscription.statut.trim().toLowerCase();
    final isRejected = status == 'refusee';
    final tourist = inscription.touriste ?? const {};
    final activity = inscription.activite ?? const {};
    final avatar = tourist['avatar']?.toString() ?? '';
    final name = (tourist['fullname'] ?? 'Unknown').toString();
    final activityTitle = (activity['titre'] ?? 'Activity').toString();

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String ? DateTime.tryParse(activityDateRaw) : null;
    final date = _formatDate(activityDate);

    final badgeColor = isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
    final textColor = isRejected ? const Color(0xFFE11D48) : const Color(0xFFD97706);
    final label = isRejected ? 'REJECTED' : 'CANCELLED';
    final footerText = isRejected ? 'Rejected by you' : 'Cancelled by traveler';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFF3F5FF),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty ? const Icon(Icons.person, size: 24) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1B2452)),
                      ),
                      const Text(
                        'PREMIUM TRAVELER',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF717BBC), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    activityTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2452)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF717BBC)),
                const SizedBox(width: 10),
                Text(
                  'On $date',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF717BBC), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  footerText,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF717BBC)),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF315CFF),
                  ),
                  child: const Row(
                    children: [
                      Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF315CFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
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

// ── CUSTOM CAROUSEL WIDGET ──────────────────────────────────────────────────
class _ActivityCarousel extends StatefulWidget {
  final List<String> photos;
  const _ActivityCarousel({required this.photos});

  @override
  State<_ActivityCarousel> createState() => _ActivityCarouselState();
}

class _ActivityCarouselState extends State<_ActivityCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (idx) => setState(() => _currentPage = idx),
          itemBuilder: (ctx, i) => Image.network(
            widget.photos[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF3F5FF),
              child: const Icon(Icons.broken_image, color: Color(0xFF717BBC), size: 50),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photos.length, (idx) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _currentPage == idx ? 20 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == idx ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
