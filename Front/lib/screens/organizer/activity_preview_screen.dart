import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/activity_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
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
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
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
                      top: 380,
                      left: 20,
                      right: 20,
                      child: _HeroSummaryCard(
                        title: widget.title,
                        category: widget.category,
                        difficulty: widget.difficulty,
                        dateLabel: _fmtDate(widget.startDateTime),
                        durationLabel: widget.durationLabel,
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
                      const SizedBox(height: 120), // Spacing for Hero Card overlap
                      _SectionTitle('Description'),
                      Text(
                        _showFullDesc ? widget.description : (widget.description.length > 200 ? '${widget.description.substring(0, 200)}...' : widget.description),
                        style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4B5563)),
                      ),
                      if (widget.description.length > 200)
                        TextButton(
                          onPressed: () => setState(() => _showFullDesc = !_showFullDesc),
                          child: Text(_showFullDesc ? 'Show less' : 'Read more'),
                        ),
                      
                      _SectionTitle('Location'),
                      _LocationCard(placeLabel: widget.location),

                      _SectionTitle('Organizer (You)'),
                      _OrganizerCard(
                        organizer: _currentUser,
                        loading: _loadingUser,
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyBottomBar(
              price: '${widget.price.toStringAsFixed(0)} TND',
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final String title;
  final String category;
  final String difficulty;
  final String dateLabel;
  final String durationLabel;

  const _HeroSummaryCard({
    required this.title,
    required this.category,
    required this.difficulty,
    required this.dateLabel,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.flash_on, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                difficulty,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title.isEmpty ? 'Untitled Activity' : title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B2452),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(dateLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 16),
              const Icon(Icons.timer, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(durationLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D2652),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String placeLabel;
  const _LocationCard({required this.placeLabel});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.grey, size: 30),
            const SizedBox(height: 8),
            Text(
              'Meeting point: $placeLabel',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
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
  const _OrganizerCard({required this.organizer, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final name = (organizer?['fullname'] ?? 'Organizer').toString();
    final avatar = organizer?['avatar']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Your public profile', style: TextStyle(color: Colors.blue, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  final String price;
  final VoidCallback onBack;
  const _StickyBottomBar({required this.price, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -5))
        ],
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onBack,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 8,
            shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
          ),
          child: const Text(
            'Back to Edit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
