import 'dart:convert';

import 'package:flutter/material.dart';

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
  List<String> _specialties = [];
  List<ActivityModel> _myActivities = [];
  bool _isLoading = true;

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

  Future<void> _loadAll() async {
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

      // Keep organizer endpoints as source of truth, then backfill from timeline if needed.
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

      // Prefer organizer-level fields from DB, fallback to activity/review aggregation.
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

        if (userData != null && userData['specialites_activites'] != null) {
          _specialties = List<String>.from(
            userData['specialites_activites'] ?? [],
          );
        } else {
          _specialties = mine
              .map((a) => a.typeActivite.trim())
              .where((v) => v.isNotEmpty)
              .take(6)
              .toList();
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80';
    final bioText = (_user?.bio ?? '').trim().isNotEmpty
        ? (_user?.bio ?? '')
        : 'Passionate activity organizer sharing memorable experiences in Tunisia.';
    final displaySpecialties = _specialties
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
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
      backgroundColor: const Color(0xFFF3F2FB),
      floatingActionButton: SizedBox(
        width: 66,
        height: 66,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF4D74F5),
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
            );
            if (created == true) _loadAll();
          },
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Organizer',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: Color(0xFF1A2254),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Color(0xFF6A6F91),
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFFCFDCF2)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -54,
                      child: CircleAvatar(
                        radius: 66,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 61,
                          backgroundColor: const Color(0xFFE2E7F6),
                          backgroundImage: (_user?.avatar ?? '').isNotEmpty
                              ? NetworkImage(_user!.avatar!)
                              : null,
                          child: (_user?.avatar ?? '').isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 46,
                                  color: Color(0xFF8892AE),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 64),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E61F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'ORGANISATOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _user?.fullname ?? 'Organizer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFF1A2254),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: Color(0xFF686E92),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _user?.paysOrigine?.trim().isNotEmpty == true
                            ? (_user?.paysOrigine ?? 'Djerba, Tunisia')
                            : 'Djerba, Tunisia',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF686E92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEBFA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'BIO',
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 3.2,
                          color: Color(0xFF525B8D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        bioText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.45,
                          color: Color(0xFF1D2557),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'SPECIAL ACTIVITIES',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.6,
                          color: Color(0xFF525B8D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children:
                            (displaySpecialties.isNotEmpty
                                    ? displaySpecialties
                                    : [
                                        'Water Sports',
                                        'Excursions',
                                        'Luxury Sailing',
                                      ])
                                .map((label) => _SpecialtyChip(label))
                                .toList(),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              value: _avgRating > 0
                                  ? _avgRating.toStringAsFixed(1)
                                  : '0.0',
                              label: 'RATING',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              value: _reviewsCount.toString(),
                              label: 'REVIEWS',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              value: _activitiesCount.toString(),
                              label: 'ACTIVITIES',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final tileSize = (constraints.maxWidth - (spacing * 2)) / 3;
                    if (profileActivities.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Aligne tout à gauche par défaut
                      children: [
                        // 1. BLOC DES BOUTONS (EDIT & SETTINGS)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                ).then((_) => _loadAll()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text('Edit Profile'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE8E8F6),
                                  side: BorderSide.none,
                                  foregroundColor: const Color(0xFF46508A),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text('Settings'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 2. BLOC TITRE "MY ACTIVITIES" AVEC LIGNE ET BOUTON VIEW ALL
                        Row(
                          crossAxisAlignment: CrossAxisAlignment
                              .end, // Aligne le bas du titre et du bouton
                          children: [
                            // Utilisation d'une Column ici pour que le Container soit SOUS le texte
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'My Activities',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A2254),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 64, // Largeur de la ligne bleue
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E61F0),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(), // Pousse le bouton VIEW ALL vers la droite

                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OrganizerMainScreen(
                                      initialIndex: 1,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1C52E5),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'VIEW ALL',
                                style: TextStyle(
                                  fontSize: 14,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 3. LA GRILLE D'ACTIVITÉS (WRAP)
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: profileActivities.map((activity) {
                            return SizedBox(
                              width: tileSize,
                              height: tileSize,
                              child: _ActivityTile(
                                imageUrl: _resolveActivityImageUrl(activity),
                                onTap: activity.id.isEmpty
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ActivityDetailScreen(
                                                  activityId: activity.id,
                                                  viewOnly: true,
                                                ),
                                          ),
                                        );
                                      },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1C52E5),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.8,
            color: Color(0xFF2D3562),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC6C6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF2E3CA3),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD9DFF0),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      color: Color(0xFF8A94B2),
                      size: 30,
                    ),
                  )
                : const Icon(Icons.image, color: Color(0xFF8A94B2), size: 30),
          ),
        ),
      ),
    );
  }
}
