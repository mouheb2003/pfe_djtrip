import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
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
  UserModel? _user;
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
    if (user != null && user.isOrganisator) {
      final mine = activities.where((a) {
        final orgId = (a.organisateur?['_id'] ?? a.organisateur?['id'] ?? '')
            .toString();
        return orgId == user.id;
      }).toList();
      reservationsCount = mine.fold<int>(0, (p, a) => p + a.nombreReservations);
      recent = mine.take(2).toList();
    } else {
      // Public stats for another tourist are not exposed by backend for now.
      // If this is my own profile, use secured tourist stats endpoint.
      if (user != null && user.id == currentUserId) {
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
    final avatarUrl = _resolveUrl(user?.avatar);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'DJTrip Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const Center(child: Text('Profile not found.'))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    Center(
                      child: Container(
                        width: 176,
                        height: 176,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFED7C3),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 56,
                                  color: Color(0xFF64748B),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.fullname.isEmpty ? 'DJTrip User' : user.fullname,
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
                          Icons.location_on,
                          color: Color(0xFFF97316),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (user.paysOrigine ?? '').trim().isNotEmpty
                              ? user.paysOrigine!.trim()
                              : 'Tunisia',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (user.bio ?? '').trim().isNotEmpty
                          ? user.bio!.trim()
                          : 'Explorer and adventure lover.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: _reservationsCount.toString(),
                            label: 'RESERVATIONS',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: _favoritesCount.toString(),
                            label: 'FAVORITES',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: user.nombreAvis.toString(),
                            label: 'REVIEWS',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          (user.centresInteret.isNotEmpty
                                  ? user.centresInteret
                                  : const ['Adventure', 'Culture'])
                              .map(
                                (i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFFECBA1),
                                    ),
                                  ),
                                  child: Text(
                                    i,
                                    style: const TextStyle(
                                      color: Color(0xFFF97316),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_recentActivities.isEmpty)
                      const Text(
                        'No activities to show.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentActivities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final a = _recentActivities[i];
                            final photo = _resolveUrl(
                              a.photos.isNotEmpty ? a.photos.first : null,
                            );
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(
                                      activityId: a.id,
                                      viewOnly: true,
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 230,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: SizedBox(
                                        height: 150,
                                        width: 230,
                                        child: photo.isNotEmpty
                                            ? Image.network(
                                                photo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color: const Color(
                                                        0xFFCBD5E1,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                color: const Color(0xFFCBD5E1),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      a.titre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
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
                                          a.noteMoyenne.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Color(0xFF334155),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatConversationScreen(
                            partnerId: user.id,
                            partnerName: user.fullname.isEmpty
                                ? 'DJTrip User'
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
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text(
                      'Message',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
