import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/inscription_model.dart';
import '../models/activity_model.dart';
import 'inscription_service.dart';
import 'user_service.dart';
import 'api_client.dart';
import 'review_service.dart';

/// Simple service to manage review reminders for completed activities
/// Handles both online (activity ends while app is open) and offline (activity ends while disconnected) scenarios
class ReviewReminderService {
  static const _storage = FlutterSecureStorage();
  static const _keyShownReviews = 'djtrip_shown_reviews';
  static const _keyLastCheck = 'djtrip_review_last_check';

  /// Get list of booking IDs that have already shown review popup
  static Future<Set<String>> getShownReviews() async {
    final data = await _storage.read(key: _keyShownReviews);
    if (data == null) return <String>{};
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Mark a booking as having shown the review popup
  static Future<void> markAsShown(String bookingId) async {
    final shown = await getShownReviews();
    shown.add(bookingId);
    await _storage.write(key: _keyShownReviews, value: jsonEncode(shown.toList()));
  }

  /// Clear shown reviews (for testing or user preference)
  static Future<void> clearShownReviews() async {
    await _storage.delete(key: _keyShownReviews);
  }

  /// Get the last time we checked for reviews
  static Future<DateTime?> getLastCheckTime() async {
    final data = await _storage.read(key: _keyLastCheck);
    if (data == null) return null;
    try {
      return DateTime.parse(data);
    } catch (_) {
      return null;
    }
  }

  /// Update the last check time
  static Future<void> updateLastCheck() async {
    await _storage.write(key: _keyLastCheck, value: DateTime.now().toIso8601String());
  }

  /// Check for bookings that need review prompts
  /// Returns a list of (booking, activity) tuples that should show the popup
  static Future<List<Map<String, dynamic>>> getPendingReviews() async {
    try {
      // Get all user bookings
      final bookingsMap = await InscriptionService.getMyBookings();
      final allBookings = <InscriptionModel>[];
      
      // Combine all booking statuses
      for (final status in ['pending', 'confirmed', 'cancelled']) {
        final list = bookingsMap[status] ?? [];
        allBookings.addAll(list);
      }

      // Get shown reviews to avoid showing the same popup multiple times
      final shownReviews = await getShownReviews();
      final now = DateTime.now();
      
      final pendingReviews = <Map<String, dynamic>>[];

      for (final booking in allBookings) {
        // Skip if already shown
        if (shownReviews.contains(booking.id)) {
          continue;
        }

        // Skip if booking is not approved/confirmed or is cancelled
        if (!booking.isApproved || booking.isCancelled) {
          continue;
        }

        // Extract activity data
        final activityData = booking.activite;
        if (activityData == null) continue;

        // Create ActivityModel from the data
        final activity = ActivityModel.fromJson(activityData);

        // Check if activity is past (completed)
        if (!activity.isPast) {
          continue;
        }

        // Check if activity ended within the last 7 days (review window)
        if (activity.dateFin != null) {
          final daysSinceEnd = now.difference(activity.dateFin!).inDays;
          if (daysSinceEnd > 7) {
            // Too old, skip
            continue;
          }
        }

        // Check if organizer is active
        final organizerData = booking.organisateur;
        final organizerId = organizerData?['_id'] as String?;
        print('[ReviewReminderService] Checking booking ${booking.id}, organizerId: $organizerId');
        
        if (organizerId == null || organizerId.isEmpty) {
          print('[ReviewReminderService] Organizer ID is empty for booking ${booking.id}');
          continue;
        }

        try {
          final organizer = await UserService.getUserById(organizerId);
          if (organizer == null) {
            print('[ReviewReminderService] Organizer not found for booking ${booking.id}');
            continue;
          }
          final accountStatus = organizer['accountStatus'] as String?;
          print('[ReviewReminderService] Organizer status for booking ${booking.id}: $accountStatus');
          if (accountStatus != 'active') {
            print('[ReviewReminderService] Organizer is not active (status: $accountStatus) for booking ${booking.id} - SKIPPING');
            continue;
          }
          print('[ReviewReminderService] Organizer is active for booking ${booking.id}');
        } catch (e) {
          print('[ReviewReminderService] Error checking organizer status for booking ${booking.id}: $e');
          continue;
        }

        // Check if activity has already been reviewed by this user
        try {
          final activityReview = await ReviewService.getMyActivityReview(activity.id);
          if (activityReview['hasReviewed'] == true) {
            print('[ReviewReminderService] Activity ${activity.id} already reviewed by user - SKIPPING');
            continue;
          }
          print('[ReviewReminderService] Activity ${activity.id} not yet reviewed');
        } catch (e) {
          print('[ReviewReminderService] Error checking activity review status for booking ${booking.id}: $e');
          // If we can't check, skip to be safe
          continue;
        }

        // Note: Users CAN review the same organizer for different activities
        // Only activity review is checked once per activity

        print('[ReviewReminderService] Adding booking ${booking.id} to pending reviews');

        // Add to pending reviews
        pendingReviews.add({
          'booking': booking,
          'activity': activity,
        });
      }

      // Sort by most recent completion first
      pendingReviews.sort((a, b) {
        final dateA = (a['activity'] as ActivityModel).dateFin ?? DateTime(1970);
        final dateB = (b['activity'] as ActivityModel).dateFin ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      return pendingReviews;
    } catch (e) {
      print('[ReviewReminderService] Error checking pending reviews: $e');
      return [];
    }
  }

  /// Check if there are any pending reviews
  static Future<bool> hasPendingReviews() async {
    final pending = await getPendingReviews();
    return pending.isNotEmpty;
  }

  /// Get the next pending review (most recent)
  static Future<Map<String, dynamic>?> getNextPendingReview() async {
    final pending = await getPendingReviews();
    if (pending.isEmpty) return null;
    return pending.first;
  }
}
