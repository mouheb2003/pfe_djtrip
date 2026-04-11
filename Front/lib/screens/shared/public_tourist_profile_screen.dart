import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/inscription_service.dart';
import '../../services/user_service.dart';
import 'activity_detail_screen.dart';
import 'chat_conversation_screen.dart';

class PublicUserProfileScreen extends StatefulWidget {
  final String userId;
  final bool canContact;
  final VoidCallback? onContact;

  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    this.canContact = false,
    this.onContact,
  });

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  int _favoritesCount = 0;
  int _reservationsCount = 0;
  int _reviewsCount = 0;
  List<ActivityModel> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userFuture = UserService.getUserById(widget.userId);
    final activitiesFuture = ActivityService.getActivities();

    final user = await userFuture;
    final activities = await activitiesFuture;
    final currentUserId = await AuthService.getUserId();

    int favoritesCount = 0;
    try {
      final res = await ApiClient.get('/users/${widget.userId}', auth: false);
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as Map<String, dynamic>;
        final u = (raw['user'] ?? raw) as Map<String, dynamic>;
        final favorites = u['favorites'];
        if (favorites is List) {
          favoritesCount = favorites.length;
        }
      }
    } catch (_) {
      // Best effort only, endpoint may vary by role/privacy.
    }

    int reservationsCount = 0;
    int reviewsCount = 0;
    List<ActivityModel> recent = [];

    final mine = activities.where((a) {
      final orgId = (a.organisateur?['_id'] ?? a.organisateur?['id'] ?? '')
          .toString();
      return orgId == (user?['_id'] ?? '').toString();
    }).toList();

    if (user != null && user['isOrganisator'] == true) {
      reservationsCount = mine.fold<int>(0, (p, a) => p + a.nombreReservations);
      reviewsCount = mine.fold<int>(0, (p, a) => p + a.nombreAvis);
      recent = mine;
    } else {
      if (user != null && user['_id'] == currentUserId) {
        final touristStats = await InscriptionService.getTouristStats();
        reservationsCount = (touristStats['totalBookings'] as num? ?? 0)
            .toInt();
      }
      reviewsCount = (user?['nombreAvis'] as num? ?? 0).toInt();
      recent = activities;
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _favoritesCount = favoritesCount;
      _reservationsCount = reservationsCount;
      _reviewsCount = reviewsCount;
      _recentActivities = recent;
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

  String _coverImageUrl() {
    final direct = _resolveUrl(_user?['coverImage']?.toString());
    if (direct.isNotEmpty) return direct;
    if (_recentActivities.isNotEmpty &&
        _recentActivities.first.photos.isNotEmpty) {
      return _resolveUrl(_recentActivities.first.photos.first);
    }
    return '';
  }

  List<String> _interests() {
    final raw = (_user?['centresInteret'] as List?) ?? const [];
    final items = raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (items.isNotEmpty) return items;
    return const ['Water Sports', 'Culture', 'Gastronomy', 'Photography'];
  }

  Future<void> _handleContact() async {
    if (widget.onContact != null) {
      widget.onContact!.call();
      return;
    }

    final user = _user;
    if (user == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          partnerId: (user['_id'] ?? '').toString(),
          partnerName: ((user['fullname'] ?? '').toString().trim().isEmpty)
              ? 'Tourist'
              : user['fullname'].toString(),
          partnerAvatar: user['avatar'],
          partnerOnline: user['isOnline'] ?? false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final avatarUrl = _resolveUrl(user?['avatar']?.toString());
    final coverUrl = _coverImageUrl();
    final interests = _interests();

    final displayName = ((user?['fullname'] ?? '').toString().trim().isEmpty)
        ? 'Tourist'
        : user!['fullname'].toString().trim();

    final subtitle = ((user?['bio'] ?? '').toString().trim().isEmpty)
        ? 'Passionate traveler'
        : user!['bio'].toString().trim();

    final postsCount = _recentActivities.length;
    final gridItems = _recentActivities.take(6).toList();
    final extraCount = postsCount > 6 ? postsCount - 6 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF5D71FF),
            size: 18,
          ),
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
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF5D71FF)),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF9CD3F7)),
                          )
                        : Container(color: const Color(0xFF9CD3F7)),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.14),
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
                                      _defaultAvatar(),
                                )
                              : _defaultAvatar(),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF343051),
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6D6A87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _statItem(
                                    _reservationsCount.toString(),
                                    'BOOKINGS',
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: const Color(0xFFE8EAF1),
                                ),
                                Expanded(
                                  child: _statItem(
                                    _favoritesCount.toString(),
                                    'FAVORITES',
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: const Color(0xFFE8EAF1),
                                ),
                                Expanded(
                                  child: _statItem(
                                    _reviewsCount.toString(),
                                    'REVIEWS',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'INTERESTS',
                              style: TextStyle(
                                color: const Color(0xFF7E7AA8).withOpacity(0.9),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: interests
                                  .map(
                                    (interest) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD9D6FF),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        interest,
                                        style: const TextStyle(
                                          color: Color(0xFF5D71FF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  (widget.canContact ||
                                      widget.onContact != null)
                                  ? _handleContact
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3560F5),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFB6BEE9,
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 17,
                              ),
                              label: const Text(
                                'Contact Me',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Posts',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF343051),
                                  height: 1,
                                ),
                              ),
                              if (postsCount > 0)
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF3560F5),
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (postsCount == 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No posts yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF6D6A87)),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: gridItems.length,
                              itemBuilder: (ctx, i) {
                                final activity = gridItems[i];
                                final imageUrl = activity.photos.isNotEmpty
                                    ? _resolveUrl(activity.photos.first)
                                    : '';
                                final isLast = i == gridItems.length - 1;
                                final showPlus = extraCount > 0 && isLast;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ActivityDetailScreen(
                                          activityId: activity.id,
                                          viewOnly: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color: const Color(
                                                        0xFFE5E7EB,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: const Color(0xFFE5E7EB),
                                              ),
                                        if (showPlus)
                                          Container(
                                            color: const Color(
                                              0xFF0F172A,
                                            ).withOpacity(0.45),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '+$extraCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3560F5),
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9995B4),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(Icons.person, color: Color(0xFF64748B), size: 34),
    );
  }
}
