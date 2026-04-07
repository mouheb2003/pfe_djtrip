import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/inscription_model.dart';
import 'tourist_main_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final InscriptionModel inscription;

  const BookingConfirmationScreen({super.key, required this.inscription});

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
    final computed = unitPrice * inscription.nombreParticipants;
    if (inscription.prixTotal > 0) {
      return inscription.prixTotal;
    }
    return computed;
  }

  @override
  Widget build(BuildContext context) {
    final activity = inscription.activite;
    final photos = activity?['photos'] as List? ?? [];
    final imageUrl = photos.isNotEmpty ? photos.first as String : '';
    final title = activity?['titre'] as String? ?? 'Activity';
    final date =
        DateTime.tryParse(
          (activity?['date_debut'] ?? activity?['dateDebut'] ?? '').toString(),
        ) ??
        inscription.dateDemande ??
        DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final timeStr = activity?['heure'] as String? ?? '10:00 AM';
    final status = _normalizeStatus(inscription.statut);
    final isApproved = status == 'approuvee';
    final isPending = status == 'en_attente';
    final isRejected = status == 'refusee';
    final isCancelled = status == 'annulee';
    final totalPrice = _bookingTotal(activity);
    final qrData = inscription.qrData;
    final hasQrData = qrData.trim().isNotEmpty;
    final reason = inscription.organizerReason;
    final showQr = isApproved;
    final showReason = (isRejected || isCancelled) && reason != null;
    final statusLabel = inscription.statusLabel.toUpperCase();
    final statusColor = inscription.statusColor;
    final headline = isApproved
        ? 'Booking Confirmed!'
        : isPending
        ? 'Waiting for approval'
        : isRejected
        ? 'Booking Rejected'
        : 'Booking Cancelled';
    final subtitle = isApproved
        ? 'Your booking is approved. Keep your QR code for check-in.'
        : isPending
        ? 'Your request has been sent. The organizer will review it soon.'
        : isRejected
        ? 'The organizer rejected this booking request.'
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
          'Confirmation',
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
              // Top media section: show QR for approved bookings, otherwise activity image
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: showQr && hasQrData
                      ? Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 170,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(10),
                          ),
                        )
                      : imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, size: 42),
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
                                '${inscription.nombreParticipants} Participants',
                          ),
                        ),
                        Expanded(
                          child: _SummaryRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'ID',
                            value:
                                '#DJT-${inscription.id.substring(inscription.id.length - 5).toUpperCase()}',
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
                        builder: (_) =>
                            const TouristMainScreen(initialIndex: 0),
                      ),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Go Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
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
