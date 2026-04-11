import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/activity_model.dart';
import '../services/booking_service.dart';
import '../screens/shared/review_prompt_modal.dart';

class ReviewPromptService {
  static ReviewPromptService? _instance;
  static ReviewPromptService get instance => _instance ??= ReviewPromptService._();
  ReviewPromptService._();

  final Set<String> _shownInSession = <String>{};
  DateTime? _lastCheck;

  /// Vérifie si le modal doit être affiché et l'affiche si nécessaire
  Future<void> checkAndShowReviewModal(BuildContext context) async {
    final now = DateTime.now();
    
    // Éviter les vérifications trop fréquentes (cooldown de 5 minutes)
    if (_lastCheck != null && now.difference(_lastCheck!).inMinutes < 5) {
      return;
    }
    
    _lastCheck = now;

    try {
      // Récupérer tous les bookings de l'utilisateur
      final bookingsData = await BookingService.getMyBookings();
      final bookings = bookingsData.map((data) => BookingModel.fromJson(data)).toList();

      // Parcourir les bookings pour trouver ceux éligibles
      for (final booking in bookings) {
        // Vérifier si déjà affiché dans cette session
        if (_shownInSession.contains(booking.id)) {
          continue;
        }

        // Récupérer les détails de l'activité
        if (booking.activity != null) {
          final activity = ActivityModel.fromJson(booking.activity!);
          
          // Vérifier les conditions d'affichage
          if (await _shouldShowReviewModal(booking, activity)) {
            if (context.mounted) {
              _shownInSession.add(booking.id);
              await _showReviewModal(context, booking, activity);
              break; // Afficher un seul modal à la fois
            }
          }
        }
      }
    } catch (e) {
      print('Error checking review modal: $e');
    }
  }

  /// Vérifie si un booking spécifique doit afficher le modal
  Future<bool> shouldShowForBooking(BookingModel booking, ActivityModel activity) async {
    return await _shouldShowReviewModal(booking, activity);
  }

  /// Affiche manuellement le modal pour un booking spécifique
  Future<void> showForBooking(
    BuildContext context,
    BookingModel booking,
    ActivityModel activity,
  ) async {
    if (await _shouldShowReviewModal(booking, activity)) {
      _shownInSession.add(booking.id);
      await _showReviewModal(context, booking, activity);
    }
  }

  /// Réinitialise l'état de la session (pour les tests)
  void resetSessionState() {
    _shownInSession.clear();
    _lastCheck = null;
  }

  /// Conditions principales pour afficher le modal
  Future<bool> _shouldShowReviewModal(BookingModel booking, ActivityModel activity) async {
    try {
      final now = DateTime.now();

      // 1. Activité terminée
      if (now.isBefore(activity.dateFin)) {
        return false;
      }

      // 2. Booking confirmé
      if (booking.statut != 'confirmed') {
        return false;
      }

      // 3. User a participé (checked-in)
      if (booking.checkedIn != true) {
        return false;
      }

      // 4. Aucun review existant
      if (booking.hasReviewed == true) {
        return false;
      }

      // 5. User est le propriétaire du booking (vérifié par l'API)

      // 6. Délai valide (7 jours après la fin)
      final deadline = activity.dateFin.add(const Duration(days: 7));
      if (now.isAfter(deadline)) {
        return false;
      }

      // 7. Vérifier les rappels existants
      final reminderData = await BookingService.getReviewReminderData(booking.id);
      if (reminderData != null) {
        final remindAt = DateTime.parse(reminderData['remindAt']);
        final reminderCount = (reminderData['reminderCount'] as num?)?.toInt() ?? 0;
        
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

  /// Affiche le modal de review
  Future<void> _showReviewModal(
    BuildContext context,
    BookingModel booking,
    ActivityModel activity,
  ) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewPromptModal(
        booking: booking,
        activity: activity,
      ),
    );
  }

  /// Vérifie si le système de rappel doit être arrêté pour un booking
  bool shouldStopReminderSystem(BookingModel booking, ActivityModel activity) {
    final now = DateTime.now();

    // Arrêter si le user a fait le review
    if (booking.hasReviewed == true) {
      return true;
    }

    // Arrêter si le délai global est dépassé
    final deadline = activity.dateFin.add(const Duration(days: 7));
    if (now.isAfter(deadline)) {
      return true;
    }

    // Arrêter si le booking devient invalide
    if (booking.statut != 'confirmed' || booking.checkedIn != true) {
      return true;
    }

    return false;
  }

  /// Calcule le prochain temps de rappel
  DateTime calculateNextReminderTime(Map<String, dynamic> reminderData) {
    final currentCount = (reminderData['reminderCount'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();

    switch (currentCount) {
      case 0:
        // Premier rappel après 2 jours
        return now.add(const Duration(days: 2));
      case 1:
        // Deuxième rappel après 3 jours supplémentaires
        return now.add(const Duration(days: 3));
      case 2:
        // Troisième rappel après 2 jours supplémentaires
        return now.add(const Duration(days: 2));
      default:
        // Pas plus de rappels
        return now.add(const Duration(days: 365));
    }
  }

  /// Vérifie les conditions anti-spam
  bool passesAntiSpamChecks(Map<String, dynamic> reminderData) {
    final currentCount = (reminderData['reminderCount'] as num?)?.toInt() ?? 0;
    final lastReminder = reminderData['lastReminder'] != null
        ? DateTime.parse(reminderData['lastReminder'])
        : DateTime.fromMillisecondsSinceEpoch(0);
    
    final now = DateTime.now();

    // Maximum 3 affichages
    if (currentCount >= 3) {
      return false;
    }

    // Cooldown de 24h entre chaque rappel
    if (now.difference(lastReminder).inHours < 24) {
      return false;
    }

    return true;
  }

  /// Nettoie les anciennes données de rappel
  Future<void> cleanupExpiredReminders() async {
    try {
      final bookingsData = await BookingService.getMyBookings();
      final bookings = bookingsData.map((data) => BookingModel.fromJson(data)).toList();

      for (final booking in bookings) {
        if (booking.activity != null) {
          final activity = ActivityModel.fromJson(booking.activity!);
          
          if (shouldStopReminderSystem(booking, activity)) {
            // Nettoyer les données de rappel expirées
            await BookingService.dismissReviewReminder(booking.id);
          }
        }
      }
    } catch (e) {
      print('Error cleaning up expired reminders: $e');
    }
  }

  /// Statistiques du système de rappel
  Map<String, dynamic> getSystemStats() {
    return {
      'shownInSession': _shownInSession.length,
      'lastCheck': _lastCheck?.toIso8601String(),
      'activeBookings': _shownInSession.length,
    };
  }
}
