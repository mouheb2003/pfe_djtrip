import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/inscription_model.dart';
import '../../../services/user_service.dart';
import '../../../services/inscription_service.dart';
import '../../shared/edit_profile_screen.dart';
import '../../shared/settings_screen.dart';
import '../../shared/activity_detail_screen.dart';
import 'favorites_screen.dart';

class TouristProfileTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const TouristProfileTab({super.key, this.onNavigateToTab});

  @override
  State<TouristProfileTab> createState() => _TouristProfileTabState();
}

class _TouristProfileTabState extends State<TouristProfileTab> {
  UserModel? _user;
  int _postsCount = 0;
  int _followers = 0;
  int _following = 0;
  bool _savingInterests = false;
  List<InscriptionModel> _recentActivities = [];
  String _selectedTab = 'Posts';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final recentActivitiesFuture = InscriptionService.getMyInscriptions(
      statut: 'approuvee',
    ).catchError((_) => <InscriptionModel>[]);
    final results = await Future.wait([
      UserService.getProfile(),
      InscriptionService.getTouristStats(),
      UserService.getFavorites(),
      recentActivitiesFuture,
    ]);
    if (!mounted) return;

    final userData = results[0] as Map<String, dynamic>?;
    final user = userData != null ? UserModel.fromJson(userData) : null;

    setState(() {
      _user = user;
      final stats = results[1] as Map<String, dynamic>;
      _postsCount = (stats['totalBookings'] as num?)?.toInt() ?? 0;
      _followers = (stats['followers'] as num?)?.toInt() ?? 1200;
      _following = (stats['following'] as num?)?.toInt() ?? 500;
      _recentActivities = (results[3] as List<InscriptionModel>)
          .where((i) => i.statut == 'approuvee')
          .take(6)
          .toList();
    });
  }

  Future<void> _removeInterest(String interest) async {
    if (_user == null || _savingInterests) return;
    final updated = _user!.centresInteret.where((e) => e != interest).toList();

    setState(() => _savingInterests = true);
    final ok = await UserService.updateInterests(_user!.id, updated);
    bool saved = ok;
    if (!saved) {
      final profileRes = await UserService.updateProfile({
        'centres_interet': updated,
      });
      saved = profileRes['success'] == true;
    }
    if (!mounted) return;
    if (saved) {
      await _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this interest.')),
      );
    }
    setState(() => _savingInterests = false);
  }

  Future<void> _promptAddInterest() async {
    if (_user == null || _savingInterests) return;

    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an Interest'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'e.g.: Hiking, Music, Art...',
          ),
          onSubmitted: (_) => Navigator.pop(context, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (!mounted || raw == null || raw.trim().isEmpty) return;
    final interest = raw.trim();

    final current = List<String>.from(_user!.centresInteret);
    final exists = current.any(
      (e) => e.toLowerCase().trim() == interest.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This interest already exists.')),
      );
      return;
    }

    final updated = [...current, interest];

    setState(() => _savingInterests = true);
    final ok = await UserService.updateInterests(_user!.id, updated);

    // Fallback to /users/me update in case interest endpoint fails on some envs.
    bool saved = ok;
    if (!saved) {
      final profileRes = await UserService.updateProfile({
        'centres_interet': updated,
      });
      saved = profileRes['success'] == true;
    }

    if (!mounted) return;

    if (saved) {
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest added successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add this interest.')),
      );
    }

    setState(() => _savingInterests = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Header cover + profile
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cover image
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF87CEEB).withOpacity(0.8),
                            const Color(0xFF4A90E2).withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    // Action buttons
                    Positioned(
                      top: 48,
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => widget.onNavigateToTab?.call(0),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 48,
                      right: 16,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                final user = _user;
                                if (user == null || user.id.isEmpty) return;
                                final userType = user.userType == 'Organisator'
                                    ? 'organizer'
                                    : 'tourist';
                                final link =
                                    'djtrip://profile/${user.id}?type=$userType';
                                Share.share(
                                  'Profil DJTrip de ${user.fullname}\n$link\n(ouvre ce lien dans DJTrip)',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profile avatar (bottom left)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _user?.avatar != null
                              ? Image.network(
                                  _user!.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Name and user type
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user?.fullname ?? 'User',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?.userType == 'Organisator'
                                ? 'Organizer'
                                : 'Travel Lover',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Following button or Edit
                      _user?.userType != 'Organisator'
                          ? FilledButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              ).then((_) => _loadAll()),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Bio
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✈️ ${_user?.bio?.isNotEmpty == true ? _user!.bio! : 'Travel lover exploring the world'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${(_user?.email?.split('@').firstOrNull ?? 'username').toLowerCase()} • ${_user?.paysOrigine ?? 'Country'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(value: '$_postsCount', label: 'Posts'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          value: _followers > 1000
                              ? '${(_followers / 1000).toStringAsFixed(1)}K'
                              : '$_followers',
                          label: 'Followers',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          value: '$_following',
                          label: 'Following',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tabs (Posts, Interests, etc)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedTab = 'Posts'),
                        child: Column(
                          children: [
                            Text(
                              'Posts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _selectedTab == 'Posts'
                                    ? AppColors.primary
                                    : Colors.grey,
                              ),
                            ),
                            if (_selectedTab == 'Posts')
                              Container(
                                height: 3,
                                width: 40,
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: () => setState(() => _selectedTab = 'Interests'),
                        child: Column(
                          children: [
                            Text(
                              'Interests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _selectedTab == 'Interests'
                                    ? AppColors.primary
                                    : Colors.grey,
                              ),
                            ),
                            if (_selectedTab == 'Interests')
                              Container(
                                height: 3,
                                width: 70,
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tab content
                if (_selectedTab == 'Posts') ...[const SizedBox.shrink()],
                if (_selectedTab == 'Interests')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Interests',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.start,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...(_user?.centresInteret ?? const <String>[])
                                    .map(
                                      (interest) => _InterestChip(
                                        label: interest,
                                        active: true,
                                        onDelete: _savingInterests
                                            ? null
                                            : () => _removeInterest(interest),
                                      ),
                                    ),
                                _InterestChip(
                                  label: _savingInterests
                                      ? 'Adding...'
                                      : '+ Add More',
                                  active: false,
                                  onTap: _savingInterests
                                      ? null
                                      : _promptAddInterest,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Posts list
                if (_selectedTab == 'Posts')
                  _recentActivities.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textGrey,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No posts yet',
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Padding(
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
                            itemCount: _recentActivities.length,
                            itemBuilder: (_, i) {
                              final insc = _recentActivities[i];
                              final act = insc.activite;
                              final photos = act?['photos'] as List? ?? [];
                              final imageUrl = photos.isNotEmpty
                                  ? photos.first as String
                                  : '';
                              final activityId = act?['_id'] as String? ?? '';
                              return GestureDetector(
                                onTap: activityId.isNotEmpty
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ActivityDetailScreen(
                                            activityId: activityId,
                                            viewOnly: true,
                                          ),
                                        ),
                                      )
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 32,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _InterestChip({
    required this.label,
    required this.active,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: 14,
          right: onDelete != null ? 6 : 14,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.primary,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String date;
  final String rating;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.imageUrl,
    required this.title,
    required this.date,
    required this.rating,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[200]),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                ),
                // Status badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.textGrey,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
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
