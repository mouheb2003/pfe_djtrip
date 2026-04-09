import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_model.dart';
import '../../models/inscription_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/inscription_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../tourist/booking_detail_screen.dart';
import '../tourist/booking_selection_screen.dart';
import 'chat_conversation_screen.dart';
import 'public_organizer_profile_screen.dart';

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
  bool _showFullDesc = false;
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentImage = 0;
  ActivityModel? _activity;
  String _currentUserId = '';
  String _currentUserType = '';
  bool _loadingActivity = true;
  bool _isBooking = false;
  InscriptionModel? _bookingForActivity;

  final _images = const [
    'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?q=80&w=1600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1516549655169-df83a0774514?q=80&w=1600&auto=format&fit=crop',
  ];

  List<String> get _displayImages {
    final photos = _activity?.photos ?? const <String>[];
    final List<String> extractedUrls = [];
    final urlRegExp = RegExp(r'https?://[^"\\]+');

    for (final p in photos) {
      final matches = urlRegExp.allMatches(p);
      for (final m in matches) {
        final url = m.group(0)!.replaceAll('\\/', '/');
        if (url.contains('cloudinary.com') ||
            url.contains('.jpg') ||
            url.contains('.png') ||
            url.contains('.jpeg')) {
          extractedUrls.add(url);
        }
      }
    }
    if (extractedUrls.isEmpty) return _images;
    if (extractedUrls.length == 1) return [extractedUrls.first, _images[1]];
    return extractedUrls;
  }

  String get _description => (_activity?.description ?? '').trim().isNotEmpty
      ? _activity!.description
      : 'No description available.';

  LatLng? get _meetingPoint {
    final coords = _activity?.coordonnees;
    if (coords == null) return null;
    final latRaw = coords['latitude'] ?? coords['lat'];
    final lngRaw = coords['longitude'] ?? coords['lng'];
    if (latRaw is! num || lngRaw is! num) return null;
    return LatLng(latRaw.toDouble(), lngRaw.toDouble());
  }

  bool get _canContactOrganizer {
    final organizer = _activity?.organisateur;
    final organizerId = (organizer?['_id'] ?? organizer?['id'] ?? '')
        .toString()
        .trim();
    if (organizerId.isEmpty) return false;
    if (_currentUserId.isEmpty) return true;
    return organizerId != _currentUserId;
  }

  bool get _isTouristUser {
    final role = _currentUserType.trim().toLowerCase();
    return role == 'touriste' || role == 'tourist';
  }

  bool get _isOrganizerUser {
    final role = _currentUserType.trim().toLowerCase();
    return role == 'organisator' || role == 'organisateur' || role == 'organizer';
  }

  bool get _isActivityOrganizer {
    if (_activity == null || _currentUserId.isEmpty) return false;
    final organizer = _activity?.organisateur;
    final organizerId = (organizer?['_id'] ?? organizer?['id'] ?? '').toString().trim();
    return organizerId == _currentUserId;
  }

  bool get _hasBookingForActivity => _bookingForActivity != null;

  InscriptionModel? _latestBookingForActivity(
    String activityId,
    Map<String, List<InscriptionModel>> bookings,
  ) {
    InscriptionModel? latest;

    void collect(List<InscriptionModel> items) {
      for (final item in items) {
        final itemActivityId = (item.activite?['_id'] ?? '').toString();
        if (itemActivityId != activityId) continue;

        if (latest == null) {
          latest = item;
          continue;
        }

        final currentDate = item.dateDemande;
        final previousDate = latest!.dateDemande;

        if (currentDate == null && previousDate != null) continue;
        if (currentDate != null && previousDate == null) {
          latest = item;
          continue;
        }
        if (currentDate != null &&
            previousDate != null &&
            currentDate.isAfter(previousDate)) {
          latest = item;
        }
      }
    }

    collect(bookings['pending'] ?? const <InscriptionModel>[]);
    collect(bookings['confirmed'] ?? const <InscriptionModel>[]);
    collect(bookings['cancelled'] ?? const <InscriptionModel>[]);

    return latest;
  }

  Future<void> _openBookingStatus() async {
    final booking = _bookingForActivity;
    if (booking == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(inscription: booking),
      ),
    );
  }

  String _getDateRangeLabel(ActivityModel a) {
    if (a.dateDebut == null) return '-';
    if (a.dateFin == null) return _fmtDate(a.dateDebut);

    // Check if on the same day
    bool sameDay =
        a.dateDebut!.year == a.dateFin!.year &&
        a.dateDebut!.month == a.dateFin!.month &&
        a.dateDebut!.day == a.dateFin!.day;

    if (sameDay) {
      final hh = a.dateFin!.hour.toString().padLeft(2, '0');
      final mm = a.dateFin!.minute.toString().padLeft(2, '0');
      return '${_fmtDate(a.dateDebut)} - $hh:$mm';
    } else {
      return '${_fmtDate(a.dateDebut)} - ${_fmtDate(a.dateFin)}';
    }
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m $hh:$mm';
  }

  String _fmtCoords() {
    final point = _meetingPoint;
    if (point == null) return '-';
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _resetCarouselTimer();
    _loadActivity();
  }

  void _resetCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      final images = _displayImages;
      if (images.length <= 1) return;
      if (_pageController.hasClients) {
        int nextPage = _currentImage + 1;
        if (nextPage >= images.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    try {
      if (widget.activityId.isEmpty) throw Exception('Activity ID is empty');
      final results = await Future.wait([
        ActivityService.getActivityById(widget.activityId),
        AuthService.getUserId(),
        AuthService.getUserType(),
      ]);
      if (!mounted) return;

      final userType = (results[2] as String? ?? '').trim();
      InscriptionModel? booking;
      final role = userType.toLowerCase();
      if (role == 'touriste' || role == 'tourist') {
        final bookings = await InscriptionService.getMyBookings();
        if (!mounted) return;
        booking = _latestBookingForActivity(widget.activityId, bookings);
      }

      setState(() {
        _activity = results[0] as ActivityModel?;
        _currentUserId = (results[1] as String? ?? '').trim();
        _currentUserType = userType;
        _bookingForActivity = booking;
        _loadingActivity = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  Future<void> _bookActivity() async {
    if (_activity == null) return;
    setState(() => _isBooking = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSelectionScreen(activity: _activity!),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingActivity) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activity = _activity;
    if (activity == null) {
      return const Scaffold(body: Center(child: Text('Activity not found.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemCount: _displayImages.length,
                        itemBuilder: (ctx, i) =>
                            Image.network(_displayImages[i], fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 16,
                      child: _TopIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      top: 380,
                      left: 20,
                      right: 20,
                      child: _HeroSummaryCard(activity: activity),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 460),
                      _SectionTitle('Description'),
                      Text(
                        _showFullDesc
                            ? _description
                            : (_description.length > 200
                                  ? '${_description.substring(0, 200)}...'
                                  : _description),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      if (_description.length > 200)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showFullDesc = !_showFullDesc),
                          child: Text(
                            _showFullDesc ? 'Show less' : 'Read more',
                          ),
                        ),
                      _SectionTitle('Included Equipment'),
                      _TagListSection(
                        items: activity.equipementsInclus,
                        emptyLabel: 'No equipment specified',
                        icon: Icons.check_circle,
                        chipColor: const Color(0xFFE9E8F7),
                        iconColor: const Color(0xFF3049D9),
                      ),
                      _SectionTitle('What to Bring'),
                      _TagListSection(
                        items: activity.aApporter,
                        emptyLabel: 'Nothing special is required',
                        icon: Icons.inventory_2_outlined,
                        chipColor: const Color(0xFFF4F4FB),
                        iconColor: const Color(0xFF6B7280),
                      ),
                      _SectionTitle('Location'),
                      _LocationCard(
                        placeLabel: activity.lieu,
                        meetingPoint: _meetingPoint,
                      ),
                      _SectionTitle('Organizer'),
                      _OrganizerCard(
                        organizer: activity.organisateur,
                        canContact: _isTouristUser && _canContactOrganizer,
                        onContact: () {
                          final organizer = activity.organisateur;
                          final orgId =
                              (organizer?['_id'] ?? organizer?['id'] ?? '')
                                  .toString()
                                  .trim();
                          if (orgId.isEmpty) return;

                          final orgName =
                              (organizer?['fullname'] ?? 'Organizer')
                                  .toString();
                          final orgAvatar = organizer?['avatar']?.toString();
                          final orgOnline = organizer?['isOnline'] == true;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                partnerId: orgId,
                                partnerName: orgName,
                                partnerAvatar: orgAvatar,
                                partnerType: 'Organisator',
                                partnerOnline: orgOnline,
                              ),
                            ),
                          );
                        },
                        onTap: () {
                          final orgId =
                              (activity.organisateur?['_id'] ??
                                      activity.organisateur?['id'] ??
                                      '')
                                  .toString();
                          if (orgId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicOrganizerProfileScreen(
                                  organizerId: orgId,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!widget.viewOnly && !_isActivityOrganizer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyBottomBar(
                price: activity.prixFormatted,
                showPrice: !_hasBookingForActivity,
                buttonLabel: _hasBookingForActivity
                    ? 'Check Booking Status'
                    : 'Book Now',
                onBook: _isBooking
                    ? null
                    : (_hasBookingForActivity
                          ? _openBookingStatus
                          : _bookActivity),
                isLoading: _isBooking,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final ActivityModel activity;
  const _HeroSummaryCard({required this.activity});

  String _displayStatus(ActivityModel activity) {
    final timeline = activity.timelineStatus.toUpperCase();
    if (timeline == 'PAST') return 'COMPLETED';
    if (timeline == 'ONGOING') return 'ONGOING';
    return 'UPCOMING';
  }

  String _formatStartDate(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E8F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF3049D9)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'upcoming') {
      return const Color(0xFF3049D9);
    }
    if (normalized == 'ongoing') {
      return const Color(0xFF059669);
    }
    if (normalized == 'completed') {
      return const Color(0xFF6B7280);
    }
    if (normalized == 'active') {
      return const Color(0xFF2F55EB);
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    final badgeStatus = _displayStatus(activity);
    final ratingText = activity.noteMoyenne.toStringAsFixed(1);
    final activityType = activity.typeActivite.trim().isNotEmpty
        ? activity.typeActivite
        : (activity.categorie.trim().isNotEmpty
              ? activity.categorie
              : 'Activity');
    final languages = activity.languesFormatted.trim().isEmpty
        ? '-'
        : activity.languesFormatted;
    final statusColor = _statusColor(badgeStatus);
    final participants = activity.capaciteMax > 0
        ? '${activity.capaciteMax} max'
        : '-';
    final difficulty = activity.niveauDifficulte.trim().isEmpty
        ? '-'
        : activity.niveauDifficulte;
    final reviewsCount = activity.nombreAvis > 0
        ? '(${activity.nombreAvis} avis)'
        : '(0 avis)';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE8FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activityType.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3049D9),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBFA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: Color(0xFFF6C24A)),
                    const SizedBox(width: 5),
                    Text(
                      '$ratingText $reviewsCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF545273),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activity.titre,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.02,
              color: Color(0xFF17183D),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _infoTile(
                    icon: Icons.event,
                    label: 'Date debut',
                    value: _formatStartDate(activity.dateDebut),
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.timer,
                    label: 'Duree',
                    value: activity.dureeFormatted,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.group,
                    label: 'Capacite',
                    value: participants,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.payments_outlined,
                    label: 'Prix / personne',
                    value: activity.prixFormatted,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.language,
                    label: 'Langues',
                    value: languages,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.fitness_center,
                    label: 'Niveau',
                    value: difficulty,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D2652),
        ),
      ),
    );
  }
}

class _TagListSection extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  final IconData icon;
  final Color chipColor;
  final Color iconColor;

  const _TagListSection({
    required this.items,
    required this.emptyLabel,
    required this.icon,
    required this.chipColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (cleaned.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cleaned
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chipColor.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF1F2A44),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String placeLabel;
  final LatLng? meetingPoint;
  const _LocationCard({required this.placeLabel, required this.meetingPoint});

  @override
  Widget build(BuildContext context) {
    final markerId = const MarkerId('meeting_point');

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: meetingPoint == null
            ? Center(
                child: Text(
                  'Meeting point: $placeLabel',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: meetingPoint!,
                      zoom: 14.5,
                    ),
                    markers: {
                      Marker(
                        markerId: markerId,
                        position: meetingPoint!,
                        infoWindow: InfoWindow(title: placeLabel),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        placeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final Map<String, dynamic>? organizer;
  final VoidCallback onTap;
  final bool canContact;
  final VoidCallback? onContact;
  const _OrganizerCard({
    required this.organizer,
    required this.onTap,
    this.canContact = false,
    this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final name = (organizer?['fullname'] ?? 'Organizer').toString();
    final avatar = organizer?['avatar']?.toString() ?? '';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'View full profile',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            if (canContact && onContact != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF315CFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Contact',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final String price;
  final bool showPrice;
  final String buttonLabel;
  final VoidCallback? onBook;
  final bool isLoading;
  const _StickyBottomBar({
    required this.price,
    required this.showPrice,
    required this.buttonLabel,
    required this.onBook,
    required this.isLoading,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showPrice) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TOTAL PRICE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B2452),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        buttonLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
