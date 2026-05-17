import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les check-ins en mode offline
/// Stocke les check-ins localement et sync quand online
class CheckinOfflineService {
  static final CheckinOfflineService _instance = CheckinOfflineService._internal();
  factory CheckinOfflineService() => _instance;
  CheckinOfflineService._internal();

  static const String _queueBoxName = 'checkin_queue';
  late Box<Map> _queueBox;
  bool _initialized = false;

  /// Initialise le service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (!Hive.isBoxOpen(_queueBoxName)) {
        _queueBox = await Hive.openBox<Map>(_queueBoxName);
      } else {
        _queueBox = Hive.box<Map>(_queueBoxName);
      }
      _initialized = true;
    } catch (e) {
      print('Error initializing CheckinOfflineService: $e');
    }
  }

  /// Ajoute un check-in à la queue offline
  Future<void> addToQueue({
    required String inscriptionId,
    required String activityTitle,
    required String touristName,
    required DateTime timestamp,
  }) async {
    if (!_initialized) await initialize();

    final checkinData = {
      'inscriptionId': inscriptionId,
      'activityTitle': activityTitle,
      'touristName': touristName,
      'timestamp': timestamp.toIso8601String(),
      'status': 'pending',
      'retryCount': 0,
    };

    await _queueBox.put(inscriptionId, checkinData);
    print('Added check-in to offline queue: $inscriptionId');
  }

  /// Récupère tous les check-ins en attente
  Future<List<Map<String, dynamic>>> getPendingCheckins() async {
    if (!_initialized) await initialize();

    final pending = <Map<String, dynamic>>[];
    
    for (final entry in _queueBox.toMap().entries) {
      final data = entry.value;
      if (data['status'] == 'pending') {
        pending.add(Map<String, dynamic>.from(data));
      }
    }

    // Trier par timestamp (plus ancien d'abord)
    pending.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp'] as String);
      final bTime = DateTime.parse(b['timestamp'] as String);
      return aTime.compareTo(bTime);
    });

    return pending;
  }

  /// Met à jour le statut d'un check-in
  Future<void> updateStatus(String inscriptionId, String status) async {
    if (!_initialized) await initialize();

    final data = _queueBox.get(inscriptionId);
    if (data != null) {
      data['status'] = status;
      await _queueBox.put(inscriptionId, data);
    }
  }

  /// Incrémente le compteur de retry
  Future<void> incrementRetryCount(String inscriptionId) async {
    if (!_initialized) await initialize();

    final data = _queueBox.get(inscriptionId);
    if (data != null) {
      data['retryCount'] = (data['retryCount'] as int) + 1;
      await _queueBox.put(inscriptionId, data);
    }
  }

  /// Retire un check-in de la queue
  Future<void> removeFromQueue(String inscriptionId) async {
    if (!_initialized) await initialize();
    await _queueBox.delete(inscriptionId);
    print('Removed check-in from queue: $inscriptionId');
  }

  /// Vide toute la queue
  Future<void> clearQueue() async {
    if (!_initialized) await initialize();
    await _queueBox.clear();
  }

  /// Compte les check-ins en attente
  int get pendingCount {
    if (!_initialized) return 0;
    
    return _queueBox.values
        .where((data) => data['status'] == 'pending')
        .length;
  }

  /// Sauvegarde le timestamp du dernier sync
  Future<void> saveLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_checkin_sync', DateTime.now().toIso8601String());
  }

  /// Récupère le timestamp du dernier sync
  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString('last_checkin_sync');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  /// Ferme le service
  Future<void> close() async {
    await _queueBox.close();
    _initialized = false;
  }
}
