import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

import 'activity_detail_screen.dart';
import 'chat_conversation_screen.dart';
import 'edit_review_modal.dart';
import '../notifications_screen.dart';

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
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final targetId = widget.organizerId ?? await AuthService.getUserId();
    final currentUserId = await AuthService.getUserId();
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
      _currentUserId = currentUserId ?? '';
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

  static String _reviewerName(Map<String, dynamic> review) {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final name = (touriste['fullname'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Tourist';
  }

  static String _reviewerAvatar(Map<String, dynamic> review) {
    final touriste = review['touriste_id'];
    if (touriste is Map<String, dynamic>) {
      final avatar = (touriste['avatar'] ?? '').toString();
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return avatar;
      }
      final serverUrl = ApiClient.baseUrl.replaceFirst(
        RegExp(r'/api(?:/v1)?$'),
        '',
      );
      if (avatar.startsWith('/')) {
        return '$serverUrl$avatar';
      }
      return '$serverUrl/$avatar';
    }
    return '';
  }

  static String _reviewText(Map<String, dynamic> review) {
    final text = (review['commentaire'] ?? '').toString().trim();
    if (text.isEmpty) return 'No comment provided.';
    return text;
  }

  static String _reviewDate(Map<String, dynamic> review) {
    final raw = (review['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  static String _reviewerId(Map<String, dynamic> review) {
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
      backgroundColor: const Color(0xFFF2F1FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Color(0xFF131A4A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.primary),
            onPressed: () async {
              final profileUrl = 'https://djtrip.com/profile/${user?['_id']}';
              final text = 'Check out ${user?['fullname'] ?? 'this organizer'} on DJTrip!';
              await Share.share('$text\n$profileUrl');
            },
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
                  // Cover image + Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Cover photo
                      Container(
                        height: 160,
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
                      // Avatar
                      Positioned(
                        bottom: -50,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  // Badge
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
                      child: Text(
                        'ORGANIZER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Name
                  Text(
                    (user['fullname'] ?? '').isEmpty
                        ? 'Organizer'
                        : user['fullname']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2458),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Location
                  Text(
                    _organizerLocation(user).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      (user['bio'] ?? '').isEmpty
                          ? 'Passionate activity organizer sharing memorable experiences.'
                          : user['bio']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF56608B),
                      ),
                    ),
                  ),
                  // Specialties
                  if (specialties.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
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
                                  color: const Color(0xFFE8EDFF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B4A8F),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              value: _activities.length.toString(),
                              label: 'Activities',
                            ),
                          ),
                          Container(width: 1, height: 34, color: const Color(0xFFD8D9EC)),
                          Expanded(
                            child: _StatItem(
                              value: rating.toStringAsFixed(1),
                              label: 'Rating',
                              showStar: true,
                            ),
                          ),
                          Container(width: 1, height: 34, color: const Color(0xFFD8D9EC)),
                          Expanded(
                            child: _StatItem(
                              value: reviewsCount.toString(),
                              label: 'Reviews',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Contact button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text(
                          'Contact Me',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
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
                          'Activities',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2458),
                          ),
                        ),
                        Row(
                          children: [
                            // Notification icon
                            Stack(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications_outlined, color: AppColors.primary),
                                  onPressed: () {
                                    // Navigate to notifications screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                                if (false) // TODO: Replace with actual unread count check
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '3',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_activities.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() => _showAllActivities = true);
                                },
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
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
                  // Reviews section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_reviews.isNotEmpty)
                          Text(
                            '${_reviews.length} reviews',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
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
                          'No reviews yet.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: _reviews.map((review) => _OrganizerReviewCard(
                          review: review,
                          currentUserId: _currentUserId,
                          onReviewUpdated: _loadData,
                        )).toList(),
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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool showStar;

  const _StatItem({
    required this.value,
    required this.label,
    this.showStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStar)
              const Icon(
                Icons.star,
                size: 16,
                color: Color(0xFFFFC107),
              ),
            if (showStar) const SizedBox(width: 4),
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
    );
  }
}

class _OrganizerReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final String currentUserId;
  final VoidCallback? onReviewUpdated;
  const _OrganizerReviewCard({
    required this.review,
    required this.currentUserId,
    this.onReviewUpdated,
  });

  bool _isMyReview() {
    final touristeId = _PublicOrganizerProfileScreenState._reviewerId(review);
    return touristeId == currentUserId;
  }

  void _showEditDeleteOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF4B63FF)),
              title: const Text('Edit Review'),
              onTap: () {
                Navigator.pop(context);
                _openEditModal(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Review'),
              onTap: () {
                Navigator.pop(context);
                _openDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditReviewModal(
        avisId: review['_id'].toString(),
        type: 'organisateur',
        initialRating: (review['note'] ?? 0).toDouble(),
        initialComment: review['commentaire']?.toString(),
        initialTags: review['tags'] is List ? List<String>.from(review['tags'] as List) : null,
        onReviewUpdated: onReviewUpdated,
        onReviewDeleted: onReviewUpdated,
      ),
    );
  }

  void _openDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final avisId = review['_id'].toString();
              final success = await ReviewService.deleteReview(avisId);
              if (success && onReviewUpdated != null) {
                onReviewUpdated!();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = (review['note'] ?? 0).toInt();
    final avatar = _PublicOrganizerProfileScreenState._reviewerAvatar(review);
    final isMyReview = _isMyReview();

    return InkWell(
      onLongPress: isMyReview ? () => _showEditDeleteOptions(context) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMyReview ? const Color(0xFF4B63FF) : const Color(0xFFE5E7EB),
            width: isMyReview ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar.isEmpty ? const Icon(Icons.person, size: 20) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _PublicOrganizerProfileScreenState._reviewerName(review),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (isMyReview) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4B63FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit,
                              size: 14,
                              color: Color(0xFF4B63FF),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          ...List.generate(5, (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFF59E0B),
                            size: 14,
                          )),
                          const SizedBox(width: 8),
                          Text(
                            _PublicOrganizerProfileScreenState._reviewDate(review),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _PublicOrganizerProfileScreenState._reviewText(review),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
            if (isMyReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Long press to edit or delete your review',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B63FF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
