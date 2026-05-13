import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../shared/chat_conversation_screen.dart';
import '../shared/public_profile_screen.dart';
import 'bookings_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final InscriptionModel inscription;

  const BookingDetailScreen({super.key, required this.inscription});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late InscriptionModel _inscription;
  bool _isCancelling = false;
  Map<String, dynamic>? _fullOrganizerData;
  bool _isLoadingOrganizer = false;

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  List<String> _activityPhotoUrls(Map<String, dynamic>? activity) {
    final raw = activity?['photos'];
    if (raw is! List) return const [];

    final urls = <String>[];
    for (final item in raw) {
      final value = item?.toString().trim() ?? '';
      if (value.startsWith('http://') || value.startsWith('https://')) {
        urls.add(value);
      }
    }
    return urls.toSet().toList(growable: false);
  }

  Future<void> _openOrganizerChat({
    required String organizerId,
    required String organizerName,
    required String organizerAvatar,
  }) async {
    if (organizerId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organizer contact is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          partnerId: organizerId,
          partnerName: organizerName,
          partnerAvatar: organizerAvatar.isEmpty ? null : organizerAvatar,
          partnerType: 'Organisator',
        ),
      ),
    );
  }

  int _bookingsTabIndexForStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'en_attente':
        return 1;
      case 'approuvee':
        return 2;
      case 'annulee':
        return 3;
      case 'verifie':
        return 4;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _inscription = widget.inscription;
    _fetchOrganizerDataIfNeeded();
  }

  Future<void> _fetchOrganizerDataIfNeeded() async {
    final act = _inscription.activite ?? {};
    final orgaRaw =
        _inscription.organisateur ??
        (act['organisateur'] is Map
            ? Map<String, dynamic>.from(act['organisateur'] as Map)
            : null) ??
        (act['organisateur_id'] is Map
            ? Map<String, dynamic>.from(act['organisateur_id'] as Map)
            : null) ??
        const <String, dynamic>{};

    final organizerId = (orgaRaw['_id'] ?? orgaRaw['id'] ?? '')
        .toString()
        .trim();

    if (organizerId.isNotEmpty &&
        (orgaRaw['note_moyenne'] == null &&
                orgaRaw['noteMoyenne'] == null &&
                orgaRaw['rating'] == null ||
            orgaRaw['nombre_avis'] == null &&
                orgaRaw['nombreAvis'] == null &&
                orgaRaw['reviewsCount'] == null)) {
      setState(() => _isLoadingOrganizer = true);
      try {
        final fullData = await UserService.getUserById(organizerId);
        if (mounted && fullData != null) {
          setState(() => _fullOrganizerData = fullData);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingOrganizer = false);
        }
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Future<void> _cancelBooking() async {
    if (!_inscription.canBeCancelledWithTime) {
      final hoursRemaining = _inscription.hoursUntilCancellationDeadline;
      final message = hoursRemaining <= 0
          ? 'This reservation cannot be cancelled - the activity has already started or passed.'
          : 'This reservation cannot be cancelled.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Reservation'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Reservation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final success = await InscriptionService.cancelInscription(
        _inscription.id,
      );

      if (success) {
        setState(() {
          _inscription = InscriptionModel(
            id: _inscription.id,
            statut: 'annulee',
            nombreParticipants: _inscription.nombreParticipants,
            prixTotal: _inscription.prixTotal,
            dateDemande: _inscription.dateDemande,
            messageTouriste: _inscription.messageTouriste,
            activite: _inscription.activite,
            touriste: _inscription.touriste,
            organisateur: _inscription.organisateur,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel reservation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final act = _inscription.activite ?? {};
    final photoUrls = _activityPhotoUrls(act);
    final title = act['titre'] as String? ?? 'Activity';
    final lieu = act['lieu'] as String? ?? 'Location';
    final placeCount = _inscription.nombreParticipants;
    final unitPrice = (act['prix'] as num?)?.toDouble() ?? 0.0;
    final subtotal = unitPrice * placeCount;
    const serviceFee = 4.50;
    final total = subtotal + serviceFee;

    final orgaRaw =
        _fullOrganizerData ??
        _inscription.organisateur ??
        (act['organisateur'] is Map
            ? Map<String, dynamic>.from(act['organisateur'] as Map)
            : null) ??
        (act['organisateur_id'] is Map
            ? Map<String, dynamic>.from(act['organisateur_id'] as Map)
            : null) ??
        const <String, dynamic>{};
    final organizerId = (orgaRaw['_id'] ?? orgaRaw['id'] ?? '')
        .toString()
        .trim();
    final orgaName = (orgaRaw['fullname'] ?? orgaRaw['nom'] ?? 'Organizer')
        .toString();
    final orgaPhoto = (orgaRaw['avatar'] ?? orgaRaw['photoProfil'] ?? '')
        .toString();
    final orgaRating = _asDouble(
      orgaRaw['note_moyenne'] ??
          orgaRaw['noteMoyenne'] ??
          orgaRaw['rating'] ??
          orgaRaw['averageRating'] ??
          orgaRaw['avg_rating'] ??
          orgaRaw['avgRating'] ??
          orgaRaw['moyenne'] ??
          orgaRaw['average'],
    );
    final orgaReviews = _asInt(
      orgaRaw['nombre_avis'] ??
          orgaRaw['nombreAvis'] ??
          orgaRaw['reviewsCount'] ??
          orgaRaw['totalReviews'] ??
          orgaRaw['review_count'] ??
          orgaRaw['reviewCount'] ??
          orgaRaw['avis_count'] ??
          orgaRaw['avisCount'],
    );

    DateTime? activityDate;
    if (act['date_debut'] != null) {
      activityDate = DateTime.tryParse(act['date_debut'].toString());
    } else if (act['dateDebut'] != null) {
      activityDate = DateTime.tryParse(act['dateDebut'].toString());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Booking Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => BookingsScreen(
                  initialTabIndex: _bookingsTabIndexForStatus(
                    _inscription.statut,
                  ),
                ),
              ),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _inscription.statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _inscription.statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _inscription.isApproved
                          ? Icons.check
                          : _inscription.isPending
                          ? Icons.hourglass_top_rounded
                          : _inscription.isCancelled
                          ? Icons.info_outline_rounded
                          : Icons.verified_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _inscription.isApproved
                    ? 'Booking Confirmed!'
                    : _inscription.isPending
                    ? 'Waiting for approval'
                    : _inscription.isCancelled
                    ? 'Booking Cancelled'
                    : 'Booking Details',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B2452),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _inscription.isApproved
                    ? 'Your booking is approved. Keep your QR code for check-in.'
                    : _inscription.isPending
                    ? 'Your request has been sent. The organizer will review it soon.'
                    : _inscription.isCancelled
                    ? 'This booking was cancelled.'
                    : 'View your booking details',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: _BookingMediaPanel(
                    showQr: _inscription.isApproved,
                    hasQrData: _inscription.qrData.trim().isNotEmpty,
                    qrData: _inscription.qrData,
                    photoUrls: photoUrls,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Booking Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _inscription.statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _inscription.statusLabel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SummaryRow(
                      icon: Icons.surfing,
                      label: 'ACTIVITY',
                      value: title,
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(
                      icon: Icons.location_on_outlined,
                      label: 'LOCATION',
                      value: lieu,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.calendar_today,
                            label: 'DATE',
                            value: activityDate != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(activityDate)
                                : _formatDate(_inscription.dateDemande),
                          ),
                        ),
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.access_time,
                            label: 'TIME',
                            value: act['heure'] as String? ?? '10:00 AM',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.people_outline,
                            label: 'PEOPLE',
                            value: '$placeCount Participants',
                          ),
                        ),
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'ID',
                            value:
                                '#DJT-${_inscription.id.substring(_inscription.id.length - 5).toUpperCase()}',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} TND',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_inscription.isApproved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A confirmation email has been sent to your registered address with the QR code ticket and arrival instructions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Organizer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: orgaPhoto.isNotEmpty
                              ? NetworkImage(orgaPhoto)
                              : null,
                          child: orgaPhoto.isEmpty
                              ? Text(
                                  orgaName.isNotEmpty
                                      ? orgaName[0].toUpperCase()
                                      : 'O',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orgaName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    orgaRating > 0
                                        ? orgaRating.toStringAsFixed(1)
                                        : 'N/A',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($orgaReviews reviews)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: organizerId.isNotEmpty
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PublicProfileScreen(
                                          userId: organizerId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.person_outline, size: 16),
                            label: const Text(
                              'Profile',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openOrganizerChat(
                              organizerId: organizerId,
                              organizerName: orgaName,
                              organizerAvatar: orgaPhoto,
                            ),
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text(
                              'Contact',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openOrganizerChat(
                    organizerId: organizerId,
                    organizerName: orgaName,
                    organizerAvatar: orgaPhoto,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: (_inscription.isPending ||
                        (_inscription.isApproved &&
                            _inscription.canBeCancelledWithTime))
                    ? ElevatedButton.icon(
                        onPressed: _isCancelling ? null : _cancelBooking,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 20),
                        label: Text(
                          _isCancelling
                              ? 'Cancelling...'
                              : 'Cancel Reservation',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.info_outline, size: 20),
                        label: Text(_inscription.statusLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _SummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingMediaPanel extends StatefulWidget {
  final bool showQr;
  final bool hasQrData;
  final String qrData;
  final List<String> photoUrls;

  const _BookingMediaPanel({
    required this.showQr,
    required this.hasQrData,
    required this.qrData,
    required this.photoUrls,
  });

  @override
  State<_BookingMediaPanel> createState() => _BookingMediaPanelState();
}

class _BookingMediaPanelState extends State<_BookingMediaPanel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.showQr && widget.hasQrData) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: QrImageView(
          data: widget.qrData,
          version: QrVersions.auto,
          size: 170,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(10),
        ),
      );
    }

    if (widget.photoUrls.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_outlined, size: 34, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'No images found',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.photoUrls.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            return Image.network(
              widget.photoUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE2E8F0),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: Color(0xFF94A3B8),
                  size: 36,
                ),
              ),
            );
          },
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/${widget.photoUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
