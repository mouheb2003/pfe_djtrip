import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/inscription_model.dart';
import '../../../services/inscription_service.dart';
import '../../../services/activity_service.dart';
import '../../../theme/app_theme.dart';
import '../../shared/chat_conversation_screen.dart';
import '../../shared/public_profile_screen.dart';
import '../../shared/activity_detail_screen.dart';
import '../booking_detail_screen.dart';
import '../verify_booking_screen.dart';

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

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'approved' || s == 'approuvee') return 'approved';
    if (s == 'pending' || s == 'en_attente') return 'pending';
    if (s == 'cancelled' || s == 'annulee') return 'cancelled';
    if (s == 'rejected' || s == 'refusee') return 'rejected';
    if (s == 'verified' || s == 'verifie') return 'verified';
    return s;
  }

  Future<void> _approveRequest(InscriptionModel item) async {
    try {
      setState(() => _isLoading = true);
      final success = await InscriptionService.approveReservation(item.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation approved successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectRequest(InscriptionModel item) async {
    final reason = await _showRejectionDialog();
    if (reason == null) return;

    try {
      setState(() => _isLoading = true);
      final success = await InscriptionService.rejectReservation(item.id,
          messageOrganisateur: reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation rejected successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showRejectionDialog() async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Reservation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncActivityPhotos(List<InscriptionModel> items) async {
    // Collect unique activity IDs missing photos
    final missingIds = <String>{};
    for (final item in items) {
      final activity = item.activite ?? {};
      final id = (activity['_id'] ?? activity['id'] ?? '').toString();
      if (id.isNotEmpty) {
        // If photos field doesn't look like a real list with URLs
        final rawPhotos =
            activity['photos'] ??
            activity['photos_activite'] ??
            activity['images'];
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
      if (_tabIndex == 0) return status == 'pending';
      if (_tabIndex == 1) return status == 'approved' || status == 'verified';
      if (_tabIndex == 2) return status == 'cancelled' || status == 'rejected';
      return false;
    }).toList();
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return 'Pending';
      case 1:
        return 'Confirmed';
      case 2:
        return 'Cancelled';
      default:
        return '';
    }
  }

  Color _tabColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF315CFF);
      case 1:
        return const Color(0xFF22C55E);
      case 2:
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _badgeText(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'pending') return 'PENDING';
    if (status == 'approved') return 'CONFIRMED';
    if (status == 'verified') return 'CHECKED IN';
    if (status == 'cancelled') return 'CANCELLED';
    if (status == 'rejected') return 'REJECTED';
    return status.toUpperCase();
  }

  Color _badgeColor(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'pending') return const Color(0xFFF59E0B);
    if (status == 'approved') return const Color(0xFF22C55E);
    if (status == 'verified') return const Color(0xFF315CFF);
    if (status == 'cancelled' || status == 'rejected') return const Color(0xFF94A3B8);
    return Colors.grey;
  }

  Color _borderColor(InscriptionModel item) {
    final status = _normalizeStatus(item.statut);
    if (status == 'pending') return const Color(0xFF315CFF);
    if (status == 'approved') return const Color(0xFF22C55E);
    if (status == 'verified') return const Color(0xFF315CFF);
    if (status == 'cancelled' || status == 'rejected') return const Color(0xFFCBD5E1);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final String todayLabel =
        "TODAY — ${DateFormat('d MMMM').format(DateTime.now()).toUpperCase()}";

    // Custom Header Logic per Tab
    String headerLabel = todayLabel;
    String headerTitle = "New Requests";

    if (_tabIndex == 0) {
      headerLabel = "PENDING BOOKINGS";
      headerTitle = "";
    } else if (_tabIndex == 1) {
      headerLabel = "CONFIRMED BOOKINGS";
      headerTitle = "";
    } else if (_tabIndex == 2) {
      headerLabel = "CANCELLATIONS";
      headerTitle = "Cancellation Requests";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Verify QR Codes',
              child: IconButton(
                icon: const Icon(Icons.qr_code_2, color: Color(0xFF315CFF)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerifyBookingScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
                          color: active
                              ? _tabColor(index)
                              : const Color(0xFFF1F4FF),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: _tabColor(index).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          _tabLabel(index),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : const Color(0xFF717BBC),
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
                          onApprove: () => _approveRequest(item),
                          onReject: () => _rejectRequest(item),
                          cachedPhotos:
                              _activityPhotosCache[(item.activite?['_id'] ??
                                      item.activite?['id'] ??
                                      '')
                                  .toString()],
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

  Map<String, dynamic> get _tourist => inscription.touriste ?? const {};

  String get _participantId {
    return (_tourist['_id'] ?? _tourist['id'] ?? '').toString().trim();
  }

  String get _participantName {
    return (_tourist['fullname'] ?? 'Unknown').toString();
  }

  String get _participantAvatar {
    return _tourist['avatar']?.toString() ?? '';
  }

  void _openParticipantProfile(BuildContext context) {
    final participantId = _participantId;
    if (participantId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: participantId),
      ),
    );
  }

  void _openBookingDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerBookingDetailScreen(inscription: inscription),
      ),
    );
  }

  void _openActivityDetails(BuildContext context) {
    final activity = inscription.activite ?? {};
    final activityId = activity['_id'] ?? activity['id'];
    if (activityId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activityId: activityId.toString()),
      ),
    );
  }

  static String _normalizeStatus(String status) {
    switch (status) {
      case 'approuvee':
      case 'approved':
      case 'confirmée':
        return 'approved';
      case 'verifie':
      case 'verified':
        return 'verified';
      case 'en_attente':
      case 'pending':
        return 'pending';
      case 'annulee':
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      case 'refusee':
      case 'rejected':
        return 'rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = inscription.statut.trim().toLowerCase();
    final norm = _normalizeStatus(status);

    if (norm == 'approved' || norm == 'verified') {
      return _buildApprovedCard(context);
    } else if (norm == 'cancelled' || norm == 'rejected') {
      return _buildCancelledCard(context);
    } else if (norm == 'pending') {
      return _buildPendingCard(context);
    } else {
      return _buildPendingCard(context);
    }
  }

  // ── PENDING CARD ────────────────────────────────────────────────────────────
  Widget _buildPendingCard(BuildContext context) {
    final activity = inscription.activite ?? const {};
    final avatar = _participantAvatar;
    final name = _participantName;
    final activityTitle = (activity['titre'] ?? 'Activity').toString();
    final nbParticipants = inscription.nombreParticipants ?? 1;

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String
        ? DateTime.tryParse(activityDateRaw)
        : null;
    final date = _formatDate(inscription.dateDemande ?? activityDate);

    return GestureDetector(
      onTap: () => _openBookingDetails(context),
      child: Container(
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
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Color(0xFF717BBC),
                                  size: 40,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Color(0xFF717BBC),
                                size: 40,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _openBookingDetails(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                              const Icon(
                                Icons.payment,
                                color: Color(0xFFF59E0B),
                                size: 16,
                              ),
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
                              _InfoChip(
                                icon: Icons.calendar_today_rounded,
                                label: date,
                              ),
                              _InfoChip(
                                icon: Icons.people_rounded,
                                label: '$nbParticipants Participants',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'APPROVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'REJECT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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
}
  // ── APPROVED CARD (WITH IMAGE CAROUSEL) ──────────────────────────────────
  Widget _buildApprovedCard(BuildContext context) {
    final activity = inscription.activite ?? const {};

    // Prioritize cached full activity photos
    final List<String> photos =
        cachedPhotos ??
        _extractImageUrls(
          activity['photos'] ??
              activity['photos_activite'] ??
              activity['images'],
        );

    final avatar = _participantAvatar;
    final name = _participantName;
    final activityTitle = (activity['titre'] ?? 'Activity').toString();
    final nbParticipants = inscription.nombreParticipants ?? 1;

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String
        ? DateTime.tryParse(activityDateRaw)
        : null;
    final date = _formatDate(activityDate);
    final time = (activity['heure_debut'] ?? '00:00').toString();

    return GestureDetector(
      onTap: () => _openBookingDetails(context),
      child: Container(
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: GestureDetector(
                  onTap: () => _openActivityDetails(context),
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: photos.isEmpty
                        ? Container(
                            color: const Color(0xFFF3F5FF),
                            child: const Icon(
                              Icons.image,
                              color: Color(0xFF717BBC),
                              size: 50,
                            ),
                          )
                        : _ActivityCarousel(photos: photos),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF22C55E),
                        size: 14,
                      ),
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
                    GestureDetector(
                      onTap: () => _openParticipantProfile(context),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF3F5FF),
                        backgroundImage: avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openBookingDetails(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B2452),
                                ),
                              ),
                              Text(
                                '$nbParticipants people',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF717BBC),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  activityTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B2452),
                  ),
                ),
                const SizedBox(height: 12),
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: '$date • $time',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  // ── CANCELLED CARD (IMAGE 2 IN SECOND REQUEST) ────────────────────────────
  Widget _buildCancelledCard(BuildContext context) {
    final isRejected = inscription.statut == 'rejected';
    final activity = inscription.activite ?? const {};
    final avatar = _participantAvatar;
    final name = _participantName;
    final activityTitle = (activity['titre'] ?? 'Activity').toString();

    final activityDateRaw = activity['date_debut'];
    final activityDate = activityDateRaw is DateTime
        ? activityDateRaw
        : activityDateRaw is String
        ? DateTime.tryParse(activityDateRaw)
        : null;
    final date = _formatDate(activityDate);

    final badgeColor = isRejected
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final textColor = isRejected
        ? const Color(0xFFE11D48)
        : const Color(0xFFD97706);
    final label = isRejected ? 'REJECTED' : 'CANCELLED';
    final footerText = isRejected ? 'Rejected by you' : 'Cancelled by traveler';

    return GestureDetector(
      onTap: () => _openBookingDetails(context),
      child: Container(
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
                  GestureDetector(
                    onTap: () => _openParticipantProfile(context),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFF3F5FF),
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person, size: 24)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openBookingDetails(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B2452),
                              ),
                            ),
                          const Text(
                            'PREMIUM TRAVELER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF717BBC),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2452),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Color(0xFF717BBC),
                ),
                const SizedBox(width: 10),
                Text(
                  'On $date',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF717BBC),
                    fontWeight: FontWeight.w500,
                  ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF717BBC),
                  ),
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
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
              child: const Icon(
                Icons.broken_image,
                color: Color(0xFF717BBC),
                size: 50,
              ),
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
                    color: _currentPage == idx
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
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
