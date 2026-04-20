import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Payment Service
/// Handles all payment-related API calls for the DJTrip platform using Stripe
class PaymentService {
  final String _baseUrl;
  final http.Client _client;

  PaymentService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Get authentication token using AuthService
  Future<String?> _getAuthToken() async {
    return await AuthService.getAccessToken();
  }

  /// Create a Stripe Checkout session
  ///
  /// Parameters:
  /// - inscriptionId: Optional booking ID (if paying for existing booking)
  /// - amount: Payment amount in TND
  /// - currency: Currency code (default: 'TND')
  /// - description: Payment description
  ///
  /// Returns: Payment response with session_id and checkout_url
  Future<Map<String, dynamic>> createCheckoutSession({
    String? inscriptionId,
    String? activityId,
    String? activityTitle,
    int? nombreParticipants,
    int? adults,
    int? children,
    required double amount,
    String currency = 'TND',
    required String description,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url = '$_baseUrl/payments/create-checkout-session';
      print('[STRIPE PAYMENT SERVICE] Calling: $url');
      print('[STRIPE PAYMENT SERVICE] Body: ${jsonEncode({
        if (inscriptionId != null) 'inscription_id': inscriptionId,
        if (activityId != null) 'activity_id': activityId,
        if (activityTitle != null) 'activity_title': activityTitle,
        if (nombreParticipants != null) 'nombre_participants': nombreParticipants,
        if (adults != null) 'adults': adults,
        if (children != null) 'children': children,
        'amount': amount,
        'currency': currency,
        'description': description,
      })}');

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (inscriptionId != null) 'inscription_id': inscriptionId,
          if (activityId != null) 'activity_id': activityId,
          if (activityTitle != null) 'activity_title': activityTitle,
          if (nombreParticipants != null) 'nombre_participants': nombreParticipants,
          if (adults != null) 'adults': adults,
          if (children != null) 'children': children,
          'amount': amount,
          'currency': currency,
          'description': description,
        }),
      );

      print('[STRIPE PAYMENT SERVICE] Response status: ${response.statusCode}');
      print('[STRIPE PAYMENT SERVICE] Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        print('[STRIPE PAYMENT] Checkout session created successfully');
        return data['payment'];
      } else {
        print('[STRIPE PAYMENT SERVICE] Failed - status: ${response.statusCode}, success: ${data['success']}, message: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to create checkout session');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error creating checkout session: $e');
      rethrow;
    }
  }

  /// Launch Stripe Checkout URL in browser or external app
  /// 
  /// Parameters:
  /// - checkoutUrl: Stripe Checkout URL from backend
  /// 
  /// Returns: true if launched successfully, false otherwise
  Future<bool> launchStripeCheckout(String checkoutUrl) async {
    try {
      print('[STRIPE PAYMENT] Launching checkout URL: $checkoutUrl');
      final uri = Uri.parse(checkoutUrl);
      
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Open in external browser
        );
        print('[STRIPE PAYMENT] Checkout launched: $launched');
        return launched;
      } else {
        print('[STRIPE PAYMENT] Could not launch checkout URL');
        return false;
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error launching checkout: $e');
      return false;
    }
  }

  /// Manually complete payment (for testing without webhooks)
  /// 
  /// This simulates the Stripe webhook for local development
  /// 
  /// Parameters:
  /// - sessionId: Stripe session ID from checkout
  /// 
  /// Returns: Updated payment status
  Future<Map<String, dynamic>> completePayment({
    required String sessionId,
  }) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/payments/complete-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'session_id': sessionId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] Payment completed manually');
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to complete payment');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error completing payment: $e');
      rethrow;
    }
  }

  /// Cancel a pending payment
  ///
  /// Parameters:
  /// - orderId: Order ID from payment creation
  ///
  /// Returns: Updated payment status
  Future<Map<String, dynamic>> cancelPayment({
    required String orderId,
  }) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/payments/cancel-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'order_id': orderId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[PAYMENT SERVICE] Payment cancelled successfully');
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to cancel payment');
      }
    } catch (e) {
      print('[PAYMENT SERVICE] Error cancelling payment: $e');
      rethrow;
    }
  }

  /// Check payment status
  ///
  /// Parameters:
  /// - sessionId: Stripe session ID from checkout
  /// - orderId: Order ID from payment creation (alternative to sessionId)
  ///
  /// Returns: Payment status and details
  Future<Map<String, dynamic>> checkPayment({
    String? sessionId,
    String? orderId,
  }) async {
    try {
      if (sessionId == null && orderId == null) {
        throw Exception('Either sessionId or orderId is required');
      }

      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('Authentication token not found');
      }

      final queryParams = {
        if (sessionId != null) 'session_id': sessionId,
        if (orderId != null) 'order_id': orderId,
      };

      final uri = Uri.parse('$_baseUrl/payments/check')
          .replace(queryParameters: queryParams);

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      print('[STRIPE PAYMENT SERVICE] Check payment response status: ${response.statusCode}');
      print('[STRIPE PAYMENT SERVICE] Check payment response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] Payment status retrieved');
        print('[STRIPE PAYMENT] Payment data: ${data['payment']}');
        return {
          'payment': data['payment'],
          'inscription': data['inscription'],
        };
      } else {
        print('[STRIPE PAYMENT SERVICE] Failed - status: ${response.statusCode}, success: ${data['success']}, message: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to check payment');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error checking payment: $e');
      rethrow;
    }
  }

  /// Get user's payment history
  Future<List<Map<String, dynamic>>> getUserPayments() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/payments/user'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] User payments retrieved');
        return List<Map<String, dynamic>>.from(data['payments']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch payments');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error fetching user payments: $e');
      rethrow;
    }
  }

  /// Get user's wallet balance
  Future<double> getWalletBalance() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/payments/wallet'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] Wallet balance retrieved');
        return (data['wallet_balance'] ?? 0).toDouble();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch wallet balance');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error fetching wallet balance: $e');
      rethrow;
    }
  }

  /// Accept reservation (for organizers)
  Future<void> acceptReservation(String inscriptionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/payments/$inscriptionId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] Reservation accepted successfully');
      } else {
        throw Exception(data['message'] ?? 'Failed to accept reservation');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error accepting reservation: $e');
      rethrow;
    }
  }

  /// Reject reservation and refund user via Stripe (for organizers)
  Future<Map<String, dynamic>> rejectReservation({
    required String inscriptionId,
    String? reason,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/payments/$inscriptionId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (reason != null) 'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[STRIPE PAYMENT] Reservation rejected and refunded successfully');
        return {
          'refund_amount': data['refund_amount'],
          'currency': data['currency'],
          'new_wallet_balance': data['new_wallet_balance'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to reject reservation');
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error rejecting reservation: $e');
      rethrow;
    }
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
