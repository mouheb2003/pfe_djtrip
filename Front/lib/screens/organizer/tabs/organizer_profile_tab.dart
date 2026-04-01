import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../services/inscription_service.dart';
import '../../shared/edit_profile_screen.dart';
import '../../shared/public_organizer_profile_screen.dart';
import '../../shared/settings_screen.dart';

class OrganizerProfileTab extends StatefulWidget {
  const OrganizerProfileTab({super.key});

  @override
  State<OrganizerProfileTab> createState() => _OrganizerProfileTabState();
}

class _OrganizerProfileTabState extends State<OrganizerProfileTab> {
  UserModel? _user;
  int _activitiesCount = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0.0;
  List<String> _specialties = []; // 🚀 NEW: Stocker les spécialités d'activités

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      UserService.getProfile(),
      InscriptionService.getOrganizerStats(),
    ]);
    if (!mounted) return;
    
    final userData = results[0] as Map<String, dynamic>?;
    final user = userData != null ? UserModel.fromJson(userData) : null;
    
    setState(() {
      _user = user;
      final stats = results[1] as Map<String, dynamic>;
      _activitiesCount = (stats['activitiesCount'] as num?)?.toInt() ?? 0;
      _totalBookings = (stats['totalBookings'] as num?)?.toInt() ?? 0;
      _totalRevenue = (stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      
      // 🚀 NEW: Charger les spécialités d'activités
      if (userData != null && userData['specialites_activites'] != null) {
        _specialties = List<String>.from(userData['specialites_activites'] ?? []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
        child: Column(
          children: [
            // Cover + profile header
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover image
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDNfZZTtbb9R6ggSFQb7xX45Kx85or58pI910ucscdM_B6Zm323nkRO5_Ygvg8JlYPYAfGQ39PlXMlfaEgOhaslWehtU45pd6srTFntUeosgajKg7Y06dghPvQNSezADfPDRPYp-povZLZTjxmPtdcmryWfif_V3uTpbV-4RcrfibTiBaj-0RrGG-AqoUW_Fn9gNooQk0efkv0fXWO2c35y5oaJCL7Snsf6s86CTVhpN3xFe1jdhOex2miLPfyGEsDVd22evBYBDu4',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppColors.primary.withOpacity(0.3)),
                  ),
                ),
                // Overlay buttons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CoverButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.maybePop(context),
                        ),
                        Row(
                          children: [
                            _CoverButton(
                              icon: Icons.share,
                              onTap: () => Share.share(
                                  'Check out organizer ${_user?.fullname ?? 'DJTrip'} on DJTrip.',
                                ),
                            ),
                            const SizedBox(width: 8),
                            _CoverButton(
                              icon: Icons.more_vert,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Avatar
                Positioned(
                  bottom: -50,
                  left: 24,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage: _user?.avatar != null
                              ? NetworkImage(_user!.avatar!)
                              : null,
                          backgroundColor: Colors.grey[200],
                          child: _user?.avatar == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            // Profile info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?.fullname ?? 'Organizer',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.textGrey,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _user?.paysOrigine ?? 'Location not provided',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            value: _user?.noteMoyenne.toStringAsFixed(1) ?? '—',
                            label: 'Avg Rating',
                          ),
                        ),
                        const _Divider(),
                        Expanded(
                          child: _StatItem(
                            value: _user?.nombreAvis.toString() ?? '0',
                            label: 'Reviews',
                          ),
                        ),
                        const _Divider(),
                        Expanded(
                          child: _StatItem(
                            value: '$_activitiesCount',
                            label: 'Activities',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Edit Profile + Settings
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Icon(
                              Icons.settings,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // View Public Profile
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PublicOrganizerProfileScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.public, size: 16),
                      label: const Text('View Public Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 🚀 NEW: Dynamic Activity Specialties
                  const Text(
                    'Activity Specialties',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_specialties.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specialties.map((specialty) {
                        return _SpecialtyChip(specialty);
                      }).toList(),
                    )
                  else
                    const Text(
                      'No specialties added yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Monthly Performance
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Monthly Performance',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Jan 2025',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _PerfItem(
                                icon: Icons.euro,
                                value:
                                    '${_totalRevenue.toStringAsFixed(0)} TND',
                                label: 'Revenue',
                                sub: Icons.trending_up,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white30,
                            ),
                            Expanded(
                              child: _PerfItem(
                                icon: Icons.confirmation_number,
                                value: '$_totalBookings',
                                label: 'Bookings',
                                sub: Icons.trending_up,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.borderLight);
  }
}

class _CoverButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CoverButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _PerfItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final IconData sub;

  const _PerfItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Icon(sub, color: Colors.greenAccent, size: 16),
        ],
      ),
    );
  }
}
