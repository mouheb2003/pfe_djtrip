import 'dart:async';
import 'package:flutter/material.dart';
import '../models/activite.dart';
import '../models/user.dart';
import '../models/inscription.dart';
import '../screens/image_gallery_screen.dart';
import '../services/inscription_service.dart';
import 'package:intl/intl.dart';

class ActivityCardTourist extends StatefulWidget {
  final Activite activity;
  final User user;
  final VoidCallback onRefresh;
  final bool isPast;

  const ActivityCardTourist({
    super.key,
    required this.activity,
    required this.user,
    required this.onRefresh,
    this.isPast = false,
  });

  @override
  State<ActivityCardTourist> createState() => _ActivityCardTouristState();
}

class _ActivityCardTouristState extends State<ActivityCardTourist> {
  int _currentImageIndex = 0;
  Timer? _imageTimer;
  final PageController _pageController = PageController();
  Inscription? _myInscription;
  bool _checkingInscription = true;

  @override
  void initState() {
    super.initState();
    if (widget.activity.photos.length > 1) {
      _startImageCarousel();
    }
    _checkMyInscription();
  }

  Future<void> _checkMyInscription() async {
    try {
      final inscriptions = await InscriptionService.getMesInscriptions();
      Inscription? found;
      for (final ins in inscriptions) {
        // Check both activiteId directly and populated activite id
        final insActiviteId = ins.activiteId.isNotEmpty
            ? ins.activiteId
            : (ins.activite?.id ?? '');
        if (insActiviteId == widget.activity.id &&
            (ins.statut == 'en_attente' || ins.statut == 'approuvee')) {
          found = ins;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _myInscription = found;
          _checkingInscription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingInscription = false;
        });
      }
    }
  }

  Future<void> _cancelInscription() async {
    if (_myInscription == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Annuler la réservation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler votre demande de réservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await InscriptionService.annulerInscription(_myInscription!.id);
        if (mounted) {
          setState(() {
            _myInscription = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Réservation annulée'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          String msg = e.toString();
          if (msg.startsWith('Exception: ')) msg = msg.substring(11);
          if (msg.startsWith('Erreur: ')) msg = msg.substring(8);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Text('Erreur', style: TextStyle(fontSize: 17)),
                ],
              ),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startImageCarousel() {
    _imageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentImageIndex =
            (_currentImageIndex + 1) % widget.activity.photos.length;
      });
      _pageController.animateToPage(
        _currentImageIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _showImageGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          imageUrls: widget.activity.photos,
          initialIndex: _currentImageIndex,
        ),
      ),
    );
  }

  void _showOrganisateurInfo(BuildContext context) {
    if (widget.activity.organisateur == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations de l\'organisateur non disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final org = widget.activity.organisateur!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2D5016),
              backgroundImage: org.avatar != null && org.avatar!.isNotEmpty
                  ? NetworkImage(org.avatar!)
                  : null,
              child: org.avatar == null || org.avatar!.isEmpty
                  ? Text(
                      org.fullname.isNotEmpty
                          ? org.fullname[0].toUpperCase()
                          : 'O',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              org.fullname,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5016).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Organisateur',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D5016),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rating
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    org.noteMoyenne.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    ' / 5.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  const SizedBox(width: 16),
                  Text(
                    '${org.nombreAvis}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D5016),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'avis',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Fonctionnalité de messagerie bientôt disponible',
                          ),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5016),
                      side: const BorderSide(
                        color: Color(0xFF2D5016),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profil complet bientôt disponible'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('Profil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fermer',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog(BuildContext context) async {
    final placesDisponibles =
        widget.activity.capaciteMax - widget.activity.nombreReservations;

    // Si plus de places disponibles
    if (placesDisponibles <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Désolé, cette activité est complète')),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int participants = 1;
    final messageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Réserver cette activité',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D5016),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Warning if limited places
                  if (placesDisponibles < 5)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange[700],
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Seulement $placesDisponibles place${placesDisponibles > 1 ? "s" : ""} restante${placesDisponibles > 1 ? "s" : ""}!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Nombre de participants
                  const Text(
                    'Nombre de participants',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: participants > 1
                              ? () => setState(() => participants--)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '$participants',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: participants < placesDisponibles
                              ? () => setState(() => participants++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prix total
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B1A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Prix total:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(widget.activity.prix * participants).toStringAsFixed(0)} DT',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message optionnel
                  const Text(
                    'Message (optionnel)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Ajoutez une note pour l\'organisateur...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5016),
                ),
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Créer l'inscription
        final response = await InscriptionService.createInscription(
          activiteId: widget.activity.id,
          nombreParticipants: participants,
          messageTouriste: messageController.text.isNotEmpty
              ? messageController.text
              : null,
        );

        if (mounted) {
          Navigator.pop(context); // Fermer le loading

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✓ Demande envoyée! L\'organisateur va examiner votre réservation.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          _checkMyInscription(); // Recheck inscription status
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Fermer le loading

          // Extract clean error message
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring('Exception: '.length);
          }
          if (errorMessage.startsWith('Erreur: ')) {
            errorMessage = errorMessage.substring('Erreur: '.length);
          }

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Text('Erreur', style: TextStyle(fontSize: 17)),
                ],
              ),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }

    messageController.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Visite guidée':
        return Icons.tour;
      case 'Excursion':
        return Icons.landscape;
      case 'Atelier':
        return Icons.palette;
      case 'Sport':
        return Icons.sports_soccer;
      case 'Gastronomie':
        return Icons.restaurant;
      case 'Culture':
        return Icons.museum;
      case 'Aventure':
        return Icons.terrain;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = widget.activity.dateFin.isAfter(now);
    final isStarted = widget.activity.dateDebut.isBefore(now);
    final daysLeft = widget.activity.dateFin.difference(now).inDays;

    String statusText = '';
    Color statusColor = Colors.grey;

    if (widget.isPast) {
      statusText = 'Completed';
      statusColor = Colors.grey;
    } else if (!isActive) {
      statusText = 'Ended';
      statusColor = Colors.red;
    } else if (isStarted) {
      if (daysLeft == 0) {
        statusText = 'Ending today';
      } else {
        statusText = 'In progress';
      }
      statusColor = Colors.blue;
    } else {
      final daysUntilStart = widget.activity.dateDebut.difference(now).inDays;
      if (daysUntilStart == 0) {
        statusText = 'Starting today';
      } else {
        statusText = 'Starts in $daysUntilStart days';
      }
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header with Carousel
            Stack(
              children: [
                if (widget.activity.photos.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemCount: widget.activity.photos.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.activity.photos[index],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[300]!,
                                      Colors.grey[400]!,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.white70,
                                ),
                              ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2D5016).withOpacity(0.7),
                          const Color(0xFF2D5016),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.photo_camera,
                        size: 50,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),

                // Type Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getActivityIcon(widget.activity.typeActivite),
                          size: 14,
                          color: const Color(0xFF2D5016),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.activity.typeActivite,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D5016),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Activity title and location overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.activity.titre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.activity.lieu,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Photo count badge - Clickable (doit être après l'overlay pour être au-dessus)
                if (widget.activity.photos.length > 1)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _showImageGallery(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.collections,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentImageIndex + 1}/${widget.activity.photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    widget.activity.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Organizer info - Clickable
                  if (widget.activity.organisateur != null)
                    GestureDetector(
                      onTap: () => _showOrganisateurInfo(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D5016).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2D5016).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF2D5016),
                              backgroundImage:
                                  widget.activity.organisateur!.avatar !=
                                          null &&
                                      widget
                                          .activity
                                          .organisateur!
                                          .avatar!
                                          .isNotEmpty
                                  ? NetworkImage(
                                      widget.activity.organisateur!.avatar!,
                                    )
                                  : null,
                              child:
                                  widget.activity.organisateur!.avatar ==
                                          null ||
                                      widget
                                          .activity
                                          .organisateur!
                                          .avatar!
                                          .isEmpty
                                  ? Text(
                                      widget
                                              .activity
                                              .organisateur!
                                              .fullname
                                              .isNotEmpty
                                          ? widget
                                                .activity
                                                .organisateur!
                                                .fullname[0]
                                                .toUpperCase()
                                          : 'O',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.activity.organisateur!.fullname,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D5016),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.activity.organisateur!.nombreAvis >
                                      0)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 12,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${widget.activity.organisateur!.noteMoyenne.toStringAsFixed(1)} (${widget.activity.organisateur!.nombreAvis})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Color(0xFF2D5016),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Date Range
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(widget.activity.dateDebut),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              Text(
                                'to ${_formatDate(widget.activity.dateFin)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B1A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B1A),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.payments,
                          size: 20,
                          color: Color(0xFFFF6B1A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.activity.prix.toStringAsFixed(0)} DT / person',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          Icons.people,
                          '${widget.activity.nombreReservations}/${widget.activity.capaciteMax}',
                          'Places',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          Icons.star,
                          widget.activity.noteMoyenne > 0
                              ? widget.activity.noteMoyenne.toStringAsFixed(1)
                              : 'New',
                          'Rating',
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          Icons.rate_review_outlined,
                          '${widget.activity.nombreAvis}',
                          'Reviews',
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  // Book / status button
                  if (!widget.isPast && isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: _checkingInscription
                            ? const Center(
                                child: SizedBox(
                                  height: 36,
                                  width: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2D5016),
                                  ),
                                ),
                              )
                            : _myInscription != null
                            ? _myInscription!.statut == 'en_attente'
                                  // Pending → Cancel Request
                                  ? ElevatedButton.icon(
                                      onPressed: _cancelInscription,
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Cancel Request'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    )
                                  // Approved → disabled "Booked"
                                  : ElevatedButton.icon(
                                      onPressed: null,
                                      icon: const Icon(
                                        Icons.check_circle,
                                        size: 18,
                                      ),
                                      label: const Text('Booked'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[600],
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            Colors.green[600],
                                        disabledForegroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    )
                            : () {
                                final placesDisponibles =
                                    widget.activity.capaciteMax -
                                    widget.activity.nombreReservations;
                                final isFull = placesDisponibles <= 0;
                                return ElevatedButton.icon(
                                  onPressed: isFull
                                      ? null
                                      : () => _showBookingDialog(context),
                                  icon: Icon(
                                    isFull ? Icons.block : Icons.bookmark_add,
                                    size: 18,
                                  ),
                                  label: Text(isFull ? 'Complet' : 'Book Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFull
                                        ? Colors.grey[400]
                                        : const Color(0xFF2D5016),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    disabledBackgroundColor: Colors.grey[400],
                                    disabledForegroundColor: Colors.grey[200],
                                  ),
                                );
                              }(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
