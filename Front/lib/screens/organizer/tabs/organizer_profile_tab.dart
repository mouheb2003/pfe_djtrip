import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/review_service.dart';
import '../../../services/user_service.dart';
import '../../../services/inscription_service.dart';
import '../create_activity_screen.dart';
import '../organizer_main_screen.dart';
import '../../shared/activity_detail_screen.dart';
import '../../shared/edit_profile_screen.dart';
import '../../shared/settings_screen.dart';

class OrganizerProfileTab extends StatefulWidget {
  const OrganizerProfileTab({super.key});

  @override
  State<OrganizerProfileTab> createState() => _OrganizerProfileTabState();
}

class _OrganizerProfileTabState extends State<OrganizerProfileTab> {
  UserModel? _user;
  int _activitiesCount = 0;
  double _avgRating = 0.0;
  int _reviewsCount = 0;
  List<ActivityModel> _myActivities = [];
  List<String> _spokenLanguages = []; // 🚀 NEW: Organizer languages
  List<String> _specialties = []; // 🚀 NEW: Organizer specialties
  bool _isLoading = true;
  bool _isLoadingAll = false;

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
  }

  bool _looksLikeImageUrl(String value) {
    if (!_isValidHttpUrl(value)) return false;
    final lower = value.toLowerCase();
    if (lower.contains('cloudinary.com') ||
        lower.contains('googleusercontent.com') ||
        lower.contains('/upload/')) {
      return true;
    }
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.avif');
  }

  bool _matchesOrganizer(ActivityModel activity, String organizerId) {
    if (organizerId.isEmpty) return true;
    final rawId =
        (activity.organisateur?['_id'] ?? activity.organisateur?['id'] ?? '')
            .toString();
    return rawId == organizerId;
  }

  String _extractUrlFromDynamic(dynamic value) {
    if (value == null) return '';

    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return '';

      if (_looksLikeImageUrl(raw)) {
        return raw;
      }

      if (raw.startsWith('{') || raw.startsWith('[') || raw.contains('\\"')) {
        try {
          final decoded = jsonDecode(raw);
          return _extractUrlFromDynamic(decoded);
        } catch (_) {
          // Continue with regex fallback.
        }
      }

      final normalized = raw.replaceAll('\\/', '/');
      final match = RegExp(r'https?://[^"\s,\]]+').firstMatch(normalized);
      final candidate = match?.group(0) ?? '';
      return _looksLikeImageUrl(candidate) ? candidate : '';
    }

    if (value is List) {
      for (final item in value) {
        final url = _extractUrlFromDynamic(item);
        if (url.isNotEmpty) return url;
      }
      return '';
    }

    if (value is Map) {
      final keys = ['photos', 'photo', 'image', 'imageUrl', 'thumbnail'];
      for (final key in keys) {
        if (!value.containsKey(key)) continue;
        final url = _extractUrlFromDynamic(value[key]);
        if (url.isNotEmpty) return url;
      }
      return '';
    }

    return '';
  }

  String _resolveActivityImageUrl(ActivityModel activity) {
    final direct = _extractUrlFromDynamic(activity.thumbnailUrl);
    if (direct.isNotEmpty) return direct;
    return _extractUrlFromDynamic(activity.photos);
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }


  void _showAvatarFullScreen(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Avatar Full Screen',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(color: Colors.transparent),
                  ),
                  Center(
                    child: Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.70,
                        height: MediaQuery.of(context).size.width * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAll() async {
    if (_isLoadingAll) {
      if (kDebugMode) {
        debugPrint(
          '[REBUILD] OrganizerProfileTab skip _loadAll (already loading)',
        );
      }
      return;
    }

    _isLoadingAll = true;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userData = await UserService.getProfile(forceRefresh: true);
      final user = userData != null ? UserModel.fromJson(userData) : null;
      final targetId = (userData?['_id'] ?? '').toString();

      final results = await Future.wait([
        InscriptionService.getOrganizerStats(),
        ActivityService.getMyActivities(),
        ActivityService.getArchivedActivities(),
        ReviewService.getOrganizerReviews(targetId),
        ActivityService.getActivitiesByTimeline(),
      ]);

      if (!mounted) return;

      final stats = results[0] as Map<String, dynamic>;
      final activeActivities = results[1] as List<ActivityModel>;
      final archivedActivities = results[2] as List<ActivityModel>;
      final reviews = results[3] as List<Map<String, dynamic>>;
      final timeline = results[4] as Map<String, List<ActivityModel>>;
      final primaryActivities = <ActivityModel>[
        ...activeActivities,
        ...archivedActivities,
      ];
      final timelineActivities = <ActivityModel>[
        ...?timeline['upcoming'],
        ...?timeline['ongoing'],
        ...?timeline['past'],
      ];

      final byId = <String, ActivityModel>{};
      for (final activity in primaryActivities) {
        if (activity.id.isEmpty) continue;
        byId[activity.id] = activity;
      }

      if (byId.length < 9) {
        for (final activity in timelineActivities) {
          if (activity.id.isEmpty) continue;
          if (!_matchesOrganizer(activity, targetId)) continue;
          byId.putIfAbsent(activity.id, () => activity);
        }
      }

      final mine = byId.values.toList();

      final organizerAvgFromProfile = (user?.noteMoyenne ?? 0.0).clamp(
        0.0,
        5.0,
      );
      final organizerReviewsFromProfile = user?.nombreAvis ?? 0;

      final computedAverage = organizerAvgFromProfile > 0
          ? organizerAvgFromProfile
          : (mine.isNotEmpty
                ? mine.fold<double>(
                        0,
                        (sum, activity) => sum + activity.noteMoyenne,
                      ) /
                      mine.length
                : 0.0);
      final computedReviews = organizerReviewsFromProfile > 0
          ? organizerReviewsFromProfile
          : (reviews.isNotEmpty
                ? reviews.length
                : mine.fold<int>(
                    0,
                    (sum, activity) => sum + activity.nombreAvis,
                  ));

      setState(() {
        _user = user;
        _activitiesCount =
            (stats['activitiesCount'] as num?)?.toInt() ?? mine.length;
        _avgRating = computedAverage;
        _reviewsCount = computedReviews;
        _myActivities = mine;

        // 🚀 NEW: Load languages and specialties
        if (userData != null) {
          final rawLangs = (userData['langues_proposees'] as List?) ?? const [];
          _spokenLanguages = rawLangs.map((e) => e.toString()).toList();

          final rawSpecs = (userData['specialites_activites'] as List?) ?? const [];
          _specialties = rawSpecs.map((e) => e.toString()).toList();
        }

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    } finally {
      _isLoadingAll = false;
    }
  }

  String _displayLocation() {
    final raw = _user?.paysOrigine?.trim() ?? '';
    if (raw.isEmpty) return 'DJERBA, TUNISIA';
    return raw.toUpperCase();
  }

  String _safeBio() {
    final bio = _user?.bio?.trim() ?? '';
    if (bio.isNotEmpty) return bio;
    return 'Passionate activity organizer sharing memorable experiences.';
  }

  // ─── Cover Photo URL ──────────────────────────────────────────────
  static const String _coverImage =
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80';

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('[REBUILD] OrganizerProfileTab build');
    }

    final user = _user;
    final topActivities = List<ActivityModel>.from(_myActivities)
      ..sort((a, b) {
        final dateA =
            a.dateDebut ?? a.dateFin ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            b.dateDebut ?? b.dateFin ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    final profileActivities = topActivities.take(9).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          elevation: 6,
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
            );
            if (created == true) _loadAll();
          },
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 100),
            children: [
              // ── Header Row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final nav = Navigator.of(context);
                        if (nav.canPop()) nav.pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.primary,
                    ),
                    const Expanded(
                      child: Text(
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF131A4A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final user = _user;
                        if (user == null) return;
                        final profileUrl = 'https://djtrip.com/profile/${user.id}';
                        final text = 'Check out ${user.fullname ?? 'this organizer'} on DJTrip!';
                        await Share.share('$text\n$profileUrl');
                      },
                      icon: const Icon(Icons.share),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ── Cover Photo + Avatar ────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Cover photo
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Image.network(
                          _coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF4D74F5), Color(0xFF7B93FF)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Avatar overlapping the cover (Instagram style with blurred glow)
                  Positioned(
                    bottom: -50,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Blurred Glow Background
                        if (user?.avatar != null)
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.15),
                                image: DecorationImage(
                                  image: NetworkImage(user!.avatar!),
                                  fit: BoxFit.cover,
                                  opacity: 0.6,
                                ),
                              ),
                            ),
                          ),
                        
                        // Main Avatar with White Border
                        GestureDetector(
                          onTap: () => _showAvatarFullScreen(user?.avatar),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: 'profile_avatar',
                              child: ClipOval(
                                child: user?.avatar != null
                                    ? Image.network(
                                        user!.avatar!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _DefaultAvatar(),
                                      )
                                    : _DefaultAvatar(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 56),

              // ── Badge ───────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      const Text(
                        'ORGANIZER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Name ────────────────────────────────────────────────
               Text(
                user?.fullname ?? 'Organizer',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2458),
                ),
              ),
              const SizedBox(height: 8),

              // ── Location ───────────────────────────────────────────────
              Text(
                _displayLocation(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              // ── Bio ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _safeBio(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF56608B),
                  ),
                ),
              ),
              if (_specialties.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _specialties
                        .map((s) => _SpecialtyChip(label: s))
                        .toList(),
                  ),
                ),
              ],
              if (_spokenLanguages.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _spokenLanguages
                        .map((l) => _LanguageChip(label: l))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _OrganizerStatsRow(
                activities: _activitiesCount,
                rate: _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '0.0',
                reviews: _reviewsCount,
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Action Buttons ────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadAll()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text('Edit Profile'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8E8F6),
                              side: BorderSide.none,
                              foregroundColor: const Color(0xFF46508A),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text('Settings'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Create Activity ────────────
                    InkWell(
                      onTap: () async {
                        final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateActivityScreen()));
                        if (created == true) _loadAll();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: _user?.avatar != null ? NetworkImage(_user!.avatar!) : null,
                              child: _user?.avatar == null ? const Icon(Icons.person, size: 16) : null,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('Tap to create a new activity', style: TextStyle(color: Color(0xFF8C90B3), fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            Icon(Icons.add_circle_outline, color: AppColors.primary.withOpacity(0.7)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── My Activities ────────────
                    const Text('MANAGED', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Row(
                      children: [
                        const Text('My Activities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B2458))),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizerMainScreen(initialIndex: 1))),
                          child: const Text('VIEW ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (profileActivities.isEmpty)
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Center(child: Text('No activities yet', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600))),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: profileActivities.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1),
                        itemBuilder: (context, index) {
                          final activity = profileActivities[index];
                          return _ActivityTile(
                            imageUrl: _resolveActivityImageUrl(activity),
                            onTap: activity.id.isEmpty
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ActivityDetailScreen(activityId: activity.id, viewOnly: true)),
                                    ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const _StatItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 3),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6F7396),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}


class _ActivityTile extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const _ActivityTile({required this.imageUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onTap,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8E8F6),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Color(0xFF8C93BE),
                            size: 30,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE8E8F6),
                      child: const Center(
                        child: Icon(
                          Icons.terrain_rounded,
                          color: Color(0xFF8C93BE),
                          size: 30,
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
class _LanguageChip extends StatelessWidget {
  final String label;

  const _LanguageChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE1FEE7), // Soft green for languages
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF065F46),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    // Member colors updated to Blue as requested
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft blue for specialties
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E40AF),
        ),
      ),
    );
  }
}

class _OrganizerBioCard extends StatelessWidget {
  final String bio;
  const _OrganizerBioCard({required this.bio});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        bio,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF56608B)),
      ),
    );
  }
}

