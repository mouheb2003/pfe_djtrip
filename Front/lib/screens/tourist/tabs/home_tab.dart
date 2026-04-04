import 'package:flutter/material.dart';
import '../../../models/lieu_model.dart';
import '../../../services/lieu_service.dart';
import '../place_detail_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onExploreTap;
  final VoidCallback onMessagesTap;

  const HomeTab({
    super.key,
    required this.onExploreTap,
    required this.onMessagesTap,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<LieuModel> _lieux = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String _selectedCategory = 'All';

  static const List<_CategoryItem> _categories = [
    _CategoryItem(
      keyName: 'All',
      label: 'Beaches',
      imageUrl:
          'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=300&q=80',
    ),
    _CategoryItem(
      keyName: 'Hotels',
      label: 'Hotels',
      imageUrl:
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=300&q=80',
    ),
    _CategoryItem(
      keyName: 'Restaurants',
      label: 'Restaurants',
      imageUrl:
          'https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=300&q=80',
    ),
    _CategoryItem(
      keyName: 'Activities',
      label: 'Activities',
      imageUrl:
          'https://images.unsplash.com/photo-1531058020387-3be344556be6?auto=format&fit=crop&w=300&q=80',
    ),
    _CategoryItem(
      keyName: 'Excursions',
      label: 'Excursions',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  static const String _heroImage =
      'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1500&q=80';

  @override
  void initState() {
    super.initState();
    _loadLieux();
  }

  Future<void> _loadLieux() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final lieux = await LieuService.getLieux();
      if (mounted) {
        setState(() {
          _lieux = lieux;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  List<LieuModel> get _filteredLieux {
    if (_selectedCategory == 'All') return _lieux;

    final wanted = _selectedCategory.toLowerCase().trim();

    return _lieux.where((lieu) {
      final category = lieu.categorie.toLowerCase().trim();
      final title = lieu.titre.toLowerCase().trim();
      final subtitle = lieu.sousTitre.toLowerCase().trim();
      return category.contains(wanted) ||
          title.contains(wanted) ||
          subtitle.contains(wanted);
    }).toList();
  }

  List<LieuModel> get _visibleLieux {
    final items = _filteredLieux;
    if (items.isNotEmpty) return items;
    return _lieux;
  }

  List<LieuModel> get _topDestinations {
    final items = [..._visibleLieux];
    items.sort((a, b) {
      if (a.topDestination == b.topDestination) return 0;
      return a.topDestination ? -1 : 1;
    });
    return items.take(6).toList();
  }

  Map<String, dynamic> _toPlaceMap(LieuModel l) {
    return {
      '_id': l.id,
      'title': l.titre,
      'subtitle': l.sousTitre,
      'description': l.description,
      'image': l.displayImage,
      'images': l.images,
      'rating': l.noteMoyenne.toStringAsFixed(1),
      'nombreAvis': l.nombreAvis,
      'top_destination': l.topDestination,
      'activity_id': l.activiteLieeId,
      'coordonnees': {'latitude': l.latitude, 'longitude': l.longitude},
      'price': l.prix,
      'categorie': l.categorie,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: RefreshIndicator(
        onRefresh: _loadLieux,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _HomeHero(
              backgroundImage: _heroImage,
              onExploreTap: widget.onExploreTap,
              onMessagesTap: widget.onMessagesTap,
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8ECF2),
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Color(0xFF7A8BA6),
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Search beaches, hotels, activities..',
                                    style: TextStyle(
                                      color: Color(0xFF7A8BA6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF167BFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF167BFF,
                                ).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 116,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final c = _categories[index];
                          return _CategoryAvatar(
                            label: c.label,
                            imageUrl: c.imageUrl,
                            selected: _selectedCategory == c.keyName,
                            onTap: () =>
                                setState(() => _selectedCategory = c.keyName),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Top Destinations',
                            style: TextStyle(
                              fontSize: 44 / 2,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF167BFF),
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text(
                            'See All',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _topDestinations.isEmpty
                        ? _EmptyDestinations(onRetry: _loadLieux)
                        : SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _topDestinations.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final lieu = _topDestinations[index];
                                return _TopDestinationCard(
                                  lieu: lieu,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaceDetailScreen(
                                        place: _toPlaceMap(lieu),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 20),
                    const _PlanTripCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 48,
        height: 48,
        child: Hero(
          tag: 'home_fab',
          child: Material(
            color: const Color(0xFFFF6B1A),
            elevation: 8,
            shape: const CircleBorder(),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final String backgroundImage;
  final VoidCallback onExploreTap;
  final VoidCallback onMessagesTap;

  const _HomeHero({
    required this.backgroundImage,
    required this.onExploreTap,
    required this.onMessagesTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            backgroundImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF167BFF)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA0B3E8E),
                  Color(0x66167BFF),
                  Color(0x22000000),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      _HeroIcon(
                        icon: Icons.chat_bubble_outline,
                        onTap: onMessagesTap,
                      ),
                      const SizedBox(width: 12),
                      const _HeroIcon(icon: Icons.notifications_none),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Discover the\nBeauty of',
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Djerba',
                    style: TextStyle(
                      fontSize: 38,
                      height: 0.9,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explore, Relax, Enjoy.',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFFF1F5F9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 206,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onExploreTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF167BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(34),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeroIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(icon, color: const Color(0xFF1E293B), size: 20),
      ),
    );
  }
}

class _CategoryAvatar extends StatelessWidget {
  final String label;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryAvatar({
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF167BFF) : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFDDE3ED),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image, color: Color(0xFF7A8BA6)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopDestinationCard extends StatelessWidget {
  final LieuModel lieu;
  final VoidCallback onTap;

  const _TopDestinationCard({required this.lieu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = lieu.displayImage.isNotEmpty
        ? lieu.displayImage
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFD0D9E8)),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x4D000000),
                      Color(0xAA000000),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      lieu.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFC529),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lieu.noteMoyenne.toStringAsFixed(1)} (${lieu.nombreAvis})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _PlanTripCard extends StatelessWidget {
  const _PlanTripCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 226,
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE9F3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFCFE0EE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan Your Perfect Trip',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Discover & Book in one place!',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 188,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 126,
            height: 126,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB9DDED),
            ),
            child: const Center(
              child: Icon(
                Icons.beach_access,
                color: Color(0xFF2A6388),
                size: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDestinations extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyDestinations({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, color: Color(0xFF7A8BA6), size: 34),
            const SizedBox(height: 10),
            const Text(
              'Not yet available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String keyName;
  final String label;
  final String imageUrl;

  const _CategoryItem({
    required this.keyName,
    required this.label,
    required this.imageUrl,
  });
}
