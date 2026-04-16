import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/booking_model.dart';
import '../../../models/activity_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/user_service.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallScreen ? 12 : 20,
        vertical: isVerySmallScreen ? 12 : 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.9,
        ),
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
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
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
                  SizedBox(height: isSmallScreen ? 8 : 16),
                  
                  // Rating Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star,
                          color: Colors.white,
                          size: isSmallScreen ? 24 : 32,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 16),
                  
                  // Title
                  Text(
                    'How was your experience?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 18 : 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  
                  // Subtitle
                  Text(
                    'Your feedback helps ${widget.activity.titre} improve',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                    // Activity Info
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E9F7)),
                      ),
                      child: Row(
                        children: [
                          // Activity Image
                          Container(
                            width: isSmallScreen ? 50 : 60,
                            height: isSmallScreen ? 50 : 60,
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
                                ? Icon(
                                    Icons.image,
                                    color: const Color(0xFF4B63FF),
                                    size: isSmallScreen ? 20 : 24,
                                  )
                                : null,
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
                          
                          // Activity Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.activity.titre,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E225E),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.grey[600],
                                      size: isSmallScreen ? 12 : 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.activity.lieu,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isSmallScreen ? 11 : 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Text(
                                  'Completed on ${widget.activity.dateFin != null ? _formatDate(widget.activity.dateFin!) : 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: isSmallScreen ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    
                    // Benefits
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
                              Icon(
                                Icons.lightbulb,
                                color: const Color(0xFF4B63FF),
                                size: isSmallScreen ? 16 : 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Why your review matters',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4B63FF),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          ...[
                            'Help others make informed decisions',
                            'Recognize great organizers',
                            'Improve future experiences',
                          ].map((benefit) => Padding(
                            padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
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
                                      fontSize: isSmallScreen ? 12 : 13,
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
                    
                    SizedBox(height: isSmallScreen ? 20 : 32),
                    
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
                              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                                    ),
                                  )
                                : Text(
                                    'Maybe Later',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        
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
                              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                            ),
                            child: Text(
                              'Leave Review',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 16),
                  ],
                ),
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
      if (activity.dateFin == null || now.isBefore(activity.dateFin!)) {
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
      if (activity.dateFin == null) {
        return false;
      }
      final deadline = activity.dateFin!.add(const Duration(days: 7));
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

      // Condition 8: Vérifier si l'organisateur est actif
      final organizerId = booking.organisateurId;
      if (organizerId.isEmpty) {
        print('Organizer ID is empty for booking ${booking.id}');
        return false;
      }

      try {
        final organizer = await UserService.getUserById(organizerId);
        if (organizer == null) {
          print('Organizer not found for booking ${booking.id}');
          return false;
        }
        final accountStatus = organizer['accountStatus'] as String?;
        if (accountStatus != 'active') {
          print('Organizer is not active (status: $accountStatus) for booking ${booking.id}');
          return false;
        }
      } catch (e) {
        print('Error checking organizer status: $e');
        // If we can't check organizer status, don't show the modal to be safe
        return false;
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
