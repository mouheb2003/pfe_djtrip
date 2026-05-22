import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/lieu_service.dart';
import '../services/post_service.dart';

class BookmarkProvider extends ChangeNotifier {
  // Shared state for all bookmarks in the app
  final Map<String, bool> _activityBookmarks = {};
  final Map<String, bool> _lieuBookmarks = {};
  final Map<String, bool> _postBookmarks = {};

  // Getters
  bool isActivityBookmarked(String id) => _activityBookmarks[id] ?? false;
  bool isLieuBookmarked(String id) => _lieuBookmarks[id] ?? false;
  bool isPostBookmarked(String id) => _postBookmarks[id] ?? false;

  /// Update the internal state for an activity
  void updateActivityState(String id, bool isBookmarked, {bool force = false}) {
    if (force || !_activityBookmarks.containsKey(id)) {
      _activityBookmarks[id] = isBookmarked;
      notifyListeners();
    }
  }

  void updateLieuState(String id, bool isBookmarked, {bool force = false}) {
    if (force || !_lieuBookmarks.containsKey(id)) {
      _lieuBookmarks[id] = isBookmarked;
      notifyListeners();
    }
  }

  void updatePostState(String id, bool isBookmarked, {bool force = false}) {
    if (force || !_postBookmarks.containsKey(id)) {
      _postBookmarks[id] = isBookmarked;
      notifyListeners();
    }
  }

  /// Initialize by fetching all bookmarks from backend
  Future<void> initialize() async {
    try {
      final results = await Future.wait([
        ActivityService.getBookmarkedActivities(),
        LieuService.getBookmarkedLieux(),
        PostService.getBookmarkedPosts(),
      ]);
      
      final activities = results[0];
      final lieux = results[1];
      final posts = results[2];
      
      for (var a in activities) {
        final id = (a['_id'] ?? a['id'])?.toString();
        if (id != null) _activityBookmarks[id] = true;
      }
      for (var l in lieux) {
        final id = (l['_id'] ?? l['id'])?.toString();
        if (id != null) _lieuBookmarks[id] = true;
      }
      for (var p in posts) {
        final id = (p['_id'] ?? p['id'])?.toString();
        if (id != null) _postBookmarks[id] = true;
      }
      
      notifyListeners();
    } catch (e) {
      // fail silently or log
    }
  }

  /// Update and notify
  void setActivityBookmarked(String id, bool isBookmarked) {
    _activityBookmarks[id] = isBookmarked;
    notifyListeners();
  }

  void setLieuBookmarked(String id, bool isBookmarked) {
    _lieuBookmarks[id] = isBookmarked;
    notifyListeners();
  }

  void setPostBookmarked(String id, bool isBookmarked) {
    _postBookmarks[id] = isBookmarked;
    notifyListeners();
  }

  /// Toggle Activity Bookmark
  Future<Map<String, dynamic>> toggleActivityBookmark(String id) async {
    final original = _activityBookmarks[id] ?? false;
    
    // Optimistic UI update
    _activityBookmarks[id] = !original;
    notifyListeners();

    try {
      final result = await ActivityService.toggleActivityBookmark(id);
      if (result['success'] == true) {
        _activityBookmarks[id] = result['bookmarked'] == true;
      } else {
        _activityBookmarks[id] = original; // Rollback
      }
      notifyListeners();
      return result;
    } catch (e) {
      _activityBookmarks[id] = original; // Rollback
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Toggle Lieu Bookmark
  Future<Map<String, dynamic>> toggleLieuBookmark(String id) async {
    final original = _lieuBookmarks[id] ?? false;
    
    // Optimistic UI update
    _lieuBookmarks[id] = !original;
    notifyListeners();

    try {
      final result = await LieuService.toggleLieuBookmark(id);
      if (result['success'] == true) {
        _lieuBookmarks[id] = result['bookmarked'] == true;
      } else {
        _lieuBookmarks[id] = original; // Rollback
      }
      notifyListeners();
      return result;
    } catch (e) {
      _lieuBookmarks[id] = original; // Rollback
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Toggle Post Bookmark
  Future<Map<String, dynamic>> togglePostBookmark(String id) async {
    final original = _postBookmarks[id] ?? false;
    
    // Optimistic UI update
    _postBookmarks[id] = !original;
    notifyListeners();

    try {
      final result = await PostService.togglePostBookmark(id);
      if (result['success'] == true) {
        _postBookmarks[id] = result['bookmarked'] == true;
      } else {
        _postBookmarks[id] = original; // Rollback
      }
      notifyListeners();
      return result;
    } catch (e) {
      _postBookmarks[id] = original; // Rollback
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Clear all bookmarks (e.g. on logout)
  void clear() {
    _activityBookmarks.clear();
    _lieuBookmarks.clear();
    _postBookmarks.clear();
    notifyListeners();
  }
}
