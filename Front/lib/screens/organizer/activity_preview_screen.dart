import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/activity_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../shared/public_profile_screen.dart';

class ActivityPreviewScreen extends StatefulWidget {
  final String title;
  final String category;
  final String description;
  final double price;
  final int capacity;
  final String location;
  final double duration;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final List<String> existingPhotos;
  final List<XFile> photos;
  final List<String> requirements;
  final List<String> optional;
  final LatLng? pickedLatLng;
  final String difficulty;
  final List<String> languages;
  final String durationLabel;

  const ActivityPreviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.capacity,
    required this.location,
    required this.duration,
    this.startDateTime,
    this.endDateTime,
    this.existingPhotos = const [],
    this.photos = const [],
    this.requirements = const [],
    this.optional = const [],
    this.pickedLatLng,
    this.difficulty = 'Medium',
    this.languages = const ['Français'],
    required this.durationLabel,
  });

  @override
  State<ActivityPreviewScreen> createState() => _ActivityPreviewScreenState();
}

class _ActivityPreviewScreenState extends State<ActivityPreviewScreen> {
  bool _showFullDesc = false;
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentImage = 0;
  Map<String, dynamic>? _currentUser;
  bool _loadingUser = true;

  List<dynamic> get _allPhotos => [...widget.existingPhotos, ...widget.photos];

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _resetCarouselTimer();
    _loadCurrentUser();
  }

  void _resetCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      if (_allPhotos.length <= 1) return;
      if (_pageController.hasClients) {
        int nextPage = _currentImage + 1;
        if (nextPage >= _allPhotos.length) nextPage = 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await UserService.getProfile();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _loadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F2FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Carousel
                    SizedBox(
                      height: 400,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemCount: _allPhotos.isEmpty ? 1 : _allPhotos.length,
                        itemBuilder: (ctx, i) {
                          if (_allPhotos.isEmpty) {
                            return Container(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey[300],
                              child: Icon(Icons.image, size: 50, color: isDark ? Colors.grey[600] : Colors.grey),
                            );
                          }
                          final item = _allPhotos[i];
                          if (item is String) {
                            return Image.network(item, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error));
                          } else if (item is XFile) {
                            return Image.file(File(item.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error));
                          }
                          return const Icon(Icons.image_not_supported);
                        },
                      ),
                    ),

                    // Preview Mode Banner
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'MODE PREVIEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Navigation
                    Positioned(
                      top: 40,
                      left: 16,
                      child: _TopIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),

                    // Hero Card
                    Positioned(
                      top: 340,
                      left: 20,
                      right: 20,
                      child: _HeroSummaryCard(
                        title: widget.title,
                        category: widget.category,
                        dateLabel: _fmtDate(widget.startDateTime),
                        durationLabel: widget.durationLabel,
                        capacity: widget.capacity,
                        languages: widget.languages,
                        price: widget.price,
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 420), // Spacing for Hero Card overlap - ensures description starts after box ends
                      _SectionTitle('Description'),
                      Text(
                        _showFullDesc ? widget.description : (widget.description.length > 200 ? '${widget.description.substring(0, 200)}...' : widget.description),
                        style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.grey[300] : const Color(0xFF4B5563)),
                      ),
                      if (widget.description.length > 200)
                        TextButton(
                          onPressed: () => setState(() => _showFullDesc = !_showFullDesc),
                          child: Text(_showFullDesc ? 'Show less' : 'Read more'),
                        ),
                      
                      _SectionTitle('Included Equipment'),
                      _TagListSection(
                        items: widget.requirements,
                        emptyLabel: 'No equipment specified',
                        icon: Icons.check_circle,
                        chipColor: const Color(0xFFE9E8F7),
                        iconColor: const Color(0xFF3049D9),
                      ),
                      
                      _SectionTitle('What to Bring'),
                      _TagListSection(
                        items: widget.optional,
                        emptyLabel: 'Nothing special is required',
                        icon: Icons.shopping_basket_outlined,
                        chipColor: const Color(0xFFE9E8F7),
                        iconColor: const Color(0xFF3049D9),
                      ),

                      _SectionTitle('Location'),
                      _LocationCard(
                        placeLabel: widget.location,
                        latLng: widget.pickedLatLng,
                      ),

                      _SectionTitle('Organizer (You)'),
                      _OrganizerCard(
                        organizer: _currentUser,
                        loading: _loadingUser,
                        onViewProfile: () {
                          if (_currentUser != null) {
                            final userId = (_currentUser!['_id'] ?? _currentUser!['id'] ?? '').toString();
                            if (userId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(userId: userId),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Bar - Back to Edit only
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyBottomBar(
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 20),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final String title;
  final String category;
  final String dateLabel;
  final String durationLabel;
  final int capacity;
  final List<String> languages;
  final double price;

  const _HeroSummaryCard({
    required this.title,
    required this.category,
    required this.dateLabel,
    required this.durationLabel,
    required this.capacity,
    required this.languages,
    required this.price,
  });

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF312E81) : const Color(0xFFE9E8F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3049D9)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final participants = capacity > 0 ? '$capacity max' : '-';
    final languagesText = languages.isEmpty ? '-' : languages.join(', ');
    final priceText = '${price.toStringAsFixed(0)} TND';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F2FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81).withOpacity(0.5) : const Color(0xFF3049D9).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3049D9),
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFDCE8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3049D9),
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title.isEmpty ? 'Untitled Activity' : title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.02,
              color: isDark ? Colors.white : const Color(0xFF17183D),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 24) / 3; // 3 items per row
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _infoTile(
                    icon: Icons.event,
                    label: 'Date debut',
                    value: dateLabel,
                    isDark: isDark,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.timer,
                    label: 'Duree',
                    value: durationLabel,
                    isDark: isDark,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.attach_money,
                    label: 'Prix',
                    value: priceText,
                    isDark: isDark,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.group,
                    label: 'Capacite',
                    value: participants,
                    isDark: isDark,
                    width: itemWidth,
                  ),
                  _infoTile(
                    icon: Icons.language,
                    label: 'Langues',
                    value: languagesText,
                    isDark: isDark,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1D2652),
        ),
      ),
    );
  }
}

