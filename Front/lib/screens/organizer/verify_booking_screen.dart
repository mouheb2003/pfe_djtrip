import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import 'package:intl/intl.dart';

class VerifyBookingScreen extends StatefulWidget {
  const VerifyBookingScreen({super.key});

  @override
  State<VerifyBookingScreen> createState() => _VerifyBookingScreenState();
}

class _VerifyBookingScreenState extends State<VerifyBookingScreen> {
  late MobileScannerController _scannerController;
  bool _isScannerInitialized = false;
  bool _isLoading = false;
  String? _scannedCode;
  InscriptionModel? _verifiedBooking;
  VerificationStatus? _verificationStatus;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      autoStart: true,
      torchEnabled: false,
    );
    // Scanner is initialized on widget build
    setState(() => _isScannerInitialized = true);
  }

  Future<void> _verifyBooking(String bookingCode) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _scannedCode = bookingCode;
      _verificationStatus = null;
      _statusMessage = null;
    });

    try {
      // Fetch booking by ID from QR code
      final booking = await InscriptionService.getInscriptionById(bookingCode);

      if (booking == null) {
        setState(() {
          _verificationStatus = VerificationStatus.invalid;
          _statusMessage = 'Booking not found';
        });
        return;
      }

      // Check if booking is already used/verified
      if (booking.statut == 'verifie' || booking.statut == 'verified') {
        setState(() {
          _verifiedBooking = booking;
          _verificationStatus = VerificationStatus.alreadyUsed;
          _statusMessage = 'This booking has already been verified';
        });
        return;
      }

      // Check if booking is approved
      if (booking.statut != 'approuvee' && booking.statut != 'approved') {
        setState(() {
          _verifiedBooking = booking;
          _verificationStatus = VerificationStatus.notApproved;
          _statusMessage =
              'Booking must be approved first. Current status: ${booking.statut}';
        });
        return;
      }

      // Booking is valid and can be verified
      setState(() {
        _verifiedBooking = booking;
        _verificationStatus = VerificationStatus.valid;
        _statusMessage = 'Booking verified successfully!';
      });
    } catch (e) {
      setState(() {
        _verificationStatus = VerificationStatus.error;
        _statusMessage = 'Error verifying booking: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmVerification() async {
    if (_verifiedBooking == null) return;

    setState(() => _isLoading = true);

    try {
      // Call API to mark booking as verified
      final success = await InscriptionService.verifyInscription(
        _verifiedBooking!.id,
      );

      if (success) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Verification Confirmed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Details:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Tourist:',
                    _verifiedBooking?.touriste?['fullname'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Participants:',
                    '${_verifiedBooking?.nombreParticipants ?? 0}',
                  ),
                  _buildDetailRow(
                    'Total Price:',
                    '\$${_verifiedBooking?.prixTotal?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  child: const Text('Scan Another'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to confirm verification'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _scannedCode = null;
      _verifiedBooking = null;
      _verificationStatus = null;
      _statusMessage = null;
    });
    _scannerController.start();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Booking'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _verificationStatus == null
          ? _buildScannerView()
          : _buildVerificationResultView(),
    );
  }

  Widget _buildScannerView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Scanner
          Container(
            height: 400,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _isScannerInitialized
                  ? MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null &&
                              barcode.rawValue != _scannedCode) {
                            _verifyBooking(barcode.rawValue!);
                            _scannerController.stop();
                            break;
                          }
                        }
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Initializing camera...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Instructions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Scanning Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Point camera at QR code on booking ticket\n'
                  '• Wait for automatic scanning\n'
                  '• Booking will be verified instantly\n'
                  '• Ensure good lighting condition',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),

          // Torch Control
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  icon: Icon(
                    _scannerController.torchEnabled
                        ? Icons.flash_on
                        : Icons.flash_off,
                  ),
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                    setState(() {});
                  },
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  icon: const Icon(Icons.qr_code_2),
                  onPressed: () {
                    // Could open gallery or manual entry
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationResultView() {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;
    String statusTitle = 'Unknown';

    switch (_verificationStatus) {
      case VerificationStatus.valid:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'Valid Booking';
        break;
      case VerificationStatus.invalid:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTitle = 'Invalid Booking';
        break;
      case VerificationStatus.alreadyUsed:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusTitle = 'Already Used';
        break;
      case VerificationStatus.notApproved:
        statusColor = Colors.amber;
        statusIcon = Icons.schedule;
        statusTitle = 'Not Approved';
        break;
      case VerificationStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusTitle = 'Verification Error';
        break;
      default:
        break;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: statusColor, width: 2)),
            ),
            child: Column(
              children: [
                Icon(statusIcon, size: 64, color: statusColor),
                const SizedBox(height: 16),
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // Booking Details (if available)
          if (_verifiedBooking != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailField('Booking ID:', _scannedCode ?? 'N/A'),
                      _buildDetailField(
                        'Tourist:',
                        _verifiedBooking?.touriste?['fullname'] ?? 'N/A',
                      ),
                      _buildDetailField(
                        'Activity:',
                        _verifiedBooking?.activite?['titre'] ?? 'N/A',
                      ),
                      _buildDetailField(
                        'Participants:',
                        '${_verifiedBooking?.nombreParticipants ?? 0} people',
                      ),
                      _buildDetailField(
                        'Total Price:',
                        '\$${_verifiedBooking?.prixTotal?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                      _buildDetailField(
                        'Booking Date:',
                        _verifiedBooking?.dateDemande != null
                            ? DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(_verifiedBooking!.dateDemande!)
                            : 'N/A',
                      ),
                      _buildDetailField(
                        'Status:',
                        _verifiedBooking?.statut ?? 'N/A',
                        statusColor: statusColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_verificationStatus == VerificationStatus.valid)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _confirmVerification,
                    icon: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isLoading ? 'Confirming...' : 'Confirm Verification',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetScanner,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Scan Another Booking'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: statusColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

enum VerificationStatus { valid, invalid, alreadyUsed, notApproved, error }
