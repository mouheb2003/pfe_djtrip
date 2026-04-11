import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/booking_review_model.dart';
import '../models/review_queue_item.dart';
import 'review_storage_service.dart';
import 'review_api_service.dart';

/// Service principal de gestion de la queue de reviews
/// Coordonne la logique métier, l'API et le stockage local
class ReviewQueueService extends ChangeNotifier {
  final ReviewStorageService _storageService;
  final ReviewApiService _apiService;
  final String _userToken;

  List<ReviewQueueItem> _queue = [];
  bool _isLoading = false;
  String? _error;
  Timer? _syncTimer;
  DateTime? _lastPopupShown;

  // Configuration
  static const Duration _cooldownBetweenPopups = Duration(minutes: 5);
  static const Duration _syncInterval = Duration(hours: 1);
  static const Duration _maxReviewWindow = Duration(days: 7);

  ReviewQueueService({
    required ReviewStorageService storageService,
    required ReviewApiService apiService,
    required String userToken,
  })  : _storageService = storageService,
        _apiService = apiService,
        _userToken = userToken {
    _initialize();
  }

  // Getters
  List<ReviewQueueItem> get queue => List.unmodifiable(_queue);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _queue.length;
  bool get hasPendingReviews => _queue.isNotEmpty;

  /// Initialise le service
  Future<void> _initialize() async {
    try {
      await _storageService.initialize();
      await _loadQueueFromStorage();
      await _syncWithBackend();
      _startSyncTimer();
    } catch (e) {
      _error = 'Initialization error: $e';
      notifyListeners();
    }
  }

  /// Charge la queue depuis le stockage local
  Future<void> _loadQueueFromStorage() async {
    try {
      _queue = _storageService.getQueueItems();
      
      // Trier par date de fin d'activité (plus récent d'abord)
      _queue.sort((a, b) => b.booking.endDate.compareTo(a.booking.endDate));
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading queue from storage: $e');
    }
  }

  /// Synchronise avec le backend
  Future<void> _syncWithBackend() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Récupérer tous les bookings depuis l'API
      final allBookings = await _apiService.getUserBookings(token: _userToken);

      // Filtrer les bookings éligibles pour review
      final eligibleBookings = _filterEligibleBookings(allBookings);

      // Fusionner avec la queue existante
      await _mergeWithExistingQueue(eligibleBookings);

