import 'package:hive_flutter/hive_flutter.dart';
import '../models/review_queue_item.dart';
import '../models/booking_review_model.dart';

/// Service de persistance locale pour la queue de reviews
/// Utilise Hive pour un stockage performant et type-safe
class ReviewStorageService {
  static const String _queueBoxName = 'review_queue';
  static const String _shownBookingsBoxName = 'shown_bookings';
  static const String _settingsBoxName = 'review_settings';

  late Box<ReviewQueueItem> _queueBox;
  late Box<String> _shownBookingsBox;
  late Box<dynamic> _settingsBox;

  bool _isInitialized = false;

  /// Initialise les boxes Hive
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ouvrir ou créer les boxes
      if (!Hive.isBoxOpen(_queueBoxName)) {
        _queueBox = await Hive.openBox<ReviewQueueItem>(_queueBoxName);
      } else {
        _queueBox = Hive.box<ReviewQueueItem>(_queueBoxName);
      }

      if (!Hive.isBoxOpen(_shownBookingsBoxName)) {
        _shownBookingsBox = await Hive.openBox<String>(_shownBookingsBoxName);
      } else {
        _shownBookingsBox = Hive.box<String>(_shownBookingsBoxName);
      }

      if (!Hive.isBoxOpen(_settingsBoxName)) {
        _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName);
      } else {
        _settingsBox = Hive.box<dynamic>(_settingsBoxName);
      }

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize ReviewStorageService: $e');
    }
  }

  /// Récupère tous les items de la queue
  List<ReviewQueueItem> getQueueItems() {
    if (!_isInitialized) return [];
    return _queueBox.values.toList();
  }

  /// Ajoute un item à la queue
  Future<void> addToQueue(ReviewQueueItem item) async {
    if (!_isInitialized) await initialize();
    await _queueBox.put(item.booking.id, item);
  }

  /// Ajoute plusieurs items à la queue
  Future<void> addMultipleToQueue(List<ReviewQueueItem> items) async {
    if (!_isInitialized) await initialize();
    
    final Map<String, ReviewQueueItem> itemsMap = {};
    for (final item in items) {
      itemsMap[item.booking.id] = item;
    }
    await _queueBox.putAll(itemsMap);
  }

  /// Retire un item de la queue
  Future<void> removeFromQueue(String bookingId) async {
    if (!_isInitialized) await initialize();
    await _queueBox.delete(bookingId);
  }

  /// Met à jour un item dans la queue
  Future<void> updateQueueItem(ReviewQueueItem item) async {
    if (!_isInitialized) await initialize();
    await _queueBox.put(item.booking.id, item);
  }

  /// Vide toute la queue
  Future<void> clearQueue() async {
    if (!_isInitialized) await initialize();
    await _queueBox.clear();
  }

  /// Vérifie si un booking est dans la queue
  bool isInQueue(String bookingId) {
    if (!_isInitialized) return false;
    return _queueBox.containsKey(bookingId);
  }

  /// Marque un booking comme déjà affiché dans la session
  Future<void> markAsShown(String bookingId) async {
    if (!_isInitialized) await initialize();
    await _shownBookingsBox.put(bookingId, DateTime.now().toIso8601String());
  }

  /// Vérifie si un booking a déjà été affiché
  bool hasBeenShown(String bookingId) {
    if (!_isInitialized) return false;
    return _shownBookingsBox.containsKey(bookingId);
  }

  /// Retire un booking de la liste des bookings affichés
  Future<void> removeFromShown(String bookingId) async {
    if (!_isInitialized) await initialize();
    await _shownBookingsBox.delete(bookingId);
  }

  /// Vide la liste des bookings affichés (nouvelle session)
  Future<void> clearShownBookings() async {
    if (!_isInitialized) await initialize();
    await _shownBookingsBox.clear();
  }

  /// Nettoie les anciens bookings affichés (plus de 24h)
  Future<void> cleanupOldShownBookings() async {
    if (!_isInitialized) await initialize();
    
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    
    final keysToDelete = <String>[];
    for (final entry in _shownBookingsBox.entries) {
      final shownTime = DateTime.parse(entry.value);
      if (shownTime.isBefore(cutoff)) {
        keysToDelete.add(entry.key);
      }
    }
    
    if (keysToDelete.isNotEmpty) {
      await _shownBookingsBox.deleteAll(keysToDelete);
    }
  }

  /// Sauvegarde un paramètre
  Future<void> setSetting(String key, dynamic value) async {
    if (!_isInitialized) await initialize();
    await _settingsBox.put(key, value);
  }

  /// Récupère un paramètre
  T? getSetting<T>(String key) {
    if (!_isInitialized) return null;
    return _settingsBox.get(key) as T?;
  }

  /// Supprime un paramètre
  Future<void> removeSetting(String key) async {
    if (!_isInitialized) await initialize();
    await _settingsBox.delete(key);
  }

  /// Ferme toutes les boxes
  Future<void> close() async {
    await _queueBox.close();
    await _shownBookingsBox.close();
    await _settingsBox.close();
    _isInitialized = false;
  }

  /// Réinitialise toutes les données
  Future<void> reset() async {
    if (!_isInitialized) await initialize();
    await _queueBox.clear();
    await _shownBookingsBox.clear();
    await _settingsBox.clear();
  }
}