class _OrganizerLocationCard extends StatelessWidget {
  final String country, subLocation;
  const _OrganizerLocationCard({required this.country, required this.subLocation});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        country.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _OrganizerSpecialtiesCard extends StatelessWidget {
  final List<String> specialties;
  const _OrganizerSpecialtiesCard({required this.specialties});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: specialties.map((s) => _SpecialtyChip(label: s)).toList(),
      ),
    );
  }
}

class _OrganizerLanguagesCard extends StatelessWidget {
  final List<String> languages;
  const _OrganizerLanguagesCard({required this.languages});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: languages.map((l) => _LanguageChip(label: l)).toList(),
      ),
    );
  }
}

class _OrganizerStatsRow extends StatelessWidget {
  final int activities, reviews;
  final String rate;
  const _OrganizerStatsRow({
    required this.activities,
    required this.rate,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StatCardItem(label: 'ACTIVITIES', value: activities.toString()),
          Container(width: 1, height: 34, color: const Color(0xFFD8D9EC)),
          _StatCardItem(label: 'RATE', value: rate),
          Container(width: 1, height: 34, color: const Color(0xFFD8D9EC)),
          _StatCardItem(label: 'REVIEWS', value: reviews.toString()),
        ],
      ),
    );
  }
}

class _StatCardItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatCardItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'RATE')
                const Icon(
                  Icons.star,
                  size: 16,
                  color: Color(0xFFFFC107),
                ),
              if (label == 'RATE') const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF131A4A),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6F7396),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E7F6),
      child: const Icon(
        Icons.person,
        size: 42,
        color: Color(0xFF8892AE),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.edit,
        size: 15,
        color: Colors.white,
      ),
    );
  }
}