      // Nettoyer les items expirés ou déjà reviewés
      await _cleanupQueue();
    } catch (e) {
      _error = 'Sync error: $e';
      debugPrint('Sync error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtre les bookings éligibles pour review
  List<BookingReviewModel> _filterEligibleBookings(List<BookingReviewModel> bookings) {
    final now = DateTime.now();

    return bookings.where((booking) {
      // L'activité doit être terminée
      if (now.isBefore(booking.endDate)) return false;

      // L'utilisateur doit avoir participé (check-in)
      if (!booking.isCheckedIn) return false;

      // Pas déjà reviewé
      if (booking.isReviewed) return false;

      // Dans la fenêtre de review (7 jours après la fin)
      final deadline = booking.endDate.add(_maxReviewWindow);
      if (now.isAfter(deadline)) return false;

      // Pas déjà dans la queue (sera géré par merge)
      return true;
    }).toList();
  }

  /// Fusionne les bookings avec la queue existante
  Future<void> _mergeWithExistingQueue(List<BookingReviewModel> newBookings) async {
    for (final booking in newBookings) {
      // Si pas dans la queue, l'ajouter
      if (!_storageService.isInQueue(booking.id)) {
        final queueItem = ReviewQueueItem.fromBooking(booking);
        await _storageService.addToQueue(queueItem);
        _queue.add(queueItem);
      } else {
        // Mettre à jour si le booking a changé
        final existingIndex = _queue.indexWhere((item) => item.booking.id == booking.id);
        if (existingIndex != -1) {
          _queue[existingIndex] = _queue[existingIndex].copyWith(booking: booking);
          await _storageService.updateQueueItem(_queue[existingIndex]);
        }
      }
    }

    // Retrier
    _queue.sort((a, b) => b.booking.endDate.compareTo(a.booking.endDate));
    notifyListeners();
  }

  /// Nettoie la queue (items expirés ou reviewés)
  Future<void> _cleanupQueue() async {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final item in _queue) {
      // Si le booking est maintenant reviewé
      if (item.booking.isReviewed) {
        toRemove.add(item.booking.id);
        continue;
      }

      // Si la fenêtre de review est expirée
      final deadline = item.booking.endDate.add(_maxReviewWindow);
      if (now.isAfter(deadline)) {
        toRemove.add(item.booking.id);
      }
    }

    for (final bookingId in toRemove) {
      await _storageService.removeFromQueue(bookingId);
      _queue.removeWhere((item) => item.booking.id == bookingId);
    }

    if (toRemove.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Démarre le timer de synchronisation automatique
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _syncWithBackend();
    });
  }

  /// Récupère le prochain item à afficher
  ReviewQueueItem? getNextItemToShow() {
    // Vérifier le cooldown
    if (_lastPopupShown != null) {
      final timeSinceLastPopup = DateTime.now().difference(_lastPopupShown!);
      if (timeSinceLastPopup < _cooldownBetweenPopups) {
        return null;
      }
    }

    // Trouver le premier item qui peut être affiché
    for (final item in _queue) {
      if (item.canBeShown(cooldown: _cooldownBetweenPopups) &&
          !_storageService.hasBeenShown(item.booking.id)) {
        return item;
      }
    }

    return null;
  }

  /// Marque un item comme affiché
  Future<void> markAsShown(String bookingId) async {
    final index = _queue.indexWhere((item) => item.booking.id == bookingId);
    if (index != -1) {
      _queue[index] = _queue[index].markAsShown();
      await _storageService.updateQueueItem(_queue[index]);
      await _storageService.markAsShown(bookingId);
      _lastPopupShown = DateTime.now();
      notifyListeners();
    }
  }

  /// Soumet un review
  Future<bool> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    final index = _queue.indexWhere((item) => item.booking.id == bookingId);
    if (index == -1) return false;

    try {
      final booking = _queue[index].booking;

      // Appeler l'API
      final result = await _apiService.submitReview(
        token: _userToken,
        bookingId: bookingId,
        activityId: booking.activityId,
        rating: rating,
        comment: comment,
        tags: tags,
      );

      if (result['success'] == true) {
        // Retirer de la queue
        await _storageService.removeFromQueue(bookingId);
        await _storageService.removeFromShown(bookingId);
        _queue.removeAt(index);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error submitting review: $e');
      return false;
    }
  }

  /// Snooze un item (remet dans la queue plus tard)
  Future<void> snoozeItem(String bookingId, {Duration duration = const Duration(hours: 2)}) async {
    final index = _queue.indexWhere((item) => item.booking.id == bookingId);
    if (index != -1) {
      _queue[index] = _queue[index].snooze(duration);
      await _storageService.updateQueueItem(_queue[index]);
      notifyListeners();
    }
  }

  /// Retire un item de la queue (user ignore définitivement)
  Future<void> dismissItem(String bookingId) async {
    await _storageService.removeFromQueue(bookingId);
    await _storageService.removeFromShown(bookingId);
    _queue.removeWhere((item) => item.booking.id == bookingId);
    notifyListeners();
  }

  /// Force une synchronisation manuelle
  Future<void> forceSync() async {
    await _syncWithBackend();
  }

  /// Réinitialise la session (nouvelle session d'app)
  Future<void> resetSession() async {
    await _storageService.clearShownBookings();
    await _storageService.cleanupOldShownBookings();
    notifyListeners();
  }

  /// Vide toute la queue
  Future<void> clearQueue() async {
    await _storageService.clearQueue();
    _queue.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