class _TagListSection extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  final IconData icon;
  final Color chipColor;
  final Color iconColor;

  const _TagListSection({
    required this.items,
    required this.emptyLabel,
    required this.icon,
    required this.chipColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          emptyLabel,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF312E81) : chipColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? const Color(0xFFA5B4FC) : iconColor),
              const SizedBox(width: 8),
              Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFA5B4FC) : iconColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String placeLabel;
  final LatLng? latLng;
  const _LocationCard({required this.placeLabel, this.latLng});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // If we have coordinates, show actual map
    if (latLng != null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: latLng!,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('location'),
                    position: latLng!,
                    infoWindow: InfoWindow(
                      title: placeLabel,
                      snippet: 'Meeting point',
                    ),
                  ),
                },
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
              ),
              // Overlay with location label at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          placeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

    // Fallback: show placeholder when no coordinates
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: isDark ? Colors.grey[500] : Colors.grey, size: 30),
            const SizedBox(height: 8),
            Text(
              'Meeting point: $placeLabel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final Map<String, dynamic>? organizer;
  final bool loading;
  final VoidCallback? onViewProfile;
  const _OrganizerCard({required this.organizer, required this.loading, this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final name = (organizer?['fullname'] ?? 'Organizer').toString();
    final avatar = organizer?['avatar']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                InkWell(
                  onTap: onViewProfile,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir mon profil public',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFA5B4FC) : Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: isDark ? const Color(0xFFA5B4FC) : Colors.blue[400],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final VoidCallback onBack;
  const _StickyBottomBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black45 : Colors.black12, blurRadius: 25, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
            ),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text(
              'Back to Edit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
