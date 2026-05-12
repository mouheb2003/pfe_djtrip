import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import '../payment/stripe_payment_screen.dart';
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
  int _children = 0;
  bool _isLoading = false;
  int _currentImage = 0;
  late final PageController _imagePageController;

  final double _serviceFee = 5.0;

  int get _totalParticipants => _adults + _children;
  int get _maxParticipants => widget.activity.placesDisponibles;
  bool get _canAddParticipant => _totalParticipants < _maxParticipants;

  double get _subtotal => (_adults + _children) * widget.activity.prix;
  double get _total => _subtotal + _serviceFee;
  String get _currency => 'TND';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Book Activity',
          style: TextStyle(
            color: Color(0xFF0F172A),
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
            _buildActivityHeader(),
            const SizedBox(height: 14),
            _buildParticipantsCounter(),
            _buildPriceSummary(),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildActivityHeader() {
    final imageUrl = widget.activity.thumbnailUrl.isNotEmpty
        ? widget.activity.thumbnailUrl
        : (widget.activity.photos.isNotEmpty
              ? widget.activity.photos.first
              : '');
    final images = _activityImages;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8DFEA)),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${widget.activity.prix.toStringAsFixed(widget.activity.prix.truncateToDouble() == widget.activity.prix ? 0 : 2)} TND',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const TextSpan(
                        text: ' / person',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildParticipantsCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participants',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        _CounterCard(
          label: 'Adults',
          sublabel: '12 years and above',
          count: _adults,
          canDecrease: _adults > 1,
          canIncrease: _canAddParticipant,
          onChanged: (val) =>
              setState(() => _adults = (_adults + val).clamp(1, 99)),
        ),
        const SizedBox(height: 12),
        _CounterCard(
          label: 'Children',
          sublabel: '2 to 11 years',
          count: _children,
          canDecrease: _children > 0,
          canIncrease: _canAddParticipant,
          onChanged: (val) =>
              setState(() => _children = (_children + val).clamp(0, 99)),
        ),
        const SizedBox(height: 10),
        Text(
          _maxParticipants > 0
              ? 'Maximum available: $_maxParticipants participant${_maxParticipants > 1 ? 's' : ''}'
              : 'No seats available for this activity',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary() {
    final participants = _adults + _children;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          Divider(color: const Color(0xFFC8D0DD)),
          const SizedBox(height: 14),
          _PriceRow(
            label:
                'Subtotal (${participants}x ${participants > 1 ? 'Adults' : 'Adult'})',
            value: '${_subtotal.toStringAsFixed(0)} $_currency',
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: 'Service fee',
            value: '${_serviceFee.toStringAsFixed(0)} $_currency',
          ),
          const SizedBox(height: 12),
          Divider(color: const Color(0xFFD8DEE8), endIndent: 0),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${_total.toStringAsFixed(0)} $_currency',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                      'Pay & Confirm',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.payment, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    final requested = _totalParticipants;
    if (_maxParticipants <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This activity is no longer available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (requested > _maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum $_maxParticipants participant${_maxParticipants > 1 ? 's' : ''} allowed for this activity.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Step 1: Create inscription with PAID_PENDING_CONFIRMATION status
    try {
      final inscriptionResult = await InscriptionService.createInscription(
        activiteId: widget.activity.id,
        nombreParticipants: requested,
      );

      if (!mounted) return;

      final inscriptionId = inscriptionResult['inscription']?['_id']?.toString() ?? inscriptionResult['inscription']?['id']?.toString();

      if (inscriptionId == null || inscriptionId.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create booking'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 2: Navigate to Stripe payment screen with inscriptionId
      final paymentCompleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => StripePaymentScreen(
            inscriptionId: inscriptionId,
            activityId: widget.activity.id,
            activityTitle: widget.activity.titre,
            nombreParticipants: requested,
            adults: _adults,
            children: _children,
            amount: _total,
            currency: _currency,
            description: 'Booking for ${widget.activity.titre}',
          ),
        ),
      );

      if (!mounted) return;

      if (paymentCompleted == true) {
        // Payment successful, navigate to booking details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to booking detail screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              inscription: InscriptionModel.fromJson(inscriptionResult['inscription']),
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (paymentCompleted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment cancelled or failed. You can retry payment from the activity details.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      // Handle booking overlap errors
      String errorMessage = 'Error: $e';
      Color backgroundColor = Colors.red;
      
      if (e.toString().contains('status code 409') || e.toString().contains('already have a booking during this time period')) {
        // Extract conflict details if available
        String conflictDetails = '';
        try {
          // Try to parse the error response for conflict details
          if (e.toString().contains('conflict:')) {
            final conflictMatch = RegExp(r'conflict:\s*({.*?})').firstMatch(e.toString());
            if (conflictMatch != null) {
              conflictDetails = '\n\nConflicting activity: ${conflictMatch.group(1)}';
            }
          }
        } catch (_) {}
        
        errorMessage = 'You already have a booking during this time period.$conflictDetails';
        backgroundColor = Colors.orange;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final int count;
  final bool canDecrease;
  final bool canIncrease;
  final void Function(int) onChanged;

  const _CounterCard({
    required this.label,
    required this.sublabel,
    required this.count,
    required this.canDecrease,
    required this.canIncrease,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8DFEA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
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

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
