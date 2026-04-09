import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';

import 'activity_detail_screen.dart';
import 'chat_conversation_screen.dart';

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
  Map<String, dynamic>? _organizer;
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
    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
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

  String _organizerLocation(Map<String, dynamic> user) {
    if ((user['paysOrigine'] ?? '').trim().isNotEmpty) {
      return user['paysOrigine']!.trim();
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

  double _globalRating(Map<String, dynamic> user) {
    if ((user['noteMoyenne'] ?? 0) > 0) return user['noteMoyenne']!.toDouble();
    if (_activities.isEmpty) return 0;
    final sum = _activities.fold<double>(0, (p, a) => p + a.noteMoyenne);
    return sum / _activities.length;
  }

  List<double> _ratingBars(double rating) {
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
    if (text.isEmpty) return 'No comment provided.';
    return text;
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
    final avatarUrl = _resolveUrl(user?['avatar']);
    final rating = user == null ? 0.0 : _globalRating(user);
    final reviewsCount = (user?['nombreAvis'] ?? 0) > 0
        ? user!['nombreAvis']
        : (_activities.fold<int>(0, (p, a) => p + a.nombreAvis));
    final headerImageUrl = _headerImageUrl();
    final specialties = _specialties();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
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
                  // Cover image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0)),
                    child: headerImageUrl.isNotEmpty
                        ? Image.network(
                            headerImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.expand(),
                          )
                        : const SizedBox.expand(),
                  ),
                  const SizedBox(height: 16),
                  // Profile info section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _DefaultAvatar(),
                                  )
                                : _DefaultAvatar(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Name
                        Text(
                          (user['fullname'] ?? '').isEmpty
                              ? 'Organizer'
                              : user['fullname']!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Bio/Quote
                        Text(
                          (user['bio'] ?? '').isEmpty
                              ? 'Travel Expert'
                              : user['bio']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Stats row: rating / reviews / activities
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: const Color(0xFFF59E0B),
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  reviewsCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'REVIEWS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  _activities.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'ACTIVITIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Contact button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(
                                    partnerId: user['_id'] ?? '',
                                    partnerName:
                                        (user['fullname'] ?? '').isEmpty
                                        ? 'Organizer'
                                        : user['fullname']!,
                                    partnerAvatar: user['avatar'],
                                    partnerOnline: user['isOnline'] ?? false,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.mail_outline, size: 18),
                            label: const Text(
                              'Contact Me',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Specialties section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SPECIALTIES',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
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
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      color: Color(0xFF5D71FF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // My Activities section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Activities',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_activities.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              // Navigate to all activities view
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Activities grid
                  if (_activities.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No activities yet.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                        itemCount: _activities.length,
                        itemBuilder: (ctx, i) {
                          final activity = _activities[i];
                          final imageUrl = _resolveUrl(
                            activity.photos.isNotEmpty
                                ? activity.photos.first
                                : null,
                          );
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityDetailScreen(
                                  activityId: activity.id,
                                  viewOnly: true,
                                ),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFFF0F0F0),
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFF0F0F0),
                                        child: const Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _RatingRow({required String label, required double value}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            minHeight: 4,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toInt()}%',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}

class _ActivityMiniCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String price;
  final String rating;
  final VoidCallback? onTap;

  const _ActivityMiniCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: imageUrl == null ? const Color(0xFFF0F0F0) : null,
              ),
              child: imageUrl == null
                  ? const Icon(Icons.image, color: Colors.grey, size: 32)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF59E0B),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(Icons.person, color: Color(0xFF64748B), size: 34),
    );
  }
}
