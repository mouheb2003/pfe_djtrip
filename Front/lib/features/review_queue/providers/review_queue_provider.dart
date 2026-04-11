import 'package:flutter/foundation.dart';
import '../models/review_queue_item.dart';
import '../services/review_queue_service.dart';

/// Provider pour la gestion de la queue de reviews
/// Utilise ChangeNotifier pour le state management
class ReviewQueueProvider extends ChangeNotifier {
  final ReviewQueueService _service;

  ReviewQueueProvider({required ReviewQueueService service}) : _service = service {
    _service.addListener(_onServiceChanged);
  }

  // Getters
  List<ReviewQueueItem> get queue => _service.queue;
  bool get isLoading => _service.isLoading;
  String? get error => _service.error;
  int get pendingCount => _service.pendingCount;
  bool get hasPendingReviews => _service.hasPendingReviews;

  /// Récupère le prochain item à afficher
  ReviewQueueItem? getNextItemToShow() {
    return _service.getNextItemToShow();
  }

  /// Marque un item comme affiché
  Future<void> markAsShown(String bookingId) async {
    await _service.markAsShown(bookingId);
  }

  /// Soumet un review
  Future<bool> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    final result = await _service.submitReview(
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      tags: tags,
    );
    return result;
  }

  /// Snooze un item
  Future<void> snoozeItem(String bookingId, {Duration duration = const Duration(hours: 2)}) async {
    await _service.snoozeItem(bookingId, duration: duration);
  }

  /// Retire un item de la queue
  Future<void> dismissItem(String bookingId) async {
    await _service.dismissItem(bookingId);
  }

  /// Force une synchronisation manuelle
  Future<void> forceSync() async {
    await _service.forceSync();
  }

  /// Réinitialise la session
  Future<void> resetSession() async {
    await _service.resetSession();
  }

  /// Vide toute la queue
  Future<void> clearQueue() async {
    await _service.clearQueue();
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }
}
