import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../payment/stripe_payment_screen.dart';
import 'tourist_main_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final InscriptionModel inscription;

  const BookingConfirmationScreen({super.key, required this.inscription});

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isDeleting = false;

  String _normalizeStatus(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    if (status == 'approved' ||
        status == 'confirmée' ||
        status == 'confirmed') {
      return 'approuvee';
    }
    if (status == 'pending' || status == 'en attente') {
      return 'en_attente';
    }
    if (status == 'rejected' || status == 'refusée') {
      return 'refusee';
    }
    if (status == 'cancelled' || status == 'canceled' || status == 'annulée') {
      return 'annulee';
    }
    return status;
  }

  double _bookingTotal(Map<String, dynamic>? activity) {
    final unitPrice = (activity?['prix'] as num?)?.toDouble() ?? 0.0;
    final computed = unitPrice * widget.inscription.nombreParticipants;
    if (widget.inscription.prixTotal > 0) {
      return widget.inscription.prixTotal;
    }
    return computed;
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

  Future<void> _deleteBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final success = await InscriptionService.cancelInscription(widget.inscription.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const TouristMainScreen(initialIndex: 2),
          ),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.inscription.activite;
    final photoUrls = _activityPhotoUrls(activity);
    final title = activity?['titre'] as String? ?? 'Activity';
    final location =
        (activity?['lieu'] ??
                activity?['localisation'] ??
                activity?['adresse'] ??
                activity?['address'])
            ?.toString() ??
        'Location not specified';
    final date =
        DateTime.tryParse(
          (activity?['date_debut'] ?? activity?['dateDebut'] ?? '').toString(),
        ) ??
        widget.inscription.dateDemande ??
        DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final timeStr = activity?['heure'] as String? ?? '10:00 AM';
    final status = _normalizeStatus(widget.inscription.statut);
    final isApproved = status == 'approuvee';
    final isPending = status == 'en_attente';
    final isRejected = status == 'refusee';
    final isCancelled = status == 'annulee';
    final isUsed = status == 'verifie';
    final isPaymentFailed = widget.inscription.isPaymentFailed;
    final totalPrice = _bookingTotal(activity);
    final qrData = widget.inscription.qrData;
    final hasQrData = qrData.trim().isNotEmpty;
    final reason = widget.inscription.organizerReason;
    final showQr = isApproved;
    final showReason = (isRejected || isCancelled) && reason != null;
    final statusLabel = widget.inscription.statusLabel.toUpperCase();
    final statusColor = widget.inscription.statusColor;
    final headline = isPaymentFailed
        ? 'Payment Failed'
        : isApproved
        ? 'Booking Confirmed!'
        : isPending
        ? 'Waiting for approval'
        : isRejected
        ? 'Booking Rejected'
        : isUsed
        ? 'Checked In'
        : 'Booking Cancelled';
    final subtitle = isPaymentFailed
        ? 'Your payment could not be processed. You can delete this booking and try again.'
        : isApproved
        ? 'Your booking is approved. Keep your QR code for check-in.'
        : isPending
        ? 'Your request has been sent. The organizer will review it soon.'
        : isRejected
        ? 'The organizer rejected this booking request.'
        : isUsed
        ? 'This booking has already been checked in at the venue.'
        : 'This booking was cancelled.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Status Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved
                          ? Icons.check
                          : isPending
                          ? Icons.hourglass_top_rounded
                          : isUsed
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                headline,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Top media section: show QR for approved bookings, otherwise activity carousel
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: _BookingMediaPanel(
                    showQr: showQr,
                    hasQrData: hasQrData,
                    qrData: qrData,
                    photoUrls: photoUrls,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Booking Summary Card
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
                        Text(
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
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
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
                      value: location,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.calendar_today,
                            label: 'DATE',
                            value: dateStr,
                          ),
                        ),
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.access_time,
                            label: 'TIME',
                            value: timeStr,
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
                            value:
                                '${widget.inscription.nombreParticipants} Participants',
                          ),
                        ),
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'ID',
                            value:
                                '#DJT-${widget.inscription.id.substring(widget.inscription.id.length - 5).toUpperCase()}',
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
                          '${totalPrice.toStringAsFixed(2)} TND',
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
              if (showQr) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
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
              ],
              if (isUsed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF0F766E)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This booking has already been checked in successfully.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF115E59),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (showReason) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF5C2C7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason provided by organizer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7F1D1D),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 32),
              // Buttons
              if (isPaymentFailed || widget.inscription.statut == 'PAID_PENDING_CONFIRMATION') ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _deleteBooking,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 20),
                          label: Text(
                            _isDeleting ? 'Deleting...' : 'Delete',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            final activity = widget.inscription.activite;
                            if (activity == null) return;
                            final activityId = activity['_id']?.toString() ?? '';
                            final activityTitle = activity['titre']?.toString() ?? 'Activity';
                            
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StripePaymentScreen(
                                  inscriptionId: widget.inscription.id,
                                  activityId: activityId,
                                  activityTitle: activityTitle,
                                  nombreParticipants: widget.inscription.nombreParticipants,
                                  amount: widget.inscription.prixTotal,
                                  currency: 'TND',
                                  description: 'Payment for $activityTitle',
                                ),
                              ),
                            );
                            
                            // Refresh the screen after payment
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Pay',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Show cancel button for approved bookings
              if (isApproved) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deleteBooking,
                    icon: _isDeleting
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
                      _isDeleting ? 'Cancelling...' : 'Cancel Booking',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Only show navigation buttons for non-paid bookings
              if (!widget.inscription.isApproved) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to bookings tab (index 2 in TouristMainScreen)
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) =>
                              const TouristMainScreen(initialIndex: 2),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'View My Bookings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const TouristMainScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
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
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              'No QR code found',
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
