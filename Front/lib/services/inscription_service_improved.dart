import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'api_client.dart';
import 'checkin_offline_service.dart';

/// Service amélioré pour la gestion des inscriptions avec retry et offline support
class InscriptionServiceImproved {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static final CheckinOfflineService _offlineService = CheckinOfflineService();

  /// Valide un QR code avec retry automatique
  static Future<Map<String, dynamic>> validateQrBookingWithRetry(
    String qrData,
  ) async {
    int retryCount = 0;

    print('[QR SERVICE] Starting validation for QR: $qrData');

    while (retryCount <= _maxRetries) {
      try {
        print('[QR SERVICE] Attempt ${retryCount + 1} of ${_maxRetries + 1}');

        final res =
            await ApiClient.post('/inscriptions/qr/validate', {
              'qrData': qrData,
            }).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('[QR SERVICE] Request timed out after 10 seconds');
                throw Exception('Request timeout');
              },
            );

        print('[QR SERVICE] Status code: ${res.statusCode}');
        print('[QR SERVICE] Response body: ${res.body}');

        if (res.statusCode == 200) {
          final body = _decodeObject(res.body);
          print('[QR SERVICE] Parsed body: $body');
          print('[QR SERVICE] Success: ${body['success']}');
          print('[QR SERVICE] Data: ${body['data']}');

          return {
            'success': true,
            'statusCode': res.statusCode,
            'message': body['message'] ?? 'Validation successful',
            'code': body['code'],
            'data': body['data'],
          };
        } else if (res.statusCode >= 500) {
          // Server error, retry
          print('[QR SERVICE] Server error, retrying...');
          retryCount++;
          if (retryCount <= _maxRetries) {
            await Future.delayed(_retryDelay * retryCount);
            continue;
          }
        }

        // Client error or max retries exceeded
        final body = _decodeObject(res.body);
        print('[QR SERVICE] Error response: $body');

        return {
          'success': false,
          'statusCode': res.statusCode,
          'message': body['message'] ?? 'Validation failed',
          'code': body['code'],
        };
      } catch (e) {
        print('[QR SERVICE] Exception: $e');
        print('[QR SERVICE] Exception type: ${e.runtimeType}');

        retryCount++;
        if (retryCount <= _maxRetries) {
          print(
            '[QR SERVICE] Retrying in ${_retryDelay.inSeconds * retryCount} seconds...',
          );
          await Future.delayed(_retryDelay * retryCount);
          continue;
        }

        // Check if offline
        if (e.toString().contains('SocketException') ||
            e.toString().contains('NetworkException') ||
            e.toString().contains('timeout')) {
          print('[QR SERVICE] Network error detected');
          return {
            'success': false,
            'statusCode': 0,
            'message': 'Network error. Check-in queued for later sync.',
            'code': 'OFFLINE',
            'isOffline': true,
          };
        }

        return {
          'success': false,
          'statusCode': 500,
          'message': 'Error validating QR: $e',
          'code': 'ERROR',
        };
      }
    }

    return {
      'success': false,
      'statusCode': 500,
      'message': 'Max retries exceeded',
      'code': 'MAX_RETRIES',
    };
  }

  /// Marque une inscription comme utilisée avec retry et offline support
  static Future<Map<String, dynamic>> markInscriptionAsUsedImproved({
    required String inscriptionId,
    required String activityTitle,
    required String touristName,
  }) async {
    int retryCount = 0;

    while (retryCount <= _maxRetries) {
      try {
        final res = await ApiClient.put(
          '/inscriptions/$inscriptionId/verifier',
          {'statut': 'verified'},
        );

        if (res.statusCode == 200) {
          final body = _decodeObject(res.body);

          // Success - remove from offline queue if exists
          await _offlineService.removeFromQueue(inscriptionId);

          return {
            'success': true,
            'statusCode': res.statusCode,
            'message': body['message'] ?? 'Check-in successful',
            'code': body['code'],
            'data': body['data'],
          };
        } else if (res.statusCode == 400) {
          final body = _decodeObject(res.body);
          if (body['code'] == 'ALREADY_VERIFIED' ||
              body['code'] == 'STATUS_CHANGED') {
            // Already verified - remove from queue
            await _offlineService.removeFromQueue(inscriptionId);

            return {
              'success': false,
              'statusCode': res.statusCode,
              'message': body['message'] ?? 'Already verified',
              'code': body['code'],
            };
          }
        } else if (res.statusCode >= 500) {
          // Server error, retry
          retryCount++;
          if (retryCount <= _maxRetries) {
            await Future.delayed(_retryDelay * retryCount);
            continue;
          }
        }

        // Client error
        final body = _decodeObject(res.body);
        return {
          'success': false,
          'statusCode': res.statusCode,
          'message': body['message'] ?? 'Check-in failed',
          'code': body['code'],
        };
      } catch (e) {
        retryCount++;

        if (retryCount <= _maxRetries) {
          await Future.delayed(_retryDelay * retryCount);
          continue;
        }

        // Check if offline - queue for later
        if (e.toString().contains('SocketException') ||
            e.toString().contains('NetworkException')) {
          await _offlineService.addToQueue(
            inscriptionId: inscriptionId,
            activityTitle: activityTitle,
            touristName: touristName,
            timestamp: DateTime.now(),
          );

          return {
            'success': false,
            'statusCode': 0,
            'message': 'Offline - Check-in queued for sync',
            'code': 'OFFLINE_QUEUED',
            'isOffline': true,
          };
        }

        return {
          'success': false,
          'statusCode': 500,
          'message': 'Error marking check-in: $e',
          'code': 'ERROR',
        };
      }
    }

    return {
      'success': false,
      'statusCode': 500,
      'message': 'Max retries exceeded',
      'code': 'MAX_RETRIES',
    };
  }

  /// Sync les check-ins offline
  static Future<Map<String, dynamic>> syncOfflineCheckins() async {
    try {
      final pending = await _offlineService.getPendingCheckins();

      if (pending.isEmpty) {
        return {
          'success': true,
          'synced': 0,
          'failed': 0,
          'message': 'No pending check-ins to sync',
        };
      }

      int synced = 0;
      int failed = 0;

      for (final checkin in pending) {
        final result = await markInscriptionAsUsedImproved(
          inscriptionId: checkin['inscriptionId'] as String,
          activityTitle: checkin['activityTitle'] as String,
          touristName: checkin['touristName'] as String,
        );

        if (result['success'] == true) {
          synced++;
        } else if (result['code'] == 'ALREADY_VERIFIED') {
          synced++; // Already verified, count as success
        } else {
          failed++;
          await _offlineService.incrementRetryCount(
            checkin['inscriptionId'] as String,
          );
        }
      }

      await _offlineService.saveLastSyncTimestamp();

      return {
        'success': true,
        'synced': synced,
        'failed': failed,
        'message': 'Sync completed: $synced synced, $failed failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error syncing offline check-ins: $e',
      };
    }
  }

  /// Récupère le nombre de check-ins en attente
  static Future<int> getPendingCheckinCount() async {
    await _offlineService.initialize();
    return _offlineService.pendingCount;
  }

  /// Décode un objet JSON
  static Map<String, dynamic> _decodeObject(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
