import 'package:flutter/material.dart';
import 'dart:convert';
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

  const PublicUserProfileScreen({super.key, required this.userId});

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  int _favoritesCount = 0;
  int _reservationsCount = 0;
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
    } catch (_) {}

    int reservationsCount = 0;
    List<ActivityModel> recent = [];
    if (user != null && user['isOrganisator'] == true) {
      final mine = activities.where((a) {
        final orgId = (a.organisateur?['_id'] ?? a.organisateur?['id'] ?? '')
            .toString();
        return orgId == user['_id'];
      }).toList();
      reservationsCount = mine.fold<int>(0, (p, a) => p + a.nombreAvis);
      recent = mine.take(2).toList();
    } else {
      // Public stats for another tourist are not exposed by backend for now.
      // If this is my own profile, use secured tourist stats endpoint.
      if (user != null && user['_id'] == currentUserId) {
        final touristStats = await InscriptionService.getTouristStats();
        reservationsCount = (touristStats['totalBookings'] as num? ?? 0)
            .toInt();
      }
      recent = activities.take(2).toList();
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _favoritesCount = favoritesCount;
      _reservationsCount = reservationsCount;
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
    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    if (value.startsWith('/')) {
      return '$serverUrl$value';
    }
    return '$serverUrl/$value';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final avatarUrl = _resolveUrl(user?['avatar']);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Text(
          (user?['fullname'] ?? '').isEmpty ? 'DJTrip User' : user!['fullname']!,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              backgroundColor: Colors.grey[200],
                              child: avatarUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 32,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (user?['fullname'] ?? '').isEmpty ? 'DJTrip User' : user!['fullname']!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${widget.userId}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.favorite,
                                label: 'Favorites',
                                value: _favoritesCount.toString(),
                                color: const Color(0xFFE91E63),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.calendar_today,
                                label: 'Reservations',
                                value: _reservationsCount.toString(),
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Location
                        if ((user?['paysOrigine'] ?? '').trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0F172A),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    user?['paysOrigine']?.trim() ?? 'No location specified',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Bio
                        if ((user?['bio'] ?? '').trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?['bio']?.trim() ?? 'No bio provided.',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Interests
                        if ((user?['centresInteret'] as List?)?.isNotEmpty ?? false)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interests',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: (user?['centresInteret'] as List? ?? [])
                                      .map((interest) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              interest.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Recent Activities
                        const Text(
                          'Recent Activities',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_recentActivities.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No activities found.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        else
                          ..._recentActivities.map((activity) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: _ActivityCard(
                                activity: activity,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(
                                      activityId: activity.id,
                                      viewOnly: true,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;

  const _ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = activity.photos.isNotEmpty
        ? '${ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '')}/uploads/${activity.photos.first}'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 180,
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
            // Image
            Container(
              width: 160,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: imageUrl == null ? const Color(0xFFF0F0F0) : null,
              ),
              child: imageUrl == null
                  ? const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 32,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.titre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activity.lieu,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.noteMoyenne > 0
                                  ? activity.noteMoyenne.toStringAsFixed(1)
                                  : '0.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${activity.nombreAvis} reviews)',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activity.prixFormatted,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            activity.dureeFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
