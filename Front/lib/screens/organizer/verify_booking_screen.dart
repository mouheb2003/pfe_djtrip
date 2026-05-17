import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui' as ui;

import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../../theme/app_theme.dart';

enum _VerifyView { scanner, manualEntry, manualSuccess, manualFailure }

class VerifyBookingScreen extends StatefulWidget {
  const VerifyBookingScreen({super.key});

  @override
  State<VerifyBookingScreen> createState() => _VerifyBookingScreenState();
}

class _VerifyBookingScreenState extends State<VerifyBookingScreen> {
  late final MobileScannerController _scannerController;
  final TextEditingController _manualCodeController = TextEditingController();

  bool _isLoading = false;
  bool _userPressedButton = false;
  String? _lastScannedCode;
  _VerifyView _view = _VerifyView.scanner;
  _VerificationPayload? _lastResult;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      autoStart: true,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  VerificationStatus _statusFromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'INVALID_TOKEN':
      case 'BOOKING_NOT_FOUND':
        return VerificationStatus.invalid;
      case 'NOT_CONFIRMED':
        return VerificationStatus.notApproved;
      case 'ALREADY_USED':
        return VerificationStatus.alreadyUsed;
      case 'ACTIVITY_EXPIRED':
        return VerificationStatus.expired;
      case 'UNAUTHORIZED':
        return VerificationStatus.unauthorized;
      default:
        return VerificationStatus.error;
    }
  }

  Future<_VerificationPayload> _validateBooking(String rawInput) async {
    final input = rawInput.trim();

    Map<String, dynamic> result = await InscriptionService.validateQrBooking(
      input,
    );

    // Manual users can type plain booking IDs. Retry once with QR prefix.
    if (result['success'] != true &&
        (result['code']?.toString().toUpperCase() == 'BOOKING_NOT_FOUND') &&
        !input.startsWith('DJTRIP_BOOKING:')) {
      result = await InscriptionService.validateQrBooking(
        'DJTRIP_BOOKING:$input',
      );
    }

    final bookingData = _asMap(result['booking']);
    final booking = bookingData != null
        ? InscriptionModel.fromJson(bookingData)
        : null;
    final status = result['success'] == true && booking != null
        ? VerificationStatus.valid
        : _statusFromCode(result['code']?.toString());

    return _VerificationPayload(
      status: status,
      message: result['message']?.toString() ?? 'Verification failed',
      booking: booking,
      scannedCode: input,
      source: VerificationSource.scanner,
    );
  }

  Future<void> _onScanned(String code) async {
    if (_isLoading || code.trim().isEmpty) return;
    if (_lastScannedCode == code) return;

    setState(() {
      _lastScannedCode = code;
    });

    await _scannerController.stop();
    await _verifyAndRoute(code, source: VerificationSource.scanner);
  }

  Future<void> _verifyAndRoute(
    String input, {
    required VerificationSource source,
  }) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final payload = await _validateBooking(input);
      final resolved = payload.copyWith(source: source);
      if (!mounted) return;

      setState(() {
        _lastResult = resolved;
        _isLoading = false;
      });

      if (source == VerificationSource.scanner) {
        await _showScannerOutcomeSheet(resolved);
      } else {
        await _scannerController.stop();
        setState(() {
          _view = resolved.status == VerificationStatus.valid
              ? _VerifyView.manualSuccess
              : _VerifyView.manualFailure;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final fallback = _VerificationPayload(
        status: VerificationStatus.error,
        message: 'Error verifying booking: $e',
        booking: null,
        scannedCode: input,
        source: source,
      );
      setState(() {
        _lastResult = fallback;
        _isLoading = false;
        if (source == VerificationSource.manual) {
          _view = _VerifyView.manualFailure;
        }
      });
      if (source == VerificationSource.scanner) {
        await _showScannerOutcomeSheet(fallback);
      }
    }
  }

  Future<void> _showScannerOutcomeSheet(_VerificationPayload payload) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: SafeArea(
            top: false,
            child: payload.status == VerificationStatus.valid
                ? _buildScannerValidSheet(payload)
                : _buildScannerInvalidSheet(payload),
          ),
        );
      },
    );

    if (_view == _VerifyView.scanner) {
      _resetScanner();
    }
  }

  Widget _buildScannerValidSheet(_VerificationPayload payload) {
    final booking = payload.booking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3F6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD1FAE5),
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ticket Valid',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2A44),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          payload.message,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
        ),
        const SizedBox(height: 12),
        _detailsPanel(booking, payload.scannedCode),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading || booking == null
                ? null
                : () async {
                    print('[VERIFY] Confirm Admission button pressed by user');
                    setState(() => _userPressedButton = true);
                    await _confirmAdmission(booking!, fromManualFlow: false);
                    setState(() => _userPressedButton = false);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_rounded),
            label: const Text('Confirm Admission'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C67F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _openManualEntry();
            },
            icon: const Icon(Icons.keyboard_alt_outlined),
            label: const Text('Manual Entry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2C67F2),
              side: const BorderSide(color: Color(0xFFD5DDF5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerInvalidSheet(_VerificationPayload payload) {
    final booking = payload.booking;
    final title = _invalidTitle(payload.status);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3F6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEE2E2),
                border: Border.all(color: const Color(0xFFFECACA), width: 2),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              payload.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF667085),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _detailsPanel(booking, payload.scannedCode),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openManualEntry(prefill: payload.scannedCode);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _resetScanner();
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Back to Scanner'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475467),
                side: const BorderSide(color: Color(0xFFD5DDF5)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _detailsPanel(InscriptionModel? booking, String code) {
    final act = booking?.activite ?? {};
    final tourist = booking?.touriste ?? {};

    final guestName = (tourist['fullname'] ?? tourist['nom'] ?? 'Unknown Guest').toString();
    final activity = (act['titre'] ?? act['title'] ?? 'N/A').toString();
    final participants = booking?.nombreParticipants ?? 0;
    final bookingId = booking != null
        ? '#DJT-${booking.id.substring(booking.id.length - 5).toUpperCase()}'
        : code;
    final usedAt = booking?.qrUsedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Guest Name', guestName),
          _kv('Booking ID', bookingId),
          _kv('Activity', activity),
          _kv(
            'Participants',
            participants > 0 ? '$participants Guests' : 'N/A',
          ),
          if (usedAt != null)
            _kv('Last Scan', DateFormat('dd/MM HH:mm').format(usedAt)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: Color(0xFF1D2939),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAdmission(
    InscriptionModel booking, {
    required bool fromManualFlow,
  }) async {
    if (_isLoading) return;
    if (!fromManualFlow && !_userPressedButton) {
      print('[VERIFY] WARNING: _confirmAdmission called without user button press');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await InscriptionService.markInscriptionAsUsed(
        booking.id,
      );
      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm admission'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final updated = InscriptionModel.fromJson({
        ...booking.toJson(),
        'statut': 'verified',
        'qr_used_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _lastResult = _lastResult?.copyWith(
          booking: updated,
          status: VerificationStatus.valid,
          message: 'Identity confirmed. Guest can enter now.',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admission confirmed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      if (fromManualFlow) {
        _resetScanner();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openManualEntry({String? prefill}) {
    setState(() {
      _view = _VerifyView.manualEntry;
      if (prefill != null && prefill.trim().isNotEmpty) {
        _manualCodeController.text = prefill.trim();
      }
    });
    _scannerController.stop();
  }

  void _resetScanner() {
    setState(() {
      _view = _VerifyView.scanner;
      _lastScannedCode = null;
      _lastResult = null;
      _manualCodeController.clear();
    });
    _scannerController.start();
  }

  String _invalidTitle(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.alreadyUsed:
        return 'Invalid Ticket';
      case VerificationStatus.notApproved:
        return 'Not Confirmed';
      case VerificationStatus.expired:
        return 'Activity Expired';
      case VerificationStatus.unauthorized:
        return 'Access Denied';
      case VerificationStatus.invalid:
      case VerificationStatus.error:
      default:
        return 'Verification Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _VerifyView.manualEntry:
        return _buildManualEntryScreen();
      case _VerifyView.manualSuccess:
        return _buildManualResultScreen(success: true);
      case _VerifyView.manualFailure:
        return _buildManualResultScreen(success: false);
      case _VerifyView.scanner:
      default:
        return _buildScannerScreen();
    }
  }

  Widget _buildScannerScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Ticket',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final code = barcode.rawValue;
                      if (code != null && code.trim().isNotEmpty) {
                        _onScanned(code);
                        break;
                      }
                    }
                  },
                ),
                Container(color: Colors.black.withOpacity(0.38)),
                Column(
                  children: [
                    const Spacer(flex: 2),
                    Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF1D4ED8),
                            width: 6,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Color(0xFF9FB6FF),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Align QR code within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _scannerGlassButton(
                          icon: _scannerController.torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          onTap: _toggleTorch,
                        ),
                        const SizedBox(width: 14),
                        _scannerGlassButton(
                          icon: Icons.cameraswitch_rounded,
                          onTap: _switchCamera,
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xE6F4F5FF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.55),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Event Entry',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF414672),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _lastResult?.booking?.activite?['titre']
                                        ?.toString() ??
                                    'Ready for ticket scan',
                                style: const TextStyle(
                                  color: Color(0xFF7078A4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          final last = _lastScannedCode;
                                          if (last == null ||
                                              last.trim().isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Scan a ticket first or use Manual Entry',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          _verifyAndRoute(
                                            last,
                                            source: VerificationSource.scanner,
                                          );
                                        },
                                  icon: const Icon(Icons.verified_rounded),
                                  label: const Text('Verify Ticket'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F4FE0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _openManualEntry(),
                                  icon: const Icon(
                                    Icons.keyboard_alt_outlined,
                                    color: Color(0xFF2F63E9),
                                  ),
                                  label: const Text('Manual Entry'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4F5B84),
                                    side: const BorderSide(
                                      color: Color(0xFFC3CAE6),
                                    ),
                                    backgroundColor: const Color(0xFFE5E8F5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scannerGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildManualEntryScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: _resetScanner,
        ),
        title: const Text(
          'Verify Booking',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 22),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.confirmation_num_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter Ticket Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter Booking ID or Ticket Code to verify manually.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BOOKING ID OR TICKET CODE',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.85),
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualCodeController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '#DJT-98421 or DJTRIP_BOOKING:...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  suffixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final input = _manualCodeController.text.trim();
                          if (input.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter booking ID or ticket code',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          await _verifyAndRoute(
                            input,
                            source: VerificationSource.manual,
                          );
                        },
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: const Text('Verify Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C67F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Switch to Scanner'),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Codes are case-sensitive. Include the DJTRIP_BOOKING prefix when available.',
                  style: TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualResultScreen({required bool success}) {
    final payload = _lastResult;
    final booking = payload?.booking;

    final title = success ? 'Identity Confirmed' : 'Verification Failed';
    final subtitle = success
        ? 'The guest is cleared for immediate entry.'
        : (payload?.message ?? 'Ticket code is invalid or already used.');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF344054)),
          onPressed: _openManualEntry,
        ),
        title: Text(
          success ? 'VerificationSuccess' : 'Verification Result',
          style: const TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: success
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                  ),
                  child: Icon(
                    success ? Icons.check_rounded : Icons.close_rounded,
                    size: 64,
                    color: success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: success
                      ? const Color(0xFF111827)
                      : const Color(0xFF1F2937),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _detailsPanel(booking, payload?.scannedCode ?? '-'),
              const SizedBox(height: 20),
              if (success)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || booking == null)
                        ? null
                        : () =>
                              _confirmAdmission(booking, fromManualFlow: true),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_rounded),
                    label: const Text('Confirm Admission'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6FFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openManualEntry(prefill: payload?.scannedCode),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCF002E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _resetScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Back to Scanner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475467),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) setState(() {});
    } catch (_) {}
  }
}

class _VerificationPayload {
  final VerificationStatus status;
  final String message;
  final InscriptionModel? booking;
  final String scannedCode;
  final VerificationSource source;

  const _VerificationPayload({
    required this.status,
    required this.message,
    required this.booking,
    required this.scannedCode,
    required this.source,
  });

  _VerificationPayload copyWith({
    VerificationStatus? status,
    String? message,
    InscriptionModel? booking,
    String? scannedCode,
    VerificationSource? source,
  }) {
    return _VerificationPayload(
      status: status ?? this.status,
      message: message ?? this.message,
      booking: booking ?? this.booking,
      scannedCode: scannedCode ?? this.scannedCode,
      source: source ?? this.source,
    );
  }
}

enum VerificationSource { scanner, manual }

enum VerificationStatus {
  valid,
  invalid,
  alreadyUsed,
  notApproved,
  expired,
  unauthorized,
  error,
}
