import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class NoveltyBadgeService {
  static Future<String> _scope() async {
    final userId = (await AuthService.getUserId() ?? '').trim();
    if (userId.isEmpty) return 'guest';
    return userId;
  }

  static Future<String> _keyFor(String section) async {
    final scope = await _scope();
    return 'novelty_seen_${scope}_$section';
  }

  static Future<String?> getSeenSignature(String section) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(section);
    return prefs.getString(key);
  }

  static Future<void> markSeen(String section, String signature) async {
    final normalized = signature.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(section);
    await prefs.setString(key, normalized);
  }

  static Future<bool> hasUnseen(String section, String currentSignature) async {
    final normalized = currentSignature.trim();
    if (normalized.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = await _keyFor(section);
    final seen = prefs.getString(key);

    if (seen == null || seen.trim().isEmpty) {
      await prefs.setString(key, normalized);
      return false;
    }

    return seen.trim() != normalized;
  }
}
