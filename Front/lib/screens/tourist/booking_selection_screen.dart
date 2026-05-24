import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../../services/navigation_service.dart';
import '../../utils/snackbar_utils.dart';
import 'booking_confirmation_screen.dart';
import 'booking_detail_screen.dart';

class BookingSelectionScreen extends StatefulWidget {
  final ActivityModel activity;

  const BookingSelectionScreen({super.key, required this.activity});

  @override
  State<BookingSelectionScreen> createState() => _BookingSelectionScreenState();
}

class _BookingSelectionScreenState extends State<BookingSelectionScreen> {
  int _adults = 1;
  bool _isLoading = false;
  int _currentImage = 0;
  late final PageController _imagePageController;

  int get _totalParticipants => _adults;
  int get _maxParticipants => widget.activity.placesDisponibles;
  bool get _canAddParticipant => _totalParticipants < _maxParticipants;


  List<String> get _activityImages {
    final images = <String>[];
    for (final photo in widget.activity.photos) {
      final value = photo.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        images.add(value);
      }
    }
    if (widget.activity.thumbnailUrl.isNotEmpty) {
      images.insert(0, widget.activity.thumbnailUrl);
    }
    if (images.isEmpty) {
      return const [
        'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?q=80&w=1200&auto=format&fit=crop',
      ];
    }
    return images.toSet().toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Book Activity',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 108),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivityHeader(isDark),
            const SizedBox(height: 14),
            _buildParticipantsCounter(isDark),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(isDark),
    );
  }

  Widget _buildActivityHeader(bool isDark) {
    final images = _activityImages;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8DFEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.activity.titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 128,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 128,
                    height: 128,
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentImage = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (index) {
                      final active = index == _currentImage;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: active ? 12 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : const Color(0xFFC3CDD9),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCounter(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _CounterCard(
          label: 'Participants',
          sublabel: 'Number of people attending',
          count: _adults,
          canDecrease: _adults > 1,
          canIncrease: _canAddParticipant,
          onChanged: (val) =>
              setState(() => _adults = (_adults + val).clamp(1, 99)),
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        Text(
          _maxParticipants > 0
              ? 'Maximum available: $_maxParticipants participant${_maxParticipants > 1 ? 's' : ''}'
              : 'No seats available for this activity',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    final requested = _totalParticipants;
    if (_maxParticipants <= 0) {
      _showError('This activity has no available seats at the moment.');
      return;
    }

    if (requested > _maxParticipants) {
      _showError(
        'Only $_maxParticipants seat${_maxParticipants > 1 ? 's' : ''} available. Please reduce the number of participants.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await InscriptionService.createInscription(
        activiteId: widget.activity.id,
        nombreParticipants: requested,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] != true) {
        // Show the exact message from the server
        final msg = result['message']?.toString() ?? 'Booking could not be completed.';
        _showError(msg);
        return;
      }

      final inscriptionJson = result['inscription'];
      if (inscriptionJson == null) {
        _showError('Booking created but confirmation data is missing. Please check your bookings.');
        return;
      }

      final inscription = InscriptionModel.fromJson(inscriptionJson);

      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Booking submitted successfully.');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(inscription: inscription),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      SnackbarUtils.showError(context, msg.isNotEmpty ? msg : 'An unexpected error occurred. Please try again.');
    }
  }

  void _showError(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Text(
              'Booking Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : null),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : const Color(0xFF374151), height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final int count;
  final bool canDecrease;
  final bool canIncrease;
  final void Function(int) onChanged;
  final bool isDark;

  const _CounterCard({
    required this.label,
    required this.sublabel,
    required this.count,
    required this.canDecrease,
    required this.canIncrease,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD8DFEA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _CircleCounterButton(
            icon: Icons.remove,
            enabled: canDecrease,
            onTap: () => onChanged(-1),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 12),
          _CircleCounterButton(
            icon: Icons.add,
            enabled: canIncrease,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _CircleCounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CircleCounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = enabled ? AppColors.primary : const Color(0xFFBFCBDD);
    final fillColor = enabled ? AppColors.primary : Colors.transparent;
    final iconColor = enabled ? Colors.white : const Color(0xFFBFCBDD);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}

