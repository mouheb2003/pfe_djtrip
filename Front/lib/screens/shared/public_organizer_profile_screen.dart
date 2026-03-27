import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';

import 'activity_detail_screen.dart';
import 'chat_conversation_screen.dart';
import 'public_tourist_profile_screen.dart';

class PublicOrganizerProfileScreen extends StatefulWidget {
  final String? organizerId;

  const PublicOrganizerProfileScreen({super.key, this.organizerId});

  @override
  State<PublicOrganizerProfileScreen> createState() =>
      _PublicOrganizerProfileScreenState();
}

class _PublicOrganizerProfileScreenState
    extends State<PublicOrganizerProfileScreen> {
  bool _loading = true;
  UserModel? _organizer;
  List<ActivityModel> _activities = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _showAllActivities = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final targetId = widget.organizerId ?? await AuthService.getUserId();
    if (targetId == null || targetId.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final userFuture = UserService.getUserById(targetId);
    final activitiesFuture = ActivityService.getActivities();
    final reviewsFuture = ReviewService.getOrganizerReviews(targetId);

    final user = await userFuture;
    final allActivities = await activitiesFuture;
    final reviews = await reviewsFuture;

    final mine = allActivities.where((a) {
      final rawId = (a.organisateur?['_id'] ?? a.organisateur?['id'] ?? '')
          .toString();
      return rawId == targetId;
    }).toList();

    if (!mounted) return;
    setState(() {
      _organizer = user;
      _activities = mine;
      _reviews = reviews;
      _loading = false;
    });
  }

  String _resolveUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    if (value.startsWith('/')) {
      return '$serverUrl$value';
    }
    return '$serverUrl/$value';
  }

  String _headerImageUrl() {
    if (_activities.isNotEmpty && _activities.first.photos.isNotEmpty) {
      return _resolveUrl(_activities.first.photos.first);
    }
    return '';
  }

  String _organizerLocation(UserModel user) {
    if ((user.paysOrigine ?? '').trim().isNotEmpty) {
      return user.paysOrigine!.trim();
    }
    if (_activities.isNotEmpty && _activities.first.lieu.trim().isNotEmpty) {
      return _activities.first.lieu.trim();
    }
    return 'Tunisia';
  }

  List<String> _specialties() {
    final set = <String>{};
    for (final a in _activities) {
      if (a.typeActivite.trim().isNotEmpty) {
        set.add(a.typeActivite.trim());
      }
      for (final e in a.equipementsInclus) {
        if (e.trim().isNotEmpty) {
          set.add(e.trim());
        }
      }
      if (set.length >= 6) break;
    }
    if (set.isEmpty) {
      return const ['Adventure', 'Local Tours', 'Outdoor'];
    }
    return set.take(6).toList();
  }

  double _globalRating(UserModel user) {
    if (user.noteMoyenne > 0) return user.noteMoyenne;
    if (_activities.isEmpty) return 0;
    final sum = _activities.fold<double>(0, (p, a) => p + a.noteMoyenne);
    return sum / _activities.length;
  }

  List<double> _ratingBars(double rating) {
    // Keep static design values for now (requested): 77%, 6%, 3%.
    // TODO: replace with real rating distribution from backend when available.
    return const [0.77, 0.06, 0.03];
  }

  String _reviewerName(Map<String, dynamic> review) {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final name = (touriste['fullname'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Tourist';
  }

  String _reviewerAvatar(Map<String, dynamic> review) {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      return _resolveUrl(touriste['avatar']?.toString());
    }
    return '';
  }

  String _reviewText(Map<String, dynamic> review) {
    final text = (review['commentaire'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return 'No detailed comment provided.';
  }

  double _reviewRating(Map<String, dynamic> review) {
    return (review['note'] as num? ?? 0).toDouble().clamp(0, 5);
  }

  String _reviewDate(Map<String, dynamic> review) {
    final raw = (review['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  String _reviewerId(Map<String, dynamic> review) {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final id = (touriste['_id'] ?? touriste['id'] ?? '').toString();
      return id;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final user = _organizer;
    final avatarUrl = _resolveUrl(user?.avatar);
    final rating = user == null ? 0.0 : _globalRating(user);
    final reviewsCount = (user?.nombreAvis ?? 0) > 0
        ? user!.nombreAvis
        : (_activities.fold<int>(0, (p, a) => p + a.nombreAvis));
    final headerImageUrl = _headerImageUrl();
    final specialties = _specialties();
    final visibleActivities = _showAllActivities
        ? _activities
        : _activities.take(2).toList();
    final bars = _ratingBars(rating);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Organizer Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const Center(child: Text('Organizer not found.'))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 238,
                        width: double.infinity,
                        child: headerImageUrl.isNotEmpty
                            ? Image.network(
                                headerImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: const Color(0xFFCBD5E1)),
                              )
                            : Container(color: const Color(0xFFCBD5E1)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -44,
                        child: Center(
                          child: Container(
                            width: 92,
                            height: 92,
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFFE2E8F0),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF64748B),
                                      size: 34,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          user.fullname.isEmpty ? 'Organizer' : user.fullname,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 15,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($reviewsCount reviews)',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _organizerLocation(user),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatConversationScreen(
                                        partnerId: user.id,
                                        partnerName: user.fullname.isEmpty
                                            ? 'Organizer'
                                            : user.fullname,
                                        partnerAvatar: user.avatar,
                                        partnerOnline: user.isOnline,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble, size: 18),
                                label: const Text(
                                  'Message',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final link =
                                      'djtrip://profile/${user.id}?type=organizer';
                                  Share.share(
                                    'Profil DJTrip de ${user.fullname}\n$link\n(ouvre ce lien dans DJTrip)',
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                  ),
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  foregroundColor: const Color(0xFF111827),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'About Us',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            (user.bio ?? '').trim().isNotEmpty
                                ? user.bio!.trim()
                                : 'No organizer description yet.',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              height: 1.6,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ACTIVITY SPECIALTIES',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: specialties
                                .map(
                                  (s) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFFECBA1),
                                      ),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        color: Color(0xFFF97316),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Our Activities',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_activities.length > 2)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showAllActivities = !_showAllActivities;
                                  });
                                },
                                child: Text(
                                  _showAllActivities ? 'Reduce' : 'View all',
                                  style: const TextStyle(
                                    color: Color(0xFFF97316),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (visibleActivities.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text(
                              'No activities found.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        else
                          ...visibleActivities.map((a) {
                            final imageUrl = _resolveUrl(
                              a.photos.isNotEmpty ? a.photos.first : null,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ActivityMiniCard(
                                imageUrl: imageUrl,
                                title: a.titre,
                                price: a.prixFormatted,
                                rating: a.noteMoyenne > 0
                                    ? a.noteMoyenne.toStringAsFixed(1)
                                    : '0.0',
                                duration: a.dureeFormatted,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(
                                      activityId: a.id,
                                      viewOnly: true,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE5E7EB),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: const Color(0xFFF59E0B),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Global Rating',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 14),
                              _RatingRow(label: '5', value: bars[0]),
                              _RatingRow(label: '4', value: bars[1]),
                              _RatingRow(label: '3', value: bars[2]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_reviews.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'No reviews available for now.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        else
                          ..._reviews.take(4).map((r) {
                            final avatar = _reviewerAvatar(r);
                            final note = _reviewRating(r);
                            final reviewerId = _reviewerId(r);
                            return GestureDetector(
                              onTap: reviewerId.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PublicUserProfileScreen(
                                                userId: reviewerId,
                                              ),
                                        ),
                                      );
                                    },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(
                                            0xFFCBD5E1,
                                          ),
                                          backgroundImage: avatar.isNotEmpty
                                              ? NetworkImage(avatar)
                                              : null,
                                          child: avatar.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 16,
                                                  color: Color(0xFF64748B),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _reviewerName(r),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                _reviewDate(r),
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < note.round()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: const Color(0xFFF59E0B),
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _reviewText(r),
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ActivityMiniCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String rating;
  final String duration;
  final VoidCallback onTap;

  const _ActivityMiniCard({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.rating,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 94,
                height: 94,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[200]),
                      )
                    : Container(color: Colors.grey[200]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF64748B),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'From $price',
                        style: const TextStyle(
                          color: Color(0xFFF97316),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final double value;

  const _RatingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFD1D5DB),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF97316)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}
