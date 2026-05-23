import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/bookmark_provider.dart';
import '../../../models/lieu_model.dart';
import '../../../models/place_model.dart';
import '../../../models/activity_model.dart';
import '../../../services/lieu_service.dart';
import '../../../services/place_service.dart';
import '../../../services/activity_service.dart';
import '../place_detail_screen_v2.dart';
import '../../shared/activity_detail_screen.dart';
import '../../shared/ai_chat_screen.dart';
import '../view_all_activities_screen.dart';
import '../view_all_places_screen.dart';
import '../../shared/activity_card.dart';
import '../../../widgets/place_card.dart';
import '../../../widgets/auto_image_carousel.dart';
import '../../../theme/app_theme.dart';
import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../../../providers/user_provider.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onExploreTap;
  final VoidCallback onMessagesTap;
  final VoidCallback? onActivitiesTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback onProfileTap;
  final bool showMessagesDot;

  const HomeTab({
    super.key,
    required this.onExploreTap,
    required this.onMessagesTap,
    this.onActivitiesTap,
    this.onNotificationsTap,
    required this.onProfileTap,
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
  List<ActivityModel> _allActivities = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSuggestions = false;
  List<Map<String, dynamic>> _searchSuggestions = [];

  static const String _heroImage = 'assets/Pics/Djerba.png';

  final List<String> _djerbaImages = [
    'assets/Djerba/gettyimages-101567860-612x612.jpg',
    'assets/Djerba/gettyimages-1269508745-612x612.jpg',
    'assets/Djerba/gettyimages-1371715227-612x612.jpg',
    'assets/Djerba/gettyimages-1453337090-612x612.jpg',
    'assets/Djerba/gettyimages-152414916-612x612.jpg',
    'assets/Djerba/gettyimages-152414928-612x612.jpg',
    'assets/Djerba/gettyimages-157642812-612x612.jpg',
    'assets/Djerba/gettyimages-1742628854-612x612.jpg',
    'assets/Djerba/gettyimages-2150829217-612x612.jpg',
    'assets/Djerba/gettyimages-2263668070-612x612.jpg',
  ];

  static const String _djerbaHeroImage =
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1500&q=80';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      List<String> userInterests = [];
      if (user != null && user['centres_interet'] != null) {
        userInterests = (user['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
      } else if (AuthService.currentUser != null && AuthService.currentUser!['centres_interet'] != null) {
        userInterests = (AuthService.currentUser!['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
      }

      final lieux = await LieuService.getLieux();
      print('[DEBUG] Fetched ${lieux.length} lieux');
      for (var lieu in lieux.take(3)) {
        print(
          '[DEBUG] Lieu: ${lieu.titre}, rating: ${lieu.noteMoyenne}, topDestination: ${lieu.topDestination}',
        );
      }

      // Fetch all activities
      final activities = await ActivityService.getActivities();
      print('[DEBUG] Fetched ${activities.length} activities');

      // Filter upcoming activities and sort by organizer rating for display
      final now = DateTime.now();
      final upcomingActivities = activities.where((activity) {
        return activity.isUpcoming;
      }).toList();

      // Sort by interests first, then by rating (highest first) and take top 10 for display
      upcomingActivities.sort((a, b) {
        bool aMatches = userInterests.any((interest) => 
            a.categorie.toLowerCase().contains(interest) || a.titre.toLowerCase().contains(interest) || a.description.toLowerCase().contains(interest));
        bool bMatches = userInterests.any((interest) => 
            b.categorie.toLowerCase().contains(interest) || b.titre.toLowerCase().contains(interest) || b.description.toLowerCase().contains(interest));
        
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        
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
          _allActivities = activities; // Store all activities for search
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    List<String> userInterests = [];
    if (user != null && user['centres_interet'] != null) {
      userInterests = (user['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
    } else if (AuthService.currentUser != null && AuthService.currentUser!['centres_interet'] != null) {
      userInterests = (AuthService.currentUser!['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
    }

    final items = List<LieuModel>.from(_filteredVisibleLieux);
    print(
      '[DEBUG] _filteredVisibleLieux count: ${_filteredVisibleLieux.length}',
    );
    
    // Prioriser par centres d'intérêt, puis top destinations, puis note
    items.sort((a, b) {
      bool aMatches = userInterests.any((interest) => 
          (a.categorie ?? '').toLowerCase().contains(interest) || a.titre.toLowerCase().contains(interest) || a.description.toLowerCase().contains(interest));
      bool bMatches = userInterests.any((interest) => 
          (b.categorie ?? '').toLowerCase().contains(interest) || b.titre.toLowerCase().contains(interest) || b.description.toLowerCase().contains(interest));
      
      if (aMatches && !bMatches) return -1;
      if (!aMatches && bMatches) return 1;
      
      if (a.topDestination && !b.topDestination) return -1;
      if (!a.topDestination && b.topDestination) return 1;
      
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

  // Grouper les lieux par catégorie
  Map<String, List<LieuModel>> get _lieuxByCategory {
    final Map<String, List<LieuModel>> grouped = {};

    for (final lieu in _filteredVisibleLieux) {
      final category = lieu.categorie?.toLowerCase().trim() ?? 'autres';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(lieu);
    }

    // Trier chaque catégorie par rating (meilleur en premier)
    for (final category in grouped.keys) {
      grouped[category]!.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
    }

    return grouped;
  }

  // Obtenir les 10 meilleurs lieux notés en priorisant les centres d'intérêt
  List<LieuModel> get _topRatedPlaces {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    List<String> userInterests = [];
    if (user != null && user['centres_interet'] != null) {
      userInterests = (user['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
    } else if (AuthService.currentUser != null && AuthService.currentUser!['centres_interet'] != null) {
      userInterests = (AuthService.currentUser!['centres_interet'] as List).map((e) => e.toString().toLowerCase()).toList();
    }

    final items = [..._lieux];
    items.sort((a, b) {
      bool aMatches = userInterests.any((interest) => 
          (a.categorie ?? '').toLowerCase().contains(interest) || a.titre.toLowerCase().contains(interest) || a.description.toLowerCase().contains(interest));
      bool bMatches = userInterests.any((interest) => 
          (b.categorie ?? '').toLowerCase().contains(interest) || b.titre.toLowerCase().contains(interest) || b.description.toLowerCase().contains(interest));
      
      if (aMatches && !bMatches) return -1;
      if (!aMatches && bMatches) return 1;

      return b.noteMoyenne.compareTo(a.noteMoyenne);
    });
    return items.take(10).toList();
  }

  // Formater le nom de la catégorie
  String _formatCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'plages':
        return 'Beaches';
      case 'restaurants':
        return 'Restaurants';
      case 'hotels':
        return 'Hotels';
      case 'monuments':
        return 'Monuments';
      case 'activites':
        return 'Activities';
      case 'shopping':
        return 'Shopping';
      case 'parcs':
        return 'Parks';
      case 'musees':
        return 'Museums';
      case 'autres':
        return 'Others';
      default:
        return category
            .split(' ')
            .map(
              (word) => word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : '',
            )
            .join(' ');
    }
  }

  void _updateSearchSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final suggestions = <Map<String, dynamic>>[];
    final lowerQuery = query.toLowerCase();

    // Add lieux suggestions
    for (var lieu in _lieux) {
      if (lieu.titre.toLowerCase().contains(lowerQuery)) {
        suggestions.add({
          'type': 'lieu',
          'id': lieu.id,
          'title': lieu.titre,
          'subtitle': lieu.sousTitre,
          'image': lieu.displayImage,
          'rating': lieu.noteMoyenne,
        });
        if (suggestions.length >= 5) break;
      }
    }

    // Add activities suggestions if still need more (search through ALL activities)
    if (suggestions.length < 5) {
      for (var activity in _allActivities) {
        if (activity.titre.toLowerCase().contains(lowerQuery)) {
          suggestions.add({
            'type': 'activity',
            'id': activity.id,
            'title': activity.titre,
            'subtitle': activity.description,
            'image': activity.photos.isNotEmpty ? activity.photos.first : '',
            'rating': activity.noteMoyenne,
          });
          if (suggestions.length >= 5) break;
        }
      }
    }

    setState(() {
      _searchSuggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _searchController.text = suggestion['title'];
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = suggestion['title'].toLowerCase();
      _showSuggestions = false;
    });

    // Navigate to the appropriate screen based on type
    if (suggestion['type'] == 'lieu') {
      final lieu = _lieux.firstWhere((l) => l.id == suggestion['id']);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceDetailScreenV2(
            place: {
              'titre': lieu.titre,
              'name': lieu.titre,
              'description': lieu.description,
              'short_description': lieu.description,
              'imagePortrait': lieu.imagePortrait,
              'main_image': lieu.imagePortrait,
              'image': lieu.imagePortrait,
              'topDestination': lieu.topDestination,
              'noteMoyenne': lieu.noteMoyenne,
              'nombreAvis': lieu.nombreAvis,
              'city': lieu.city,
              'country': lieu.country,
              'opening_hours': lieu.openingHours ?? '',
              'closing_hours': lieu.closingHours ?? '',
              'prix': lieu.prix,
              'price': lieu.prix,
              'amenities': lieu.amenities,
              'reviews': lieu.reviews,
              'booking_required': lieu.bookingRequired,
            },
          ),
        ),
      );
    } else if (suggestion['type'] == 'activity') {
      // Navigate to activity detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ActivityDetailScreen(activityId: suggestion['id']),
        ),
      );
    }
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF6B7280),
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF3F3F3),
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
              onNotificationsTap: widget.onNotificationsTap,
              onProfileTap: widget.onProfileTap,
              showMessagesDot: widget.showMessagesDot,
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34.r)),
                ),
                padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 18.h),
                    SizedBox(height: 20.h),
                    // Barre de recherche fonctionnelle
                    SizedBox(
                      height: _showSuggestions ? 280 : 50,
                      child: Stack(
                        children: [
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(25.r),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                                _updateSearchSuggestions(value);
                              },
                              onTap: () {
                                if (_searchController.text.isNotEmpty) {
                                  _updateSearchSuggestions(
                                    _searchController.text,
                                  );
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search destinations, activities...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Color(0xFF6B7280),
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Color(0xFF6B7280),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _showSuggestions = false;
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                          if (_showSuggestions)
                            Positioned(
                              top: 60,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _searchSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final suggestion =
                                        _searchSuggestions[index];
                                    return ListTile(
                                      tileColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.r),
                                        child: Image.network(
                                          ApiConfig.getImageUrl(suggestion['image'] ?? ''),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              width: 48,
                                              height: 48,
                                              color: const Color(0xFFF1F5F9),
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey[300],
                                                  child: Icon(
                                                    Icons.place,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                      title: Text(
                                        suggestion['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      subtitle: Text(
                                        suggestion['subtitle'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Color(0xFF6B7280),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Colors.amber[600],
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            suggestion['rating']
                                                    ?.toStringAsFixed(1) ??
                                                '0.0',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          _selectSuggestion(suggestion),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Djerba Hero Section with Carousel
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          AutoImageCarousel(
                            imageUrls: _djerbaImages,
                            borderRadius: BorderRadius.circular(16.r),
                            interval: const Duration(seconds: 4),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.r),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(20.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Djerba',
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  'The Pearl of the Mediterranean',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Top Rated Places Section
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top Rated Places',
                            style: TextStyle(
                              fontSize: 44.sp / 2,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
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
                          icon: Icon(Icons.arrow_forward, size: 18),
                          label: Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _isLoading
                        ? SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _topRatedPlaces.isEmpty
                        ? _EmptyDestinations(onRetry: _loadLieux)
                        : SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _topRatedPlaces.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(width: 16.w),
                              itemBuilder: (context, index) {
                                final lieu = _topRatedPlaces[index];
                                return _TopDestinationCard(
                                  lieu: lieu,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaceDetailScreenV2(
                                        place: _toPlaceMap(lieu),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    SizedBox(height: 32.h),

                    // Top Activities Section
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top Activities',
                            style: TextStyle(
                              fontSize: 44.sp / 2,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // Navigate to activities tab
                            widget.onActivitiesTap?.call();
                          },
                          iconAlignment: IconAlignment.end,
                          icon: Icon(Icons.arrow_forward, size: 18),
                          label: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF167BFF),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _topActivities.isEmpty
                        ? Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'No upcoming activities',
                                    style: TextStyle(
                                      fontSize: 16.sp,
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
                                  SizedBox(width: 12.w),
                              itemBuilder: (context, index) {
                                final activity = _topActivities[index];
                                return _HomeActivityCard(
                                  activity: activity,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityDetailScreen(
                                        activityId: activity.id,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                    SizedBox(height: 32.h),

                    // Destinations by Category Sections
                    ...(_lieuxByCategory.entries.map((entry) {
                      final category = entry.key;
                      final places = entry.value
                          .take(5)
                          .toList(); // Top 5 par catégorie

                      if (places.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 32.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatCategoryName(category),
                                  style: TextStyle(
                                    fontSize: 44.sp / 2,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
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
                                icon: Icon(Icons.arrow_forward, size: 18),
                                label: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: places.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(width: 16.w),
                              itemBuilder: (context, index) {
                                final lieu = places[index];
                                return _TopDestinationCard(
                                  lieu: lieu,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaceDetailScreenV2(
                                        place: _toPlaceMap(lieu),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList()),

                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 100.0),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Hero(
            tag: 'ai_chat_fab',
            child: Material(
              color: const Color(0xFF167BFF),
              elevation: 8,
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(28.r),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AiChatScreen()),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Icon(Icons.smart_toy, color: Colors.white, size: 24),
                ),
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
  final VoidCallback? onNotificationsTap;
  final VoidCallback onProfileTap;
  final bool showMessagesDot;

  const _HomeHero({
    required this.backgroundImage,
    required this.onExploreTap,
    required this.onMessagesTap,
    this.onNotificationsTap,
    required this.onProfileTap,
    required this.showMessagesDot,
  });

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty || avatar == 'null') return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    if (avatar.startsWith('/')) {
      return '$baseUrl$avatar';
    }
    return '$baseUrl/$avatar';
  }

  Widget _buildProfileButton() {
    final user = AuthService.currentUser;
    final avatar = user?['avatar']?.toString();
    final resolvedAvatar = _resolveAvatarUrl(avatar);
    
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withOpacity(0.2),
          backgroundImage: resolvedAvatar.isNotEmpty
              ? NetworkImage(resolvedAvatar)
              : null,
          child: resolvedAvatar.isEmpty
              ? Icon(Icons.person, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backgroundImage.startsWith('http')
              ? Image.network(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF167BFF)),
                )
              : Image.asset(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF167BFF)),
                ),
          Container(
            decoration: BoxDecoration(
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
              padding: EdgeInsets.fromLTRB(20, 10, 20, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      _buildProfileButton(),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Discover the\nBeauty of',
                    style: TextStyle(
                      fontSize: 24.sp,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Djerba',
                    style: TextStyle(
                      fontSize: 38.sp,
                      height: 0.9,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B1A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Explore, Relax, Enjoy.',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Color(0xFFF1F5F9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 26.h),
                  SizedBox(
                    width: 206,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onExploreTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF167BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(34.r),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore Now',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
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
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: const Color(0xFF1E293B), size: 20)),
            if (showDot) Positioned(top: 9, right: 10, child: _RedDot()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              padding: EdgeInsets.all(2.w),
              child: ClipOval(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFDDE3ED),
                    alignment: Alignment.center,
                    child: Icon(Icons.image, color: Color(0xFF7A8BA6)),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = lieu.displayImage.isNotEmpty
        ? lieu.displayImage
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            if (!isDark)
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20.r),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      ApiConfig.getImageUrl(imageUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFF8FAFC),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: Center(
                          child: Icon(Icons.image, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    // Rating overlay
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Color(0xFFFFC529),
                              size: 12,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${lieu.noteMoyenne.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
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
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lieu.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      lieu.sousTitre.isNotEmpty ? lieu.sousTitre : 'Djerba',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lieu.prix == 'FREE' ? 'Free' : '${lieu.prix}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF167BFF),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 226,
      padding: EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2530) : const Color(0xFFDDE9F3),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: isDark ? const Color(0xFF2E3B4E) : const Color(0xFFCFE0EE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Your Perfect Trip',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Discover & Book in one place!',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569),
                    fontSize: 14.sp,
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
                        borderRadius: BorderRadius.circular(34.r),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF2D4B5E) : const Color(0xFFB9DDED),
            ),
            child: Center(
              child: Icon(
                Icons.beach_access,
                color: isDark ? const Color(0xFF68A5CE) : const Color(0xFF2A6388),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, color: Color(0xFF7A8BA6), size: 34),
            SizedBox(height: 10.h),
            Text(
              'Not yet available',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            TextButton(onPressed: onRetry, child: Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _HomeActivityCard extends StatefulWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const _HomeActivityCard({required this.activity, required this.onTap});

  @override
  State<_HomeActivityCard> createState() => _HomeActivityCardState();
}

class _HomeActivityCardState extends State<_HomeActivityCard> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BookmarkProvider>(context, listen: false)
            .updateActivityState(widget.activity.id, widget.activity.isBookmarked);
      }
    });
  }

  Future<void> _toggleBookmark() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<BookmarkProvider>(context, listen: false);
      await provider.toggleActivityBookmark(widget.activity.id);
    } catch (e) {
      debugPrint('❌ Error toggling bookmark in home activity card: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activity = widget.activity;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFFF3F4F6),
                      child: activity.imageUrl.isNotEmpty
                          ? Image.network(
                              ApiConfig.getImageUrl(activity.imageUrl),
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFFF8FAFC),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.event, color: Color(0xFF94A3B8)),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.event, color: Color(0xFF94A3B8)),
                            ),
                    ),
                    // Rating badge (top-left)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Color(0xFFFFC529), size: 10),
                            SizedBox(width: 2.w),
                            Text(
                              activity.noteMoyenne.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bookmark button (top-right)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Consumer<BookmarkProvider>(
                        builder: (context, provider, child) {
                          final isProviderBookmarked = provider.isActivityBookmarked(activity.id);
                          return GestureDetector(
                            onTap: _toggleBookmark,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isProviderBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border_rounded,
                                size: 16,
                                color: isProviderBookmarked
                                    ? const Color(0xFF167BFF)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      activity.organisateur?['fullname'] ??
                          activity.organisateur?['nom_organisation'] ??
                          activity.organisateur?['name'] ??
                          'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      activity.prixFormatted,
                      style: TextStyle(
                        fontSize: 11.sp,
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
