import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/inscription_service.dart';
import 'booking_confirmation_screen.dart';

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
            value: '${_subtotal.toStringAsFixed(0)} TND',
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: 'Service fee',
            value: '${_serviceFee.toStringAsFixed(0)} TND',
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
                '${_total.toStringAsFixed(0)} TND',
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
                      'Confirm booking',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
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
          content: Text('No seats available for this activity.'),
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
    final result = await InscriptionService.createInscription(
      activiteId: widget.activity.id,
      nombreParticipants: requested,
      message: 'Adults: $_adults, Children: $_children',
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final inscription = InscriptionModel.fromJson(result['inscription']);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(inscription: inscription),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Booking error'),
          backgroundColor: Colors.red,
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
