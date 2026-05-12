import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/lieu_model.dart';
import '../../services/lieu_service.dart';
import 'place_detail_new_screen.dart';
import '../../widgets/place_card.dart';

class ViewAllPlacesScreen extends StatefulWidget {
  const ViewAllPlacesScreen({super.key});

  @override
  State<ViewAllPlacesScreen> createState() => _ViewAllPlacesScreenState();
}

class _ViewAllPlacesScreenState extends State<ViewAllPlacesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<LieuModel> _places = [];
  List<LieuModel> _filteredPlaces = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSort = 'Popular';
  bool _isGridView = true;
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All', 'hotel', 'restaurant', 'museum', 'park', 'beach', 'shopping', 'entertainment', 'historical', 'landmark'
  ];

  final List<String> _sortOptions = [
    'Popular', 'Newest', 'Rating', 'Name A-Z', 'Name Z-A'
  ];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadPlaces();
    
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    
    try {
      final places = await LieuService.getLieux();
      setState(() {
        _places = places;
        _filteredPlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading places: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  void _filterPlaces() {
    setState(() {
      _filteredPlaces = _places.where((place) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            place.titre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            place.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            place.sousTitre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            place.categorie.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            place.categorie.toLowerCase() == _selectedCategory.toLowerCase();
        
        return matchesSearch && matchesCategory;
      }).toList();
      
      // Apply sorting
      _sortPlaces();
    });
  }

  void _sortPlaces() {
    setState(() {
      switch (_selectedSort) {
        case 'Popular':
          _filteredPlaces.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
          break;
        case 'Newest':
          _filteredPlaces.sort((a, b) => b.nombreAvis.compareTo(a.nombreAvis));
          break;
        case 'Rating':
          _filteredPlaces.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
          break;
        case 'Name A-Z':
          _filteredPlaces.sort((a, b) => a.titre.compareTo(b.titre));
          break;
        case 'Name Z-A':
          _filteredPlaces.sort((a, b) => b.titre.compareTo(a.titre));
          break;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterPlaces();
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _filterPlaces();
    }
  }

  void _onSortChanged(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      _filterPlaces();
    }
  }

  void _toggleViewMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E225E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: const Text(
            'All Places',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E225E),
            ),
          ),
        ),
        actions: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: const Color(0xFF4B63FF),
              ),
              onPressed: _toggleViewMode,
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
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
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search places, cities, locations...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6C757D)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFF6C757D)),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    children: [
                      // Category Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE1E4E8)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C757D)),
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: category == _selectedCategory
                                          ? const Color(0xFF4B63FF)
                                          : const Color(0xFF1E225E),
                                      fontWeight: category == _selectedCategory
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onCategoryChanged,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Sort Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE1E4E8)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C757D)),
                              items: _sortOptions.map((sort) {
                                return DropdownMenuItem<String>(
                                  value: sort,
                                  child: Text(
                                    sort,
                                    style: TextStyle(
                                      color: sort == _selectedSort
                                          ? const Color(0xFF4B63FF)
                                          : const Color(0xFF1E225E),
                                      fontWeight: sort == _selectedSort
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onSortChanged,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Results Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    children: [
                      Text(
                        '${_filteredPlaces.length} places found',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                      const Spacer(),
                      if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedCategory = 'All';
                            });
                            _filterPlaces();
                          },
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(
                              color: Color(0xFF4B63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Places List/Grid
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                        ),
                      )
                    : _filteredPlaces.isEmpty
                        ? _buildEmptyState()
                        : _isGridView
                            ? _buildGridView()
                            : _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: const Color(0xFF6C757D),
          ),
          const SizedBox(height: 16),
          Text(
            'No places found',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'All';
              });
              _filterPlaces();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        itemCount: _filteredPlaces.length,
        itemBuilder: (context, index) {
          return SizedBox(
          height: 280,
          child: _CustomPlaceCard(
            place: _filteredPlaces[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceDetailNewScreen(place: _filteredPlaces[index]),
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: _filteredPlaces.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _CustomPlaceCard(
            place: _filteredPlaces[index],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaceDetailNewScreen(place: _filteredPlaces[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CustomPlaceCard extends StatefulWidget {
  final LieuModel place;
  final VoidCallback onTap;

  const _CustomPlaceCard({required this.place, required this.onTap});

  @override
  State<_CustomPlaceCard> createState() => _CustomPlaceCardState();
}

class _CustomPlaceCardState extends State<_CustomPlaceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.place.displayImage.isNotEmpty
        ? widget.place.displayImage
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80';

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
          child: Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFFC529), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.place.noteMoyenne.toStringAsFixed(1)}',
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.place.titre,
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
                        widget.place.sousTitre.isNotEmpty ? widget.place.sousTitre : 'Djerba',
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
                          Expanded(
                            child: Text(
                              widget.place.prix == 'FREE' ? 'Free' : '${widget.place.prix}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF167BFF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
      ),
    );
  }
}
