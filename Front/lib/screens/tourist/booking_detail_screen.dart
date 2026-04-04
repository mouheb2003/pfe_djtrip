import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import 'package:intl/intl.dart';
import '../shared/activity_detail_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final InscriptionModel inscription;

  const BookingDetailScreen({super.key, required this.inscription});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isCancelling = false;
  late InscriptionModel _inscription;

  @override
  void initState() {
    super.initState();
    _inscription = widget.inscription;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Future<void> _cancelBooking() async {
    if (!_inscription.canBeCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This booking cannot be cancelled'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.\n\n'
          'Refund policy may apply based on the organizer\'s terms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final success = await InscriptionService.cancelInscription(_inscription.id);
      
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
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final act = _inscription.activite ?? {};
    final photos = act['photos'] as List?;
    final imageUrl = photos != null && photos.isNotEmpty ? photos[0] as String : '';
    final title = act['titre'] as String? ?? 'Activity';
    final lieu = act['lieu'] as String? ?? 'Location';
    final placeCount = _inscription.nombreParticipants;
    final unitPrice = (act['prix'] as num?)?.toDouble() ?? 0.0;
    final subtotal = unitPrice * placeCount;
    const serviceFee = 4.50; // Mock service fee for the design
    final total = subtotal + serviceFee;
    
    // Organizer
    final orga = act['organisateur'] is Map ? act['organisateur'] as Map : {};
    final orgaName = orga['nom'] as String? ?? 'Organizer Name';
    final orgaPhoto = orga['photoProfil'] as String? ?? '';

    // Get activity dates properly
    DateTime? activityDate;
    if (act['date_debut'] != null) {
      activityDate = DateTime.tryParse(act['date_debut'].toString());
    } else if (act['dateDebut'] != null) {
      activityDate = DateTime.tryParse(act['dateDebut'].toString());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primary),
            onPressed: () {
              // Share action
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
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
                child: _inscription.isApproved
                    ? ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.confirmation_num_outlined, size: 20),
                        label: const Text('View Ticket'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      )
                    : _inscription.canBeCancelled
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
                            label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Booking'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Card
            GestureDetector(
              onTap: () {
                final activityId = act['_id'] as String? ?? '';
                if (activityId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityDetailScreen(
                        activityId: activityId,
                        viewOnly: true,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Container(color: Colors.grey[300]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _inscription.statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _inscription.statusLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: _inscription.statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '#DJT-${_inscription.id.substring(_inscription.id.length - 5).toUpperCase()}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                activityDate != null ? _formatDate(activityDate) : _formatDate(_inscription.dateDemande),
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                lieu,
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
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

            const SizedBox(height: 24),

            // QR Code Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'CHECK-IN QR CODE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 160,
                    height: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2, size: 80, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Present this QR code to the organizer at the meeting point.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Participants
            const Text(
              'Participants',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Stack(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFC3D0A3),
                        ),
                        if (placeCount > 1)
                          Positioned(
                            left: 20,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF2C413D),
                              child: Text(
                                '+$placeCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$placeCount Person${placeCount > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Price Details
            const Text(
              'Price Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Adult x $placeCount', style: const TextStyle(color: Colors.black54, fontSize: 14)),
                      Text('${subtotal.toStringAsFixed(2)} TND', style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service Fee', style: TextStyle(color: Colors.black54, fontSize: 14)),
                      Text('${serviceFee.toStringAsFixed(2)} TND', style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      Text(
                        '${total.toStringAsFixed(2)} TND',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Organizer
            const Text(
              'Organizer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: orgaPhoto.isNotEmpty ? NetworkImage(orgaPhoto) : null,
                    child: orgaPhoto.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orgaName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.star, size: 12, color: Colors.orange),
                          Icon(Icons.star, size: 12, color: Colors.orange),
                          Icon(Icons.star, size: 12, color: Colors.orange),
                          Icon(Icons.star, size: 12, color: Colors.orange),
                          Icon(Icons.star_half, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('4.8 (124 reviews)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
