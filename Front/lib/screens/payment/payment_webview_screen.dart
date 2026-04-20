import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/payment_service.dart';
import '../../config/api_config.dart';

/// Payment WebView Screen
/// Opens Paymee payment page in a WebView and handles payment completion
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final String? inscriptionId;
  final double amount;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    this.inscriptionId,
    required this.amount,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late WebViewController _controller;
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  String? _paymentStatus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('[PAYMENT WEBVIEW] Initializing with URL: ${widget.paymentUrl}');
    print('[PAYMENT WEBVIEW] Order ID: ${widget.orderId}');
    print('[PAYMENT WEBVIEW] Amount: ${widget.amount}');
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[PAYMENT WEBVIEW] Page started: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            print('[PAYMENT WEBVIEW] Page finished: $url');
            setState(() => _isLoading = false);

            // Inject JavaScript to listen for Paymee iframe event
            _injectPaymeeEventListener();

            // Check for "/loader" in URL - this indicates payment completion
            if (url.contains('/loader')) {
              print('[PAYMENT WEBVIEW] Detected /loader - payment likely complete');
              _handlePaymentCompletion();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('[PAYMENT WEBVIEW] Navigation request: ${request.url}');
            
            // Check for success/redirect URLs
            if (request.url.contains('/payment/success') || 
                request.url.contains('/payment/cancel')) {
              _handlePaymentCompletion();
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('[PAYMENT WEBVIEW] Error: ${error.description}');
            print('[PAYMENT WEBVIEW] Error type: ${error.errorType}');
            print('[PAYMENT WEBVIEW] Error code: ${error.errorCode}');
            
            // For Paymee sandbox, show error but allow retry
            setState(() {
              _errorMessage = '${error.description} (Code: ${error.errorCode})';
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'PaymeePayment',
        onMessageReceived: (JavaScriptMessage message) {
          print('[PAYMENT WEBVIEW] Received message from Paymee: ${message.message}');
          final data = message.message as Map<String, dynamic>;
          
          // Handle paymee.complete event
          if (data['event'] == 'paymee.complete') {
            print('[PAYMENT WEBVIEW] Payment completion event received');
            _handlePaymentCompletion();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _injectPaymeeEventListener() {
    // Inject JavaScript to listen for Paymee iframe completion event
    _controller.runJavaScript('''
      (function() {
        console.log('Paymee event listener injected');
        
        // Listen for paymee.complete event
        window.addEventListener('paymee.complete', function(event) {
          console.log('paymee.complete event detected:', event);
          PaymeePayment.postMessage({
            event: 'paymee.complete',
            detail: event.detail
          });
        });
        
        // Also check for iframe messages
        window.addEventListener('message', function(event) {
          console.log('Iframe message received:', event);
          if (event.data && event.data.type === 'payment_complete') {
            PaymeePayment.postMessage({
              event: 'paymee.complete',
              detail: event.data
            });
          }
        });
      })();
    ''').then((_) {
      print('[PAYMENT WEBVIEW] JavaScript event listener injected successfully');
    }).catchError((error) {
      print('[PAYMENT WEBVIEW] Error injecting JavaScript: $error');
    });
  }

  Future<void> _handlePaymentCompletion() async {
    if (_isCheckingStatus) return;
    
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      // Poll payment status from backend
      print('[PAYMENT WEBVIEW] Checking payment status for order: ${widget.orderId}');
      
      int attempts = 0;
      const maxAttempts = 10;
      
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        
        final result = await _paymentService.checkPayment(
          orderId: widget.orderId,
        );

        final payment = result['payment'];
        final status = payment['status'];
        
        print('[PAYMENT WEBVIEW] Payment status (attempt $attempts): $status');

        setState(() {
          _paymentStatus = status;
        });

        if (status == 'paid') {
          print('[PAYMENT WEBVIEW] Payment successful!');
          _navigateToResult(success: true);
          return;
        } else if (status == 'failed') {
          print('[PAYMENT WEBVIEW] Payment failed!');
          _navigateToResult(success: false);
          return;
        }

        attempts++;
      }

      // If we reach here, payment is still pending
      print('[PAYMENT WEBVIEW] Payment status still pending after $maxAttempts attempts');
      _navigateToResult(success: false, pending: true);
    } catch (e) {
      print('[PAYMENT WEBVIEW] Error checking payment status: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      _navigateToResult(success: false);
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  void _navigateToResult({required bool success, bool pending = false}) async {
    // If payment was cancelled (not successful), call cancel endpoint
    if (!success && !pending) {
      try {
        await _paymentService.cancelPayment(orderId: widget.orderId);
        print('[PAYMENT WEBVIEW] Payment cancelled on backend');
      } catch (e) {
        print('[PAYMENT WEBVIEW] Error cancelling payment on backend: $e');
      }
    }
    Navigator.pop(context, success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),
          
          // Loading indicator
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading payment page...'),
                ],
              ),
            ),
          
          // Status checking indicator
          if (_isCheckingStatus)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Checking payment status...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          
          // Error message
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Payment',
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
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            _controller.reload();
                          },
                          child: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Open in external browser as fallback
                            launchUrl(Uri.parse(widget.paymentUrl), mode: LaunchMode.externalApplication);
                          },
                          child: const Text('Open in Browser'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}
