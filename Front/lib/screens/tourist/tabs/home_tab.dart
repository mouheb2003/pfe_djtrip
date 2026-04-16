import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/lieu_model.dart';
import '../../../models/place_model.dart';
import '../../../models/activity_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/place_service.dart';
import '../../../services/activity_service.dart';
import '../place_detail_screen.dart';
import '../place_detail_new_screen.dart';
import '../view_all_activities_screen.dart';
import '../view_all_places_screen.dart';
import '../../shared/activity_card.dart';
import '../../../widgets/place_card.dart';
import '../../../theme/app_theme.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onExploreTap;
  final VoidCallback onMessagesTap;
  final VoidCallback? onActivitiesTap;
  final bool showMessagesDot;

  const HomeTab({
    super.key,
    required this.onExploreTap,
    required this.onMessagesTap,
    this.onActivitiesTap,
    this.showMessagesDot = false,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<LieuModel> _lieux = [];
  List<PlaceModel> _places = [];
  List<ActivityModel> _activities = [];
  List<PlaceModel> _filteredPlaces = [];
  List<ActivityModel> _filteredActivities = [];
  List<LieuModel> _visibleLieux = [];
  List<LieuModel> _topDestinations = [];
  List<ActivityModel> _topActivities = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const String _heroImage =
      'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1500&q=80';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final lieux = await LieuService.getLieux();
      print('[DEBUG] Fetched ${lieux.length} lieux');
      for (var lieu in lieux.take(3)) {
        print(
          '[DEBUG] Lieu: ${lieu.titre}, rating: ${lieu.noteMoyenne}, topDestination: ${lieu.topDestination}',
        );
      }

      // Fetch top activities from best organizers
      final activities = await ActivityService.getActivities();
      print('[DEBUG] Fetched ${activities.length} activities');

      // Filter upcoming activities and sort by organizer rating
      final now = DateTime.now();
      final upcomingActivities = activities.where((activity) {
        return activity.isUpcoming;
      }).toList();

      // Sort by rating (highest first) and take top 10
      upcomingActivities.sort((a, b) {
        final ratingA = a.noteMoyenne;
        final ratingB = b.noteMoyenne;
        return ratingB.compareTo(ratingA);
      });

      final topActivities = upcomingActivities.take(10).toList();
      print('[DEBUG] Top activities count: ${topActivities.length}');

      if (mounted) {
        setState(() {
          _lieux = lieux;
          _topActivities = topActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DEBUG] Error fetching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadLieux() async {
    await _fetchData();
  }

  List<LieuModel> get _filteredLieux {
    return _lieux;
  }

  List<LieuModel> get _filteredVisibleLieux {
    List<LieuModel> items = _lieux;

    // Apply search filter if search query is not empty
    if (_searchQuery.isNotEmpty) {
      items = items.where((lieu) {
        final title = lieu.titre.toLowerCase();
        final subtitle = lieu.sousTitre.toLowerCase();
        final description = lieu.description.toLowerCase();
        final category = lieu.categorie.toLowerCase();
        return title.contains(_searchQuery) ||
            subtitle.contains(_searchQuery) ||
            description.contains(_searchQuery) ||
            category.contains(_searchQuery);
      }).toList();
    }

    return items;
  }

  List<LieuModel> get _topDestinationsList {
    final items = List<LieuModel>.from(_filteredVisibleLieux);
    print(
      '[DEBUG] _filteredVisibleLieux count: ${_filteredVisibleLieux.length}',
    );
    // D'abord prioriser les top destinations, puis trier par rating
    items.sort((a, b) {
      if (a.topDestination && !b.topDestination) return -1;
      if (!a.topDestination && b.topDestination) return 1;
      // Si les deux ont le même statut topDestination, trier par rating
      return b.noteMoyenne.compareTo(a.noteMoyenne);
    });
    final result = items.take(6).toList();
    print('[DEBUG] _topDestinations count: ${result.length}');
    for (var lieu in result.take(3)) {
      print(
        '[DEBUG] Top destination: ${lieu.titre}, rating: ${lieu.noteMoyenne}, topDestination: ${lieu.topDestination}',
      );
    }
    return result;
  }

  List<LieuModel> get _topRatedPlaces {
    final items = [..._visibleLieux];
    items.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
    return items.take(5).toList();
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

  Widget _buildFilterButton(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
              showMessagesDot: widget.showMessagesDot,
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
                    const SizedBox(height: 18),
                    const SizedBox(height: 20),
                    // Barre de recherche fonctionnelle
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search destinations...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ViewAllPlacesScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF167BFF),
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text(
                            'View All',
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
                        : _topDestinationsList.isEmpty
                        ? _EmptyDestinations(onRetry: _loadLieux)
                        : SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _topDestinationsList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final lieu = _topDestinationsList[index];
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
                    const SizedBox(height: 32),
                    // Top Activities Section
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Top Activities',
                            style: TextStyle(
                              fontSize: 44 / 2,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // Navigate to activities tab
                            widget.onActivitiesTap?.call();
                          },
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF167BFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _topActivities.isEmpty
                        ? Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No upcoming activities',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _topActivities.length > 5
                                  ? 5
                                  : _topActivities.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final activity = _topActivities[index];
                                return Container(
                                  width: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(16),
                                              ),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                height: double.infinity,
                                                color: const Color(0xFFF3F4F6),
                                                child:
                                                    activity.imageUrl.isNotEmpty
                                                    ? Image.network(
                                                        activity.imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => const Center(
                                                              child: Icon(
                                                                Icons.event,
                                                                color: Color(
                                                                  0xFF9CA3AF,
                                                                ),
                                                              ),
                                                            ),
                                                      )
                                                    : const Center(
                                                        child: Icon(
                                                          Icons.event,
                                                          color: Color(
                                                            0xFF9CA3AF,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${activity.noteMoyenne.toStringAsFixed(1)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activity.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                activity.organisateur?['name'] ??
                                                    'Unknown',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                activity.prixFormatted,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF167BFF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
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
  final bool showMessagesDot;

  const _HomeHero({
    required this.backgroundImage,
    required this.onExploreTap,
    required this.onMessagesTap,
    required this.showMessagesDot,
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
                        showDot: showMessagesDot,
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
  final bool showDot;

  const _HeroIcon({required this.icon, this.onTap, this.showDot = false});

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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: const Color(0xFF1E293B), size: 20)),
            if (showDot) const Positioned(top: 9, right: 10, child: _RedDot()),
          ],
        ),
      ),
    );
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
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
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFD0D9E8),
                        child: const Center(
                          child: Icon(Icons.image, color: Color(0xFF7A8BA6)),
                        ),
                      ),
                    ),
                    // Rating overlay
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFC529),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${lieu.noteMoyenne.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lieu.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lieu.sousTitre.isNotEmpty ? lieu.sousTitre : 'Djerba',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lieu.prix == 'FREE' ? 'Free' : '${lieu.prix}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF167BFF),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF167BFF),
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
