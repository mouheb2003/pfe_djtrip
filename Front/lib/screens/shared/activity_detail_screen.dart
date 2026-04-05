import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../tourist/booking_selection_screen.dart';
import 'chat_conversation_screen.dart';

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
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentImage = 0;
  ActivityModel? _activity;
  String _currentUserId = '';
  bool _loadingActivity = true;
  bool _isBooking = false;

  final _images = const [
    'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?q=80&w=1600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1516549655169-df83a0774514?q=80&w=1600&auto=format&fit=crop',
  ];

  List<String> get _displayImages {
    final photos = _activity?.photos ?? const <String>[];

    // Extract actual URLs using RegExp. This handles cases where backend
    // accidentally stored a raw JSON string instead of an array of URLs.
    final List<String> extractedUrls = [];
    final urlRegExp = RegExp(r'https?://[^"\\]+');

    for (final p in photos) {
      final matches = urlRegExp.allMatches(p);
      for (final m in matches) {
        // Clean up extracted URL in case of escaped slashes
        final url = m.group(0)!.replaceAll('\\/', '/');
        // Only add typical image formats or Cloudinary URLs
        if (url.contains('cloudinary.com') ||
            url.contains('.jpg') ||
            url.contains('.png') ||
            url.contains('.jpeg')) {
          extractedUrls.add(url);
        }
      }
    }

    if (extractedUrls.isEmpty) return _images;

    // The user requested a carousel even if there's only 1 image uploaded.
    // So if there's only 1 valid photo, we append a generic one to enable swiping.
    if (extractedUrls.length == 1) {
      return [extractedUrls.first, _images[1]];
    }

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

  List<DateTime> get _availabilityDates {
    final dates = _activity?.datesDisponibles ?? const <DateTime>[];
    if (dates.isNotEmpty) return dates;
    final start = _activity?.dateDebut;
    return start != null ? <DateTime>[start] : const <DateTime>[];
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _fmtCoords() {
    final point = _meetingPoint;
    if (point == null) return '-';
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  String _fmtList(List<String> list) {
    if (list.isEmpty) return '-';
    return list.join(', ');
  }

  int _cancelledCount(ActivityModel activity) {
    // Fallback value because the current ActivityModel does not expose
    // a dedicated cancellations counter from API.
    final raw = activity.organisateur?['nombre_annulations'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;

    final s = activity.statut.toLowerCase().trim();
    if (s == 'annule' || s == 'annulé' || s == 'cancelled') return 1;
    return 0;
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
        if (nextPage >= images.length) {
          nextPage = 0;
        }
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
    final results = await Future.wait([
      ActivityService.getActivityById(widget.activityId),
      UserService.getFavorites(),
      AuthService.getUserId(),
    ]);

    if (!mounted) return;

    final favs = results[1] as List<Map<String, dynamic>>;
    setState(() {
      _activity = results[0] as ActivityModel?;
      _currentUserId = (results[2] as String? ?? '').trim();
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

  void _openOrganizerChat() {
    final organizer = _activity?.organisateur;
    final partnerId = (organizer?['_id'] ?? organizer?['id'] ?? '').toString();
    final partnerName = (organizer?['fullname'] ?? 'Organizer').toString();
    final partnerAvatar = organizer?['avatar']?.toString();
    final partnerOnline = organizer?['isOnline'] == true;

    if (partnerId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open chat.')));
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingActivity) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F2FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activity = _activity;
    if (activity == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F2FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F2FA),
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(child: Text('Activity not found.')),
      );
    }

    const double heroHeight = 420;
    const double floatingCardTop = 220;
    const double floatingCardReserveSpace = 380;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: heroHeight,
                pinned: true,
                backgroundColor: const Color(0xFFF3F2FA),
                elevation: 0,
                leading: _TopIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                actions: [
                  _TopIconButton(
                    icon: Icons.share,
                    onTap: () =>
                        Share.share('Check out ${activity.titre} on DJTrip.'),
                  ),
                  _TopIconButton(
                    icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                    iconColor: _isFavorite ? AppColors.primary : Colors.black87,
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
                  const SizedBox(width: 10),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── Hero image (full area) ──────────────────────────────
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _displayImages.length,
                          onPageChanged: (i) {
                            setState(() => _currentImage = i);
                            _resetCarouselTimer();
                          },
                          itemBuilder: (_, i) => Image.network(
                            _displayImages[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      // ── Gradient: darken top, fade to bg at bottom ──────────
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.28, 0.38, 1.0],
                                colors: [
                                  Colors.black.withOpacity(0.18),
                                  Colors.transparent,
                                  Colors.transparent,
                                  const Color(0xFFF3F2FA),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ── Page indicator dots ─────────────────────────────────
                      if (_displayImages.length > 1)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _displayImages.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == _currentImage ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _currentImage
                                      ? Colors.white
                                      : Colors.white54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -180),
                        child: _HeroSummaryCard(
                          activity: activity,
                          isPreview: widget.viewOnly,
                          startDateLabel: _fmtDate(activity.dateDebut),
                          endDateLabel: _fmtDate(activity.dateFin),
                          cancelledCount: _cancelledCount(activity),
                        ),
                      ),
                      const SizedBox(
                        height: -160,
                      ), // Pull the rest of the content up to compensate for the translate offset
                      _SectionTitle('Description'),
                      Text(
                        _showFullDesc
                            ? _description
                            : _description.length > 220
                            ? '${_description.substring(0, 220)}...'
                            : _description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (_description.length > 220)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showFullDesc = !_showFullDesc),
                          child: Text(
                            _showFullDesc ? 'Show less' : 'Read more',
                          ),
                        ),
                      _SectionTitle('Included Equipment'),
                      _TagWrap(
                        items: activity.equipementsInclus,
                        emptyLabel: 'No equipment specified.',
                        filledColor: const Color(0xFFE6E2FF),
                        icon: Icons.verified_rounded,
                      ),
                      _SectionTitle('Bring Your Own'),
                      _TagWrap(
                        items: activity.aApporter,
                        emptyLabel: 'No items required to bring.',
                        filledColor: const Color(0xFFF3F4FA),
                        icon: Icons.list_alt_rounded,
                      ),
                      _SectionTitle('Location'),
                      _LocationCard(
                        point: _meetingPoint,
                        placeLabel: activity.lieu,
                        coordsLabel: _fmtCoords(),
                      ),
                      _SectionTitle('Organizer'),
                      _OrganizerCard(
                        organizer: activity.organisateur,
                        canContact: _canContactOrganizer,
                        onContact: _openOrganizerChat,
                      ),
                      _SectionTitle('Availability'),
                      _AvailabilityCard(dates: _availabilityDates),
                      _SectionTitle('Additional Information'),
                      _MetaInfoCard(
                        rows: [
                          _MetaRow('Activity Type', activity.typeActivite),
                          _MetaRow('Location', activity.lieu),
                          _MetaRow('Coordinates', _fmtCoords()),
                          _MetaRow('Duration', activity.dureeFormatted),
                          _MetaRow('Price', activity.prixFormatted),
                          _MetaRow('Max Capacity', '${activity.capaciteMax}'),
                          _MetaRow(
                            'Languages',
                            _fmtList(activity.languesDisponibles),
                          ),
                          _MetaRow(
                            'Difficulty Level',
                            activity.niveauDifficulte,
                          ),
                          _MetaRow('Start Date', _fmtDate(activity.dateDebut)),
                          _MetaRow('End Date', _fmtDate(activity.dateFin)),
                          _MetaRow('Status', activity.statut),
                          _MetaRow(
                            'Average Rating',
                            activity.noteMoyenne.toStringAsFixed(1),
                          ),
                          _MetaRow(
                            'Number of Reviews',
                            '${activity.nombreAvis}',
                          ),
                          if (!widget.viewOnly)
                            _MetaRow(
                              'Reservations',
                              '${activity.nombreReservations}',
                            ),
                          _MetaRow('Photos', '${activity.photos.length}'),
                          _MetaRow('Created', _fmtDate(activity.createdAt)),
                          _MetaRow('Updated', _fmtDate(activity.updatedAt)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (!widget.viewOnly)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1,
                              color: Color(0xFF7A82A5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity.prixFormatted,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2452),
                            ),
                          ),
                          const Text(
                            'pers.',
                            style: TextStyle(
                              color: Color(0xFF7A82A5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isBooking ? null : _bookActivity,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isBooking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Book\nNow',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.viewOnly)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF4F67E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text(
                    'Back to Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Map<String, dynamic> _getStatusInfo(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'disponible' || s == 'available') {
      return {
        'label': 'AVAILABLE',
        'bg': const Color(0xFFDCFCE7),
        'text': const Color(0xFF047857),
      };
    }
    if (s == 'en cours' || s == 'ongoing') {
      return {
        'label': 'ONGOING',
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFD97706),
      };
    }
    if (s == 'complet' || s == 'completed') {
      return {
        'label': 'COMPLETED',
        'bg': const Color(0xFFEDE9FE),
        'text': const Color(0xFF7C3AED),
      };
    }
    return {
      'label': s.toUpperCase(),
      'bg': const Color(0xFFEDE9FE),
      'text': const Color(0xFF7C3AED),
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = _getStatusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info['bg'],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        info['label'],
        style: TextStyle(
          color: info['text'],
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final ActivityModel activity;
  final bool isPreview;
  final String startDateLabel;
  final String endDateLabel;
  final int cancelledCount;

  const _HeroSummaryCard({
    required this.activity,
    required this.isPreview,
    required this.startDateLabel,
    required this.endDateLabel,
    required this.cancelledCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
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
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  activity.typeActivite.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF3858C8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const Spacer(),
              isPreview
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'PREVIEW',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    )
                  : _StatusBadge(status: activity.statut),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
              const SizedBox(width: 4),
              Text(
                activity.noteMoyenne.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2A44),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${activity.nombreAvis} reviews)',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activity.titre,
            style: const TextStyle(
              fontSize: 20,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2452),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.25,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _MiniInfoCard(
                label: 'PRICE',
                value: activity.prixFormatted,
                icon: Icons.payments_rounded,
              ),
              _MiniInfoCard(
                label: 'START DATE',
                value: startDateLabel,
                icon: Icons.event_available_rounded,
              ),
              _MiniInfoCard(
                label: 'END DATE',
                value: endDateLabel,
                icon: Icons.event_busy_rounded,
              ),
              if (!isPreview)
                _MiniInfoCard(
                  label: 'RESERVATIONS',
                  value: '${activity.nombreReservations}',
                  icon: Icons.event_note_rounded,
                ),
              _MiniInfoCard(
                label: 'CANCELLED',
                value: '$cancelledCount',
                icon: Icons.cancel_presentation_rounded,
              ),
              _MiniInfoCard(
                label: 'DURATION',
                value: activity.dureeFormatted,
                icon: Icons.timelapse_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniInfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF4A58A8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF5E6790),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF222B52),
              fontWeight: FontWeight.w700,
            ),
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
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D2652),
        ),
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  final Color filledColor;
  final IconData icon;

  const _TagWrap({
    required this.items,
    required this.emptyLabel,
    required this.filledColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: const TextStyle(color: Color(0xFF6A7294), fontSize: 15),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: filledColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: const Color(0xFF4E5BA6)),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3766),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LatLng? point;
  final String placeLabel;
  final String coordsLabel;

  const _LocationCard({
    required this.point,
    required this.placeLabel,
    required this.coordsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (point != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: point!, zoom: 13),
              markers: {
                Marker(
                  markerId: const MarkerId('meeting_point'),
                  position: point!,
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2EA3CC), Color(0xFF46B4D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(Icons.map_outlined, color: Colors.white, size: 54),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          placeLabel,
                          style: const TextStyle(
                            color: Color(0xFF1E2954),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          coordsLabel,
                          style: const TextStyle(
                            color: Color(0xFF5D678B),
                            fontSize: 11,
                          ),
                        ),
                      ],
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

class _OrganizerCard extends StatelessWidget {
  final Map<String, dynamic>? organizer;
  final bool canContact;
  final VoidCallback onContact;

  const _OrganizerCard({
    required this.organizer,
    required this.canContact,
    required this.onContact,
  });

  String _memberSince() {
    final raw = organizer?['createdAt'] ?? organizer?['created_at'];
    if (raw == null) return 'Member since 2021';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'Member since 2021';
    return 'Member since ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (organizer?['fullname'] ?? 'Organizer').toString();
    final avatar = organizer?['avatar']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORGANIZER',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: Color(0xFF7079A0),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: avatar.isNotEmpty
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  const Positioned(
                    bottom: -1,
                    right: -1,
                    child: Icon(
                      Icons.verified,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D2754),
                      ),
                    ),
                    Text(
                      _memberSince(),
                      style: const TextStyle(
                        color: Color(0xFF7B83A5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canContact) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContact,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFE0E7FF),
                  foregroundColor: const Color(0xFF273463),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Contact Organizer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final List<DateTime> dates;

  const _AvailabilityCard({required this.dates});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVAILABILITY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: Color(0xFF7079A0),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (dates.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No dates available.',
                style: TextStyle(color: Color(0xFF6A7294)),
              ),
            )
          else
            ...dates.take(6).map((d) {
              final now = DateTime.now();
              final isAvailable = !d.isBefore(now);
              final label =
                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A3462),
                        ),
                      ),
                    ),
                    Text(
                      isAvailable ? 'Available' : 'Fully Booked',
                      style: TextStyle(
                        color: isAvailable
                            ? const Color(0xFF2A4EFF)
                            : const Color(0xFFE23B67),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetaRow {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);
}

class _MetaInfoCard extends StatelessWidget {
  final List<_MetaRow> rows;
  const _MetaInfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: Color(0xFF56608B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.value.isEmpty ? '-' : r.value,
                        style: const TextStyle(
                          color: Color(0xFF1E2954),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
