import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'dart:convert';

/// Base state for async operations
enum LoadingState { idle, loading, loaded, error }

/// User provider for global state management
class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  LoadingState _state = LoadingState.idle;
  String? _error;

  Map<String, dynamic>? get user => _user;
  LoadingState get state => _state;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userType => _user?['userType'];

  /// Load user from storage
  Future<void> loadUser() async {
    _state = LoadingState.loading;
    notifyListeners();

    try {
      _user = await AuthService.getUser();
      _state = LoadingState.loaded;
    } catch (e) {
      _error = e.toString();
      _state = LoadingState.error;
    }
    notifyListeners();
  }

  /// Update user data
  void updateUser(Map<String, dynamic> userData) {
    _user = userData;
    AuthService.saveUser(userData);
    notifyListeners();
  }

  /// Clear user on logout
  void clearUser() {
    _user = null;
    _state = LoadingState.idle;
    notifyListeners();
  }

  /// Check if user has specific role
  bool hasRole(String role) {
    return _user?['userType'] == role;
  }

  /// Check if user is tourist
  bool get isTourist => hasRole('touriste');

  /// Check if user is organizer
  bool get isOrganizer => hasRole('organisator');

  /// Refresh user data from API
  Future<void> refreshUser() async {
    try {
      final res = await ApiClient.get('/users/profile', auth: true, cacheFirst: false);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final userData = body['user'] ?? body['data'] ?? body;
        if (userData is Map<String, dynamic>) {
          updateUser(userData);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }
}

/// Generic list provider for paginated data
class ListProvider<T> extends ChangeNotifier {
  List<T> _items = [];
  LoadingState _state = LoadingState.idle;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  int _total = 0;

  List<T> get items => _items;
  LoadingState get state => _state;
  String? get error => _error;
  bool get hasMore => _hasMore;
  int get total => _total;
  bool get isEmpty => _items.isEmpty;

  /// Reset and load first page
  Future<void> loadFirstPage(Future<List<T>> Function(int page) fetch) async {
    _items = [];
    _page = 1;
    _hasMore = true;
    await loadMore(fetch);
  }

  /// Load next page
  Future<void> loadMore(Future<List<T>> Function(int page) fetch) async {
    if (!_hasMore || _state == LoadingState.loading) return;

    _state = LoadingState.loading;
    notifyListeners();

    try {
      final newItems = await fetch(_page);

      if (newItems.isEmpty) {
        _hasMore = false;
      } else {
        _items = [..._items, ...newItems];
        _page++;
      }
      _state = LoadingState.loaded;
    } catch (e) {
      _error = e.toString();
      _state = LoadingState.error;
    }
    notifyListeners();
  }

  /// Refresh list
  Future<void> refresh(Future<List<T>> Function(int page) fetch) async {
    await loadFirstPage(fetch);
  }

  /// Clear list
  void clear() {
    _items = [];
    _page = 1;
    _hasMore = true;
    _total = 0;
    _state = LoadingState.idle;
    notifyListeners();
  }
}
