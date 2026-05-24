import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../shared/activity_card.dart';

class ViewAllActivitiesScreen extends StatefulWidget {
  const ViewAllActivitiesScreen({super.key});

  @override
  State<ViewAllActivitiesScreen> createState() => _ViewAllActivitiesScreenState();
}

class _ViewAllActivitiesScreenState extends State<ViewAllActivitiesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<ActivityModel> _activities = [];
  List<ActivityModel> _filteredActivities = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSort = 'Popular';
  bool _isGridView = true;
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All', 'Adventure', 'Cultural', 'Food & Wine', 'Historical', 
    'Nature', 'Photography', 'Shopping', 'Water Sports', 'Mountain'
  ];

  final List<String> _sortOptions = [
    'Popular', 'Newest', 'Price: Low to High', 'Price: High to Low', 'Rating'
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
    
    _loadActivities();
    
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

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    
    try {
      final activities = await ActivityService.getAllActivities();
      setState(() {
        _activities = activities;
        _filteredActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading activities: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  int _searchRank(ActivityModel activity, String query) {
    if (query.isEmpty) return 0;
    final title = activity.title.toLowerCase();
    if (title.contains(query)) return 0;

    final category = activity.category.toLowerCase();
    if (category.contains(query)) return 1;

    final description = activity.description.toLowerCase();
    if (description.contains(query)) return 2;

    final location = activity.location.toLowerCase();
    if (location.contains(query)) return 3;

    return 4;
  }

  int _compareBySelectedSort(ActivityModel a, ActivityModel b) {
    switch (_selectedSort) {
      case 'Popular':
      case 'Rating':
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      case 'Newest':
        return b.createdDate.compareTo(a.createdDate);
      case 'Price: Low to High':
        return (a.price ?? 0).compareTo(b.price ?? 0);
      case 'Price: High to Low':
        return (b.price ?? 0).compareTo(a.price ?? 0);
      default:
        return 0;
    }
  }

  void _filterActivities() {
    setState(() {
      _filteredActivities = _activities.where((activity) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            activity.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            activity.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            activity.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            activity.location.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            activity.category.toLowerCase() == _selectedCategory.toLowerCase();
        
        return matchesSearch && matchesCategory;
      }).toList();
      
      // Apply sorting
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        _filteredActivities.sort((a, b) {
          final rankCompare = _searchRank(a, query).compareTo(_searchRank(b, query));
          if (rankCompare != 0) return rankCompare;
          return _compareBySelectedSort(a, b);
        });
      } else {
        _sortActivities();
      }
    });
  }

  void _sortActivities() {
    setState(() {
      switch (_selectedSort) {
        case 'Popular':
          _filteredActivities.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
        case 'Newest':
          _filteredActivities.sort((a, b) => b.createdDate.compareTo(a.createdDate));
          break;
        case 'Price: Low to High':
          _filteredActivities.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
          break;
        case 'Price: High to Low':
          _filteredActivities.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
          break;
        case 'Rating':
          _filteredActivities.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterActivities();
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() {
        _selectedCategory = category;
      });
      _filterActivities();
    }
  }

  void _onSortChanged(String? sort) {
    if (sort != null) {
      setState(() {
        _selectedSort = sort;
      });
      _filterActivities();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF1E225E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'All Activities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E225E),
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
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : Colors.transparent),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search activities, locations...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : const Color(0xFF6C757D)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : const Color(0xFF6C757D)),
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
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE1E4E8)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.grey[400] : const Color(0xFF6C757D)),
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: category == _selectedCategory
                                          ? const Color(0xFF4B63FF)
                                          : (isDark ? Colors.grey[300] : const Color(0xFF1E225E)),
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
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE1E4E8)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              value: _selectedSort,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.grey[400] : const Color(0xFF6C757D)),
                              items: _sortOptions.map((sort) {
                                return DropdownMenuItem<String>(
                                  value: sort,
                                  child: Text(
                                    sort,
                                    style: TextStyle(
                                      color: sort == _selectedSort
                                          ? const Color(0xFF4B63FF)
                                          : (isDark ? Colors.grey[300] : const Color(0xFF1E225E)),
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
                        '${_filteredActivities.length} activities found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : const Color(0xFF6C757D),
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
                            _filterActivities();
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
              
              // Activities List/Grid
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                        ),
                      )
                    : _filteredActivities.isEmpty
                        ? _buildEmptyState(isDark)
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark ? Colors.grey[600] : const Color(0xFF6C757D),
          ),
          const SizedBox(height: 16),
          Text(
            'No activities found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[500] : const Color(0xFF6C757D),
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
              _filterActivities();
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
          childAspectRatio: 0.75,
        ),
        itemCount: _filteredActivities.length,
        itemBuilder: (context, index) {
          final activity = _filteredActivities[index];
          return ActivityCard(
            activity: activity,
            isCompact: true,
            isFavorite: activity.isBookmarked,
            onFavorite: () {
              final currentState = activity.isBookmarked;
              setState(() {
                final idx = _filteredActivities.indexOf(activity);
                if (idx != -1) {
                  _filteredActivities[idx] = activity.copyWith(isBookmarked: !currentState);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = _filteredActivities[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ActivityCard(
            activity: activity,
            isCompact: false,
            isFavorite: activity.isBookmarked,
            onFavorite: () {
              final currentState = activity.isBookmarked;
              setState(() {
                final idx = _filteredActivities.indexOf(activity);
                if (idx != -1) {
                  _filteredActivities[idx] = activity.copyWith(isBookmarked: !currentState);
                }
              });
            },
          ),
        );
      },
    );
  }
}
