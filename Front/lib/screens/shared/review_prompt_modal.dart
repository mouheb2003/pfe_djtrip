import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/booking_model.dart';
import '../../../models/activity_model.dart';
import '../../../services/booking_service.dart';
import '../../../theme/app_theme.dart';
import 'activity_review_screen.dart';

class ReviewPromptModal extends StatefulWidget {
  final BookingModel booking;
  final ActivityModel activity;

  const ReviewPromptModal({
    super.key,
    required this.booking,
    required this.activity,
  });

  @override
  State<ReviewPromptModal> createState() => _ReviewPromptModalState();
}

class _ReviewPromptModalState extends State<ReviewPromptModal> {
  bool _isLoading = false;

  Future<void> _dismissForLater() async {
    setState(() => _isLoading = true);
    
    try {
      await BookingService.dismissReviewReminder(
        widget.booking.id,
        reminderAt: DateTime.now().add(const Duration(days: 2)),
      );
      
      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveReview() async {
    HapticFeedback.mediumImpact();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityReviewScreen(
          booking: widget.booking,
          activity: widget.activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4B63FF), Color(0xFF6B7FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _dismissForLater,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Rating Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  const Text(
                    'How was your experience?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Your feedback helps ${widget.activity.titre} improve',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Activity Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7E9F7)),
                    ),
                    child: Row(
                      children: [
                        // Activity Image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: widget.activity.thumbnailUrl?.isNotEmpty == true
                                ? DecorationImage(
                                    image: NetworkImage(widget.activity.thumbnailUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: const Color(0xFFE8E5FF),
                          ),
                          child: widget.activity.thumbnailUrl?.isEmpty != false
                              ? const Icon(
                                  Icons.image,
                                  color: Color(0xFF4B63FF),
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        
                        // Activity Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.activity.titre,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E225E),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.grey[600],
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.activity.lieu,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Completed on ${_formatDate(widget.activity.dateFin)}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Benefits
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4B63FF).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb,
                              color: Color(0xFF4B63FF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Why your review matters',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B63FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...[
                          'Help others make informed decisions',
                          'Recognize great organizers',
                          'Improve future experiences',
                        ].map((benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4B63FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Row(
                    children: [
                      // Maybe Later Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _dismissForLater,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B63FF),
                            side: const BorderSide(color: Color(0xFF4B63FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                                  ),
                                )
                              : const Text(
                                  'Maybe Later',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Leave Review Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _leaveReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B63FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Leave Review',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ReviewReminderService {
  static Future<bool> shouldShowReviewModal(BookingModel booking, ActivityModel activity) async {
    try {
      // Condition 1: Activité terminée
      final now = DateTime.now();
      if (now.isBefore(activity.dateFin)) {
        return false;
      }

      // Condition 2: Booking confirmé
      if (booking.statut != 'confirmed') {
        return false;
      }

      // Condition 3: User a participé
      if (booking.checkedIn != true) {
        return false;
      }

      // Condition 4: Aucun review existant
      if (booking.hasReviewed == true) {
        return false;
      }

      // Condition 5: User est le propriétaire du booking
      // (Assume que le booking est déjà filtré pour l'utilisateur actuel)

      // Condition 6: Délai valide (7 jours après la fin)
      final deadline = activity.dateFin.add(const Duration(days: 7));
      if (now.isAfter(deadline)) {
        return false;
      }

      // Condition 7: Vérifier les rappels
      final reminderData = await BookingService.getReviewReminderData(booking.id);
      if (reminderData != null) {
        final remindAt = DateTime.parse(reminderData['remindAt']);
        final reminderCount = reminderData['reminderCount'] ?? 0;
        
        // Ne pas afficher si le temps de rappel n'est pas atteint
        if (now.isBefore(remindAt)) {
          return false;
        }
        
        // Limiter le nombre de rappels (max 3)
        if (reminderCount >= 3) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking review modal conditions: $e');
      return false;
    }
  }

  static Future<void> showReviewModal(
    BuildContext context,
    BookingModel booking,
    ActivityModel activity,
  ) async {
    if (await shouldShowModal(booking, activity)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ReviewPromptModal(
          booking: booking,
          activity: activity,
        ),
      );
    }
  }

  static Future<bool> shouldShowModal(BookingModel booking, ActivityModel activity) async {
    return await shouldShowReviewModal(booking, activity);
  }
}
