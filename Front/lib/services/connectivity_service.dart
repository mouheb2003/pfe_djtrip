import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((item) => item != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static Stream<bool> get onStatusChanged {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((item) => item != ConnectivityResult.none),
    );
  }
}
