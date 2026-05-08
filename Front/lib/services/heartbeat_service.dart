import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Service for managing real-time presence tracking through heartbeat
class HeartbeatService {
  static HeartbeatService? _instance;
  static HeartbeatService get instance => _instance ??= HeartbeatService._();
  
  HeartbeatService._();

  Timer? _heartbeatTimer;
  bool _isRunning = false;
  
  /// Start the heartbeat service
  void startHeartbeat() {
    if (_isRunning) {
      developer.log('💓 [HEARTBEAT] Service already running', name: 'HeartbeatService');
      return;
    }
    
    _isRunning = true;
    developer.log('💓 [HEARTBEAT] Starting heartbeat service', name: 'HeartbeatService');
    
    // Send initial heartbeat immediately
    _sendHeartbeat();
    
    // Set up periodic heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendHeartbeat();
    });
  }
  
  /// Stop the heartbeat service
  void stopHeartbeat() {
    if (!_isRunning) {
      developer.log('💓 [HEARTBEAT] Service already stopped', name: 'HeartbeatService');
      return;
    }
    
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    developer.log('💓 [HEARTBEAT] Stopped heartbeat service', name: 'HeartbeatService');
  }
  
  /// Send a single heartbeat request
  Future<void> _sendHeartbeat() async {
    try {
      developer.log('💓 [HEARTBEAT] Sending heartbeat...', name: 'HeartbeatService');
      
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        developer.log('❌ [HEARTBEAT] No auth token available', name: 'HeartbeatService');
        return;
      }
      
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/users/heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        developer.log('💓 [HEARTBEAT] Heartbeat sent successfully', name: 'HeartbeatService');
      } else {
        developer.log('❌ [HEARTBEAT] Heartbeat failed with status: ${response.statusCode}', name: 'HeartbeatService');
      }
    } catch (e) {
      developer.log('❌ [HEARTBEAT] Error sending heartbeat: $e', name: 'HeartbeatService');
      
      // Don't log detailed errors for network issues to avoid spam
      if (e.toString().contains('Timeout') || e.toString().contains('Connection')) {
        developer.log('💓 [HEARTBEAT] Network issue - will retry next interval', name: 'HeartbeatService');
      } else {
        developer.log('❌ [HEARTBEAT] HTTP error: $e', name: 'HeartbeatService');
      }
    }
  }
  
  /// Get current heartbeat status
  bool get isRunning => _isRunning;
  
  /// Send heartbeat on important user actions
  void sendHeartbeatOnAction(String action) {
    if (_isRunning) {
      developer.log('💓 [HEARTBEAT] Action triggered: $action', name: 'HeartbeatService');
      _sendHeartbeat();
    }
  }
  
  /// Dispose the service
  void dispose() {
    stopHeartbeat();
    developer.log('💓 [HEARTBEAT] Service disposed', name: 'HeartbeatService');
  }
}
