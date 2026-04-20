import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/payment_service.dart';
import '../../services/inscription_service.dart';
import '../../config/api_config.dart';
import '../tourist/booking_detail_screen.dart';
import '../../models/inscription_model.dart';

/// Stripe Payment Screen
/// Creates a Stripe Checkout session and displays it in an in-app webview
/// Handles payment completion by checking status after redirect
class StripePaymentScreen extends StatefulWidget {
  final String? inscriptionId;
  final String? activityId;
  final String? activityTitle;
  final int? nombreParticipants;
  final int? adults;
  final int? children;
  final double amount;
  final String currency;
  final String description;

  const StripePaymentScreen({
    super.key,
    this.inscriptionId,
    this.activityId,
    this.activityTitle,
    this.nombreParticipants,
    this.adults,
    this.children,
    required this.amount,
    this.currency = 'USD',
    required this.description,
  });

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  bool _shouldCancelCheck = false;
  String? _sessionId;
  String? _orderId;
  String? _inscriptionId;
  String? _checkoutUrl;
  bool _showWebView = false;
  String? _errorMessage;
  String? _paymentStatus;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    print('[STRIPE PAYMENT] Initializing payment: ${widget.amount} ${widget.currency}');
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print('[STRIPE PAYMENT] Navigation request: ${request.url}');
            // Prevent loading cancel/success URLs (they don't exist on backend)
            if (request.url.contains('/payment/cancel') || request.url.contains('/payment/success')) {
              print('[STRIPE PAYMENT] Payment redirect detected, closing webview');
              // Trigger status check immediately when redirect is detected
              setState(() {
                _showWebView = false;
              });
              _checkPaymentStatus();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            print('[STRIPE PAYMENT] Page finished: $url');
          },
        ),
      );
    _createCheckoutSession();
  }

  Future<void> _createCheckoutSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[STRIPE PAYMENT] Creating checkout session...');
      
      final response = await _paymentService.createCheckoutSession(
        inscriptionId: widget.inscriptionId,
        activityId: widget.activityId,
        activityTitle: widget.activityTitle,
        nombreParticipants: widget.nombreParticipants,
        adults: widget.adults,
        children: widget.children,
        amount: widget.amount,
        currency: widget.currency,
        description: widget.description,
      );

      print('[STRIPE PAYMENT] Checkout session created: ${response['session_id']}');
      print('[STRIPE PAYMENT] Checkout URL: ${response['checkout_url']}');

      setState(() {
        _sessionId = response['session_id'];
        _orderId = response['order_id'];
        _checkoutUrl = response['checkout_url'];
        _isLoading = false;
        _showWebView = true;
      });

      // Load the checkout URL in the webview
      _webViewController.loadRequest(Uri.parse(_checkoutUrl!));
    } catch (e) {
      print('[STRIPE PAYMENT] Error creating checkout session: $e');
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_isCheckingStatus || _sessionId == null) return;
    
    setState(() {
      _isCheckingStatus = true;
      _shouldCancelCheck = false;
    });

    try {
      print('[STRIPE PAYMENT] Checking payment status for session: $_sessionId');
      
      int attempts = 0;
      const maxAttempts = 20;
      
      while (attempts < maxAttempts && !_shouldCancelCheck) {
        await Future.delayed(const Duration(seconds: 3));
        
        if (_shouldCancelCheck) {
          print('[STRIPE PAYMENT] Status check cancelled by user');
          break;
        }
        
        final result = await _paymentService.checkPayment(
          sessionId: _sessionId,
        );

        final payment = result['payment'];
        final status = payment['status'];
        final inscription = result['inscription'];
        final inscriptionId = inscription != null ? inscription['id'] : null;

        print('[STRIPE PAYMENT] Payment status (attempt $attempts): $status');
        print('[STRIPE PAYMENT] Inscription ID: $inscriptionId');

        setState(() {
          _paymentStatus = status;
          if (inscriptionId != null) {
            _inscriptionId = inscriptionId.toString();
          }
        });

        if (status == 'paid') {
          print('[STRIPE PAYMENT] Payment successful!');
          _navigateToResult(success: true);
          return;
        } else if (status == 'failed' || status == 'cancelled') {
          print('[STRIPE PAYMENT] Payment $status!');
          _navigateToResult(success: false);
          return;
        }

        attempts++;
      }

      // If we reach here, payment is still pending or was cancelled
      if (_shouldCancelCheck) {
        print('[STRIPE PAYMENT] Status check cancelled, showing webview');
        setState(() {
          _showWebView = true;
        });
      } else {
        print('[STRIPE PAYMENT] Payment status still pending after $maxAttempts attempts');
        _navigateToResult(success: false, pending: true);
      }
    } catch (e) {
      print('[STRIPE PAYMENT] Error checking payment status: $e');
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e.toString());
      });
    } finally {
      setState(() {
        _isCheckingStatus = false;
        _shouldCancelCheck = false;
      });
    }
  }

  void _navigateToResult({required bool success, bool pending = false}) {
    if (success && _inscriptionId != null) {
      // Navigate directly to booking detail screen on successful payment
      _navigateToBookingDetail();
    } else {
      setState(() {
        _paymentStatus = success ? 'paid' : (pending ? 'pending' : 'failed');
        _showWebView = false;
        _isCheckingStatus = false;
      });
    }
  }

  void _retryPayment() {
    _createCheckoutSession();
  }

  String _getUserFriendlyErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    // Check for server errors
    if (errorLower.contains('server') || errorLower.contains('500') || errorLower.contains('502') || errorLower.contains('503')) {
      return 'Server error. Please try again later.';
    }

    // Check for network errors
    if (errorLower.contains('network') || errorLower.contains('connection') || errorLower.contains('timeout')) {
      return 'Network error. Please check your internet connection.';
    }

    // Check for authentication errors
    if (errorLower.contains('unauthorized') || errorLower.contains('401') || errorLower.contains('403')) {
      return 'Authentication error. Please log in again.';
    }

    // Check for not found errors
    if (errorLower.contains('not found') || errorLower.contains('404')) {
      return 'Resource not found. Please try again.';
    }

    // Default message for unknown errors
    return 'An error occurred. Please try again.';
  }

  Future<void> _completePaymentManually() async {
    if (_sessionId == null) return;
    
    try {
      print('[STRIPE PAYMENT] Manually completing payment for session: $_sessionId');
      final result = await _paymentService.completePayment(sessionId: _sessionId!);
      
      print('[STRIPE PAYMENT] Payment completed successfully');
      
      // Show success screen
      setState(() {
        _showWebView = false;
        _isCheckingStatus = false;
      });
      
      _navigateToResult(success: true);
    } catch (e) {
      print('[STRIPE PAYMENT] Error completing payment manually: $e');
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e.toString());
        _showWebView = false;
      });
    }
  }

  void _cancelPayment() {
    // Cancel any ongoing operations
    _shouldCancelCheck = true;

    // Reset state before popping
    setState(() {
      _isLoading = false;
      _isCheckingStatus = false;
      _showWebView = false;
      _errorMessage = null;
    });

    // Pop the screen
    if (Navigator.canPop(context)) {
      Navigator.pop(context, {'success': false, 'cancelled': true});
    }
  }

  Future<void> _navigateToBookingDetail() async {
    if (_inscriptionId == null) {
      Navigator.pop(context, {'success': true});
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Fetch the complete inscription
      final inscription = await InscriptionService.getInscriptionById(_inscriptionId!);

      if (!mounted) return;

      if (inscription == null) {
        setState(() {
          _errorMessage = 'Booking not found. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Navigate to booking detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(inscription: inscription),
        ),
      );
    } catch (e) {
      print('[STRIPE PAYMENT] Error fetching inscription: $e');
      if (mounted) {
        setState(() {
          _errorMessage = _getUserFriendlyErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Navigate to Tourist Main Screen with My Activities tab (index 1)
            Navigator.popUntil(context, (route) => route.isFirst);
            Navigator.pushReplacementNamed(
              context,
              '/tourist/main',
              arguments: {'initialIndex': 2},
            );
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating payment session...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                      // Navigate to Tourist Main Screen with My Activities tab (index 2)
                      Navigator.pushReplacementNamed(context, '/tourist-main', arguments: 2);
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_paymentStatus == 'pending') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty,
                      color: Colors.orange,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Pending',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment verification timed out',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: ${_orderId ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _paymentStatus = null;
                          _errorMessage = null;
                        });
                        _checkPaymentStatus();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _paymentStatus = null;
                          _errorMessage = null;
                          _sessionId = null;
                          _orderId = null;
                          _checkoutUrl = null;
                        });
                        _createCheckoutSession();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Return to Payment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_paymentStatus == 'paid') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your payment has been processed successfully',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: ${_orderId ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToBookingDetail,
                      icon: const Icon(Icons.check),
                      label: const Text('View Booking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_paymentStatus == 'failed') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Failed',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We couldn\'t process your payment',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: ${_orderId ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _retryPayment,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancelPayment,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_showWebView && _checkoutUrl != null) {
      return Column(
        children: [
          // WebView for Stripe checkout
          Expanded(
            child: WebViewWidget(
              controller: _webViewController,
            ),
          ),
        ],
      );
    }

    if (_isCheckingStatus) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Checking Payment Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please wait while we verify your payment...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_paymentStatus != null)
                    Text(
                      'Current status: ${_paymentStatus!.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const Center(
      child: Text('Initializing payment...'),
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}
