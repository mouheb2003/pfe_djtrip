import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/inscription_service.dart';
import '../../services/user_service.dart';
import 'chat_conversation_screen.dart';
import '../../models/inscription_model.dart';
import '../tourist/booking_confirmation_screen.dart';
import '../tourist/booking_selection_screen.dart';

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;
  final bool viewOnly;
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
    this.viewOnly = false,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _isFavorite = false;
  bool _showFullDesc = false;
  int _currentImage = 0;
  ActivityModel? _activity;
  bool _loadingActivity = true;
  bool _isBooking = false;

  final _images = const [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDNfZZTtbb9R6ggSFQb7xX45Kx85or58pI910ucscdM_B6Zm323nkRO5_Ygvg8JlYPYAfGQ39PlXMlfaEgOhaslWehtU45pd6srTFntUeosgajKg7Y06dghPvQNSezADfPDRPYp-povZLZTjxmPtdcmryWfif_V3uTpbV-4RcrfibTiBaj-0RrGG-AqoUW_Fn9gNooQk0efkv0fXWO2c35y5oaJCL7Snsf6s86CTVhpN3xFe1jdhOex2miLPfyGEsDVd22evBYBDu4',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCX_4WeeW_SGTwvs7VXl_aL99uiNWhh02XDKhh6An-T5k8DJhyuMYfD5faSyGfwTH9Ua8ZfSoXgw795eAHn43kWAIq29_REfLIU7DvyOtQG-68B2Sc7CkVqPRKp1XHZSaU9rXQEJIcksCLS0JY0snXzpCvpZGMommtBseZIEDjTXzCoywLY2EdLfnqD9lVhdLSUexpuLVBMr-sNNh3i6_ntPGSHRxKMtQSIaFgv6NFpohrWblLM6WPFiKWRTv0fMQQ09aUA83H0pw0',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAjRY_sl_a6Rc65aV3sPu7S3B2Kgxl0UpL6_GKL2B5N7r-eWGfBwgqdTGQM5tkIRPik38vpxgj56MsXUHnSdGmEPeKYxEEkFKnOjQgOwt8jdWOEkrZS9HKEP0LY-sQJsNaA4NFMzseh1Cxjfp2d5zBt7m5eekZOk3wWeTEtBCrGLJXVkZh4vTyyXTUzcguvJoEstinWH9ombbG2y-ae9e3dUE4UU03yGYP6_jx3CSgvLCS16mcEqKrDSIuDb-1XmGx0Ptwoaa_WLnA',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDNfZZTtbb9R6ggSFQb7xX45Kx85or58pI910ucscdM_B6Zm323nkRO5_Ygvg8JlYPYAfGQ39PlXMlfaEgOhaslWehtU45pd6srTFntUeosgajKg7Y06dghPvQNSezADfPDRPYp-povZLZTjxmPtdcmryWfif_V3uTpbV-4RcrfibTiBaj-0RrGG-AqoUW_Fn9gNooQk0efkv0fXWO2c35y5oaJCL7Snsf6s86CTVhpN3xFe1jdhOex2miLPfyGEsDVd22evBYBDu4',
  ];

  final _desc =
      'A unique horseback riding adventure along the golden beaches of Djerba at sunset. '
      'Discover the breathtaking landscapes of the island with an experienced guide. '
      'Ideal for beginners and experienced riders alike. '
      'Enjoy this unforgettable experience with well-trained horses and professional supervision throughout the ride.';

  List<String> get _displayImages =>
      _activity?.photos.isNotEmpty == true ? _activity!.photos : _images;

  String get _descText => _activity?.description ?? _desc;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final results = await Future.wait([
      ActivityService.getActivityById(widget.activityId),
      UserService.getFavorites(),
    ]);
    if (!mounted) return;
    final favs = results[1] as List<Map<String, dynamic>>;
    setState(() {
      _activity = results[0] as ActivityModel?;
      _loadingActivity = false;
      _isFavorite = favs.any(
        (f) =>
            (f['_id'] ?? f['id'])?.toString() == widget.activityId ||
            (f['activite'] is Map
                    ? (f['activite']['_id'] ?? f['activite']['id'])?.toString()
                    : f['activite']?.toString()) ==
                widget.activityId,
      );
    });
  }

  Future<void> _bookActivity() async {
    if (_activity == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingSelectionScreen(activity: _activity!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Cover Image Carousel
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                backgroundColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _IconBtn(
                    icon: Icons.arrow_back,
                    iconColor: Colors.black87,
                    bgColor: Colors.white.withOpacity(0.9),
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  _IconBtn(
                    icon: Icons.share,
                    iconColor: Colors.black87,
                    bgColor: Colors.white.withOpacity(0.9),
                    onTap: () => Share.share(
                      'Check out ${_activity?.titre ?? 'this activity'} on DJTrip.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                    iconColor: _isFavorite ? AppColors.primary : Colors.black87,
                    bgColor: Colors.white.withOpacity(0.9),
                    onTap: () async {
                      final adding = !_isFavorite;
                      setState(() => _isFavorite = adding);
                      if (adding) {
                        await UserService.addFavorite(widget.activityId);
                      } else {
                        await UserService.removeFavorite(widget.activityId);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      PageView.builder(
                        itemCount: _displayImages.length,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemBuilder: (_, i) => Image.network(
                          _displayImages[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[300]),
                        ),
                      ),
                      // Dots
                      Positioned(
                        bottom: 32, // Above the rounded card
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _displayImages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == _currentImage ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _currentImage
                                    ? Colors.white
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            _activity?.titre ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Rating & Duration
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _activity?.noteMoyenne.toStringAsFixed(1) ?? '—',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${_activity?.nombreAvis ?? 0} reviews)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _activity?.dureeFormatted ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Stats chips (Price & Languages)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PRICE PER PERSON',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _activity?.prixFormatted ?? '...',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'LANGUAGES',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _activity?.languesFormatted ?? '...',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Organizer card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
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
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundImage:
                                          _activity?.organisateur?['avatar'] != null
                                          ? NetworkImage(
                                              _activity!.organisateur!['avatar']
                                                  as String,
                                            )
                                          : null,
                                      backgroundColor: const Color(0xFFFCD3BD),
                                      child:
                                          _activity?.organisateur?['avatar'] == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.black54,
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _activity?.organisateur?['fullname']
                                                as String? ??
                                            'Organizer',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Verified Organizer',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    final organizer = _activity?.organisateur;
                                    final partnerId = (organizer?['_id'] ?? '')
                                        .toString();
                                    final partnerName =
                                        (organizer?['fullname'] ?? 'Organizer')
                                            .toString();
                                    final partnerAvatar = organizer?['avatar']
                                        ?.toString();
                                    final partnerOnline =
                                        organizer?['isOnline'] == true;

                                    if (partnerId.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to open chat.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatConversationScreen(
                                          partnerId: partnerId,
                                          partnerName: partnerName,
                                          partnerAvatar: partnerAvatar,
                                          partnerOnline: partnerOnline,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3ED),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text(
                                      'Contact',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showFullDesc
                                ? _descText
                                : _descText.length > 160
                                ? '${_descText.substring(0, 160)}...'
                                : _descText,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_descText.length > 160)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showFullDesc = !_showFullDesc),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showFullDesc ? 'Show less' : 'Read more',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Icon(
                                    _showFullDesc ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),
                          // Map preview
                          const Text(
                            'Meeting Point',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  height: 180,
                                  width: double.infinity,
                                  child: Image.network(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDNfZZTtbb9R6ggSFQb7xX45Kx85or58pI910ucscdM_B6Zm323nkRO5_Ygvg8JlYPYAfGQ39PlXMlfaEgOhaslWehtU45pd6srTFntUeosgajKg7Y06dghPvQNSezADfPDRPYp-povZLZTjxmPtdcmryWfif_V3uTpbV-4RcrfibTiBaj-0RrGG-AqoUW_Fn9gNooQk0efkv0fXWO2c35y5oaJCL7Snsf6s86CTVhpN3xFe1jdhOex2miLPfyGEsDVd22evBYBDu4',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                    ),
                                  ),
                                ),
                              ),
                              // Centered Map Pin
                              Positioned.fill(
                                child: Center(
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _activity?.lieu ?? 'Lieu',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // What's included
                          const Text(
                            "What's Included",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            crossAxisCount: 2,
                            childAspectRatio: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              _IncludedItem(
                                icon: Icons.check_circle,
                                text: 'Professional guide',
                                color: AppColors.primary,
                              ),
                              _IncludedItem(
                                icon: Icons.check_circle,
                                text: 'Full equipment',
                                color: AppColors.primary,
                              ),
                              _IncludedItem(
                                icon: Icons.check_circle,
                                text: 'Water bottle',
                                color: AppColors.primary,
                              ),
                              _IncludedItem(
                                icon: Icons.check_circle,
                                text: 'Souvenir photos',
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          // Bottom padding for CTA bar
                          SizedBox(height: widget.viewOnly ? 24 : 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          // Sticky bottom CTA
          if (!widget.viewOnly)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total price',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activity?.prixFormatted ?? '...',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _isBooking ? null : _bookActivity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isBooking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Book now',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? bgColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    this.iconColor,
    this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncludedItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _IncludedItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
