import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service_improved.dart';
import '../../services/fcm_notification_service.dart';

/// Écran amélioré de vérification de booking par QR code
/// PRODUCTION READY avec gestion d'erreurs, offline, et UI améliorée
class VerifyBookingScreenImproved extends StatefulWidget {
  const VerifyBookingScreenImproved({super.key});

  @override
  State<VerifyBookingScreenImproved> createState() => _VerifyBookingScreenImprovedState();
}

class _VerifyBookingScreenImprovedState extends State<VerifyBookingScreenImproved> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isScanning = true;
  bool _isConfirming = false;
  String? _lastScannedCode;
  
  _VerificationResult? _lastResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    await FcmNotificationService().initialize();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _onScanned(String code) async {
    if (_isLoading || code.trim().isEmpty) return;
    if (_lastScannedCode == code) return;

    setState(() {
      _lastScannedCode = code;
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();
    await _scannerController.stop();
    setState(() => _isScanning = false);

    await _validateAndRoute(code);
  }

  Future<void> _validateAndRoute(String input) async {
    final result = await InscriptionServiceImproved.validateQrBookingWithRetry(input);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final bookingData = result['data']['booking'];
      final booking = InscriptionModel.fromJson(bookingData);

      setState(() {
        _lastResult = _VerificationResult(
          booking: booking,
          status: _VerificationStatus.valid,
          message: result['message'] ?? 'Valid booking',
        );
      });
    } else {
      final code = result['code'] as String?;
      final message = result['message'] as String?;

      setState(() {
        _lastResult = _VerificationResult(
          status: _statusFromCode(code),
          message: message ?? 'Verification failed',
        );
        _errorMessage = message;
      });

      HapticFeedback.heavyImpact();
    }
  }

  _VerificationStatus _statusFromCode(String? code) {
    switch (code) {
      case 'ALREADY_USED':
      case 'ALREADY_VERIFIED':
        return _VerificationStatus.alreadyUsed;
      case 'UNAUTHORIZED':
        return _VerificationStatus.unauthorized;
      case 'ACTIVITY_EXPIRED':
        return _VerificationStatus.expired;
      case 'NOT_CONFIRMED':
      case 'NOT_APPROVED':
        return _VerificationStatus.notApproved;
      case 'OFFLINE':
        return _VerificationStatus.offline;
      default:
        return _VerificationStatus.invalid;
    }
  }

  Future<void> _confirmAdmission() async {
    if (_isConfirming || _lastResult?.booking == null) return;

    setState(() => _isConfirming = true);

    try {
      final booking = _lastResult!.booking;
      
      final result = await InscriptionServiceImproved.markInscriptionAsUsedImproved(
        inscriptionId: booking.id,
        activityTitle: booking.activity?['titre'] ?? 'Activity',
        touristName: booking.tourist?['fullname'] ?? 'Tourist',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        HapticFeedback.lightImpact();
        
        setState(() {
          _lastResult = _lastResult!.copyWith(
            status: _VerificationStatus.verified,
            message: 'Check-in confirmed successfully',
          );
        });

        _showSuccessSnackBar();
        _resetScanner();
      } else if (result['code'] == 'ALREADY_VERIFIED') {
        HapticFeedback.mediumImpact();
        
        setState(() {
          _lastResult = _lastResult!.copyWith(
            status: _VerificationStatus.alreadyUsed,
            message: 'Already verified',
          );
        });

        _showWarningSnackBar('Already verified');
      } else if (result['isOffline'] == true) {
        HapticFeedback.mediumImpact();
        
        setState(() {
          _lastResult = _lastResult!.copyWith(
            status: _VerificationStatus.offline,
            message: 'Offline - Queued for sync',
          );
        });

        _showInfoSnackBar('Offline - Check-in queued for sync');
      } else {
        HapticFeedback.heavyImpact();
        
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to confirm';
        });

        _showErrorSnackBar(result['message'] ?? 'Failed to confirm admission');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _errorMessage = 'Error: $e');
      _showErrorSnackBar('Error confirming admission');
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _lastResult = null;
      _errorMessage = null;
      _isScanning = true;
    });
    _scannerController.start();
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Check-in confirmed successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _confirmAdmission(),
        ),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Booking'),
        actions: [
          if (_lastResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScanner,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lastResult == null
              ? _buildScannerView()
              : _buildResultView(),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        Expanded(
          child: _isScanning
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final String code = capture.barcodes.first.rawValue ?? '';
                    _onScanned(code);
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Scanner paused'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isScanning = true);
                          _scannerController.start();
                        },
                        child: const Text('Resume'),
                      ),
                    ],
                  ),
                ),
        ),
        _buildManualEntry(),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualCodeController,
              decoration: const InputDecoration(
                hintText: 'Enter booking ID or scan QR',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final code = _manualCodeController.text.trim();
              if (code.isNotEmpty) {
                _validateAndRoute(code);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _lastResult!;
    final booking = result.booking;
    final status = result.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(status),
          if (booking != null) _buildBookingCard(booking, status),
          if (status == _VerificationStatus.valid) _buildConfirmButton(),
          if (status == _VerificationStatus.verified) _buildVerifiedCard(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetScanner,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text('Scan Another'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(_VerificationStatus status) {
    final (icon, color, title, message) = switch (status) {
      _VerificationStatus.valid => (
          Icons.check_circle,
          Colors.green,
          'Valid Booking',
          'Ready for check-in',
        ),
      _VerificationStatus.verified => (
          Icons.verified,
          Colors.green,
          'Verified',
          'Check-in confirmed',
        ),
      _VerificationStatus.alreadyUsed => (
          Icons.history,
          Colors.orange,
          'Already Verified',
          'This booking was already checked in',
        ),
      _VerificationStatus.unauthorized => (
          Icons.lock,
          Colors.red,
          'Unauthorized',
          'You are not authorized to verify this booking',
        ),
      _VerificationStatus.expired => (
          Icons.schedule,
          Colors.red,
          'Expired',
          'This activity has already passed',
        ),
      _VerificationStatus.notApproved => (
          Icons.pending,
          Colors.orange,
          'Not Approved',
          'This booking has not been approved yet',
        ),
      _VerificationStatus.offline => (
          Icons.cloud_off,
          Colors.blue,
          'Offline',
          'Check-in queued for sync',
        ),
      _VerificationStatus.invalid => (
          Icons.error,
          Colors.red,
          'Invalid',
          _errorMessage ?? 'Invalid QR code or booking',
        ),
    };

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(InscriptionModel booking, _VerificationStatus status) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.activity?['titre'] ?? 'Unknown Activity',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Tourist', booking.tourist?['fullname'] ?? 'Unknown'),
            _buildInfoRow('Date', booking.activity?['date_debut'] ?? 'Unknown'),
            _buildInfoRow('Status', booking.statut ?? 'Unknown'),
            const SizedBox(height: 16),
            if (status == _VerificationStatus.valid)
              const Text(
                'Confirm admission to mark as checked-in',
                style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: _isConfirming ? null : _confirmAdmission,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isConfirming
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle),
                  SizedBox(width: 8),
                  Text(
                    'Confirm Admission',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildVerifiedCard() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.green.withOpacity(0.1),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.verified_user, size: 48, color: Colors.green),
            SizedBox(height: 8),
            Text(
              'Check-in Confirmed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Guest can now enter the activity',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

enum _VerificationStatus {
  valid,
  verified,
  alreadyUsed,
  unauthorized,
  expired,
  notApproved,
  offline,
  invalid,
}

class _VerificationResult {
  final InscriptionModel? booking;
  final _VerificationStatus status;
  final String message;

  _VerificationResult({
    this.booking,
    required this.status,
    required this.message,
  });

  _VerificationResult copyWith({
    InscriptionModel? booking,
    _VerificationStatus? status,
    String? message,
  }) {
    return _VerificationResult(
      booking: booking ?? this.booking,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}
