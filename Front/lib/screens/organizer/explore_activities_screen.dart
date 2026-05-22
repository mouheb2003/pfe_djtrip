import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../shared/activity_detail_screen.dart';

class ExploreActivitiesScreen extends StatefulWidget {
  const ExploreActivitiesScreen({super.key});

  @override
  State<ExploreActivitiesScreen> createState() => _ExploreActivitiesScreenState();
}

class _ExploreActivitiesScreenState extends State<ExploreActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  List<ActivityModel> _activities = [];
  List<ActivityModel> _filteredActivities = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageSize = 10;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Filter chips
  final List<String> _filterOptions = ['All', 'Upcoming', 'Ongoing', 'Archive'];
  String _selectedFilter = 'All';
  
  // Advanced filters
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  String? _selectedLocation;
  double? _minRating;
  int? _minCapacity;
  int? _maxCapacity;
  double? _minDuration;
  double? _maxDuration;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadActivities();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities({bool refresh = false, bool loadMore = false}) async {
    if (!mounted) return;
    
    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        if (refresh) {
          _isRefreshing = true;
          _currentPage = 1;
        } else {
          _isLoading = true;
          _currentPage = 1;
        }
      });
    }

    try {
      final result = await ActivityService.getAllActivitiesPaginated(
        page: _currentPage,
        limit: _pageSize,
      );
      
      final activities = result['activities'] as List<ActivityModel>;
      final total = result['total'] as int;
      final pages = result['pages'] as int;
      
      print('🔍 [Explore] Loaded ${activities.length} activities (page $_currentPage/$pages, total: $total)');
      if (activities.isNotEmpty) {
        print('🔍 [Explore] First activity: ${activities.first.titre}, status: ${activities.first.timelineStatus}');
      }
      
      if (!mounted) return;
      
      setState(() {
        if (loadMore) {
          _activities.addAll(activities);
        } else {
          _activities = activities;
        }
        _hasMore = _currentPage < pages;
        _applyFilters();
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
      
      print('🔍 [Explore] Loaded page $_currentPage/$pages, activities on page: ${activities.length}');
      print('🔍 [Explore] Total loaded: ${_activities.length}, Total available: $total');
      print('🔍 [Explore] _hasMore: $_hasMore, _currentPage: $_currentPage');
    } catch (e) {
      print('❌ Error loading activities: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load activities: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  int _searchRank(ActivityModel activity, String query) {
    if (query.isEmpty) return 0;
    final title = activity.titre.toLowerCase();
    if (title.contains(query)) return 0;

    final category = activity.categorie.toLowerCase();
    if (category.contains(query)) return 1;

    final description = activity.description.toLowerCase();
    if (description.contains(query)) return 2;

    final location = activity.lieu.toLowerCase();
    if (location.contains(query)) return 3;

    return 4;
  }

  void _applyFilters() {
    List<ActivityModel> result = _activities;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((activity) {
        return activity.titre.toLowerCase().contains(query) ||
               activity.categorie.toLowerCase().contains(query) ||
               activity.description.toLowerCase().contains(query) ||
               activity.lieu.toLowerCase().contains(query);
      }).toList();

      result.sort((a, b) => _searchRank(a, query).compareTo(_searchRank(b, query)));
    }

    // Timeline filter
    if (_selectedFilter != 'All') {
      result = result.where((activity) {
        final status = activity.timelineStatus;
        switch (_selectedFilter) {
          case 'Upcoming':
            return status == 'UPCOMING';
          case 'Ongoing':
            return status == 'ONGOING';
          case 'Past':
            return status == 'PAST';
          default:
            return true;
        }
      }).toList();
    }

    // Category filter
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      result = result.where((activity) {
        return activity.categorie.toLowerCase() == _selectedCategory!.toLowerCase();
      }).toList();
    }

    // Price filter
    if (_minPrice != null) {
      result = result.where((activity) => activity.prix >= _minPrice!).toList();
    }
    if (_maxPrice != null) {
      result = result.where((activity) => activity.prix <= _maxPrice!).toList();
    }

    // Location filter
    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      result = result.where((activity) {
        return activity.lieu.toLowerCase().contains(_selectedLocation!.toLowerCase());
      }).toList();
    }

    // Difficulty filter - removed as niveauDifficulte doesn't exist in ActivityModel
    // if (_selectedDifficulty != null && _selectedDifficulty!.isNotEmpty) {
    //   result = result.where((activity) {
    //     return activity.niveauDifficulte.toLowerCase() == _selectedDifficulty!.toLowerCase();
    //   }).toList();
    // }

    // Rating filter
    if (_minRating != null) {
      result = result.where((activity) => activity.noteMoyenne >= _minRating!).toList();
    }

    // Capacity filter
    if (_minCapacity != null) {
      result = result.where((activity) => activity.capaciteMax >= _minCapacity!).toList();
    }
    if (_maxCapacity != null) {
      result = result.where((activity) => activity.capaciteMax <= _maxCapacity!).toList();
    }

    // Duration filter
    if (_minDuration != null) {
      result = result.where((activity) => activity.duree >= _minDuration!).toList();
    }
    if (_maxDuration != null) {
      result = result.where((activity) => activity.duree <= _maxDuration!).toList();
    }

    setState(() {
      _filteredActivities = result;
    });
    
    print('🔍 [Filter] Total loaded: ${_activities.length}, After filter: ${_filteredActivities.length}, Has more pages: $_hasMore');
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1; // Reset pagination when search changes
      _activities = []; // Clear loaded activities
    });
    _loadActivities(); // Reload from page 1
  }

  void _onFilterChanged(String filter) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFilter = filter;
      _currentPage = 1; // Reset pagination when filter changes
      _activities = []; // Clear loaded activities
    });
    _loadActivities(); // Reload from page 1
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
           _minPrice != null ||
           _maxPrice != null ||
           _selectedLocation != null ||
           _minRating != null ||
           _minCapacity != null ||
           _maxCapacity != null ||
           _minDuration != null ||
           _maxDuration != null;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2458),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCategory = null;
                          _minPrice = null;
                          _maxPrice = null;
                          _selectedLocation = null;
                          _minRating = null;
                          _minCapacity = null;
                          _maxCapacity = null;
                          _minDuration = null;
                          _maxDuration = null;
                        });
                        setState(() {
                          _selectedCategory = null;
                          _minPrice = null;
                          _maxPrice = null;
                          _selectedLocation = null;
                          _minRating = null;
                          _minCapacity = null;
                          _maxCapacity = null;
                          _minDuration = null;
                          _maxDuration = null;
                        });
                        _applyFilters();
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filters - Make scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Category Filter
                      _buildFilterSection(
                        'Category',
                        _buildCategoryDropdown(setModalState),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Price Range Filter
                      _buildFilterSection(
                        'Price Range',
                        _buildPriceRangeSlider(setModalState),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Location Filter
                      _buildFilterSection(
                        'Location',
                        _buildLocationInput(setModalState),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Rating Filter
                      _buildFilterSection(
                        'Minimum Rating',
                        _buildRatingSlider(setModalState),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Capacity Filter
                      _buildFilterSection(
                        'Capacity Range',
                        _buildCapacitySlider(setModalState),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Duration Filter
                      _buildFilterSection(
                        'Duration Range (hours)',
                        _buildDurationSlider(setModalState),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // Apply Button - Fixed at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2458),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildCategoryDropdown(StateSetter setModalState) {
    final categories = ['Cultural', 'Adventure', 'Nature', 'Food', 'Sports', 'Relaxation'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          hint: const Text(
            'Select category',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          isExpanded: true,
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setModalState(() {
              _selectedCategory = value;
            });
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPriceRangeSlider(StateSetter setModalState) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min Price',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setModalState(() {
                    _minPrice = double.tryParse(value);
                  });
                  setState(() {
                    _minPrice = double.tryParse(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max Price',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setModalState(() {
                    _maxPrice = double.tryParse(value);
                  });
                  setState(() {
                    _maxPrice = double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInput(StateSetter setModalState) {
    return TextField(
      decoration: const InputDecoration(
        hintText: 'Enter location',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        setModalState(() {
          _selectedLocation = value.isEmpty ? null : value;
        });
        setState(() {
          _selectedLocation = value.isEmpty ? null : value;
        });
      },
    );
  }

  Widget _buildRatingSlider(StateSetter setModalState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Min Rating:', style: TextStyle(fontSize: 13)),
            Text(
              _minRating != null ? '${_minRating!.toStringAsFixed(1)}★' : 'Any',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _minRating ?? 0,
          min: 0,
          max: 5,
          divisions: 10,
          label: _minRating?.toStringAsFixed(1),
          onChanged: (value) {
            setModalState(() {
              _minRating = value == 0 ? null : value;
            });
            setState(() {
              _minRating = value == 0 ? null : value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCapacitySlider(StateSetter setModalState) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min Capacity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setModalState(() {
                    _minCapacity = int.tryParse(value);
                  });
                  setState(() {
                    _minCapacity = int.tryParse(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max Capacity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setModalState(() {
                    _maxCapacity = int.tryParse(value);
                  });
                  setState(() {
                    _maxCapacity = int.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationSlider(StateSetter setModalState) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min Duration (hours)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setModalState(() {
                    _minDuration = double.tryParse(value);
                  });
                  setState(() {
                    _minDuration = double.tryParse(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max Duration (hours)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setModalState(() {
                    _maxDuration = double.tryParse(value);
                  });
                  setState(() {
                    _maxDuration = double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getOrganizerName(ActivityModel activity) {
    final organisateur = activity.organisateur;
    if (organisateur == null) return 'Unknown Organizer';
    
    final fullname = organisateur['fullname']?.toString() ?? '';
    final nomOrganisation = organisateur['nom_organisation']?.toString() ?? '';
    
    if (nomOrganisation.isNotEmpty) return nomOrganisation;
    if (fullname.isNotEmpty) return fullname;
    return 'Unknown Organizer';
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
      case 'ACTIVE':
        return const Color(0xFF10B981); // Green
      case 'ONGOING':
        return const Color(0xFFF59E0B); // Orange
      case 'CANCELLED':
        return const Color(0xFFEF4444); // Red
      case 'COMPLETED':
      case 'PAST':
        return const Color(0xFF6B7280); // Grey
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
      case 'ACTIVE':
        return 'UPCOMING';
      case 'ONGOING':
        return 'ONGOING';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'COMPLETED':
      case 'PAST':
        return 'COMPLETED';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(ActivityModel activity) {
    if (activity.dateDebut == null) return 'Date TBD';
    
    final date = activity.dateDebut!;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            
            // Search Bar
            _buildSearchBar(),
            
            // Filter Chips
            _buildFilterChips(),
            
            // Results Count
            _buildResultsCount(),
            
            // Activities List
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : RefreshIndicator(
                      onRefresh: () => _loadActivities(refresh: true),
                      color: AppColors.primary,
                      child: _filteredActivities.isEmpty
                          ? _buildEmptyState()
                          : _buildActivitiesList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4B63FF), Color(0xFF7B93FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Explore Activities',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discover experiences from all organizers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Filter Icon Button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.tune,
                      color: Color(0xFF1B2458),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _showFilterModal();
                    },
                  ),
                  // Show indicator when any advanced filter is active
                  if (_hasActiveFilters())
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by city, activity name...',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF6B7280),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return FadeTransition(
      opacity: _animationController,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: _filterOptions.length,
          itemBuilder: (context, index) {
            final filter = _filterOptions[index];
            final isSelected = _selectedFilter == filter;
            
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _onFilterChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          Text(
            '${_filteredActivities.length} ${_filteredActivities.length == 1 ? 'activity' : 'activities'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          if (_isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading activities...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.search_off_outlined,
                    size: 40,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No activities found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2458),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try adjusting your search terms'
                      : 'No activities available at the moment',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                if (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedFilter = 'All';
                      });
                      _applyFilters();
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _filteredActivities.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredActivities.length) {
          // Load More button - show if there are more pages available
          if (!_hasMore) return const SizedBox.shrink();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _isLoadingMore
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  )
                : Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentPage++;
                        });
                        _loadActivities(loadMore: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Load More'),
                    ),
                  ),
          );
        }

        final activity = _filteredActivities[index];
        return _ExploreActivityCard(
          activity: activity,
          organizerName: _getOrganizerName(activity),
          formattedDate: _formatDate(activity),
          statusColor: _getStatusColor(activity.timelineStatus),
          statusLabel: _getStatusLabel(activity.timelineStatus),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityDetailScreen(
                  activityId: activity.id,
                  viewOnly: true,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Airbnb-style Activity Card
class _ExploreActivityCard extends StatefulWidget {
  final ActivityModel activity;
  final String organizerName;
  final String formattedDate;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;

  const _ExploreActivityCard({
    required this.activity,
    required this.organizerName,
    required this.formattedDate,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  State<_ExploreActivityCard> createState() => _ExploreActivityCardState();
}

class _ExploreActivityCardState extends State<_ExploreActivityCard> {
  int _currentImageIndex = 0;
  int _bookmarksCount = 0;

  String _resolveImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '')}/$url';
  }

  @override
  void initState() {
    super.initState();
    _bookmarksCount = widget.activity.bookmarksCount ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BookmarkProvider>(context, listen: false)
            .updateActivityState(widget.activity.id, widget.activity.isBookmarked ?? false);
      }
    });
  }

  Future<void> _toggleBookmark() async {
    final activityId = widget.activity.id;
    if (activityId.isEmpty) return;

    try {
      final provider = Provider.of<BookmarkProvider>(context, listen: false);
      final currentBookmarked = provider.isActivityBookmarked(activityId);
      final currentCount = _bookmarksCount;

      setState(() {
        _bookmarksCount = !currentBookmarked ? currentCount + 1 : currentCount - 1;
      });

      await provider.toggleActivityBookmark(activityId);
    } catch (e) {
      debugPrint('❌ Error toggling bookmark in explore activities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.activity.photos;
    final hasMultiplePhotos = photos.length > 1;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Cover Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: Stack(
                  children: [
                    // Image or Placeholder
                    photos.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8E9EFF), Color(0xFFA5B4FC)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount: photos.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final resolvedUrl = _resolveImageUrl(photos[index]);
                              return CachedNetworkImage(
                                imageUrl: resolvedUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF8E9EFF), Color(0xFFA5B4FC)],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),
                    
                    // Status Badge (Top Left)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.statusColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    
                    // Photo Counter (Top Right - only if multiple photos)
                    if (hasMultiplePhotos)
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${photos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    // Bookmark Button (Top Right - always visible)
                    Positioned(
                      top: 12,
                      right: hasMultiplePhotos ? 60 : 12,
                      child: Consumer<BookmarkProvider>(
                        builder: (context, provider, child) {
                          final isProviderBookmarked = provider.isActivityBookmarked(widget.activity.id);
                          return GestureDetector(
                            onTap: _toggleBookmark,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isProviderBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                                color: isProviderBookmarked ? AppColors.primary : const Color(0xFF6B7280),
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Page Indicators (Bottom - only if multiple photos)
                    if (hasMultiplePhotos)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            photos.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _currentImageIndex == index ? 20 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _currentImageIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (Bold)
                  Text(
                    widget.activity.titre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2458),
                      letterSpacing: -0.3,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Organizer Name (Small subtitle)
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.organizerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Location & Date Row
                  Row(
                    children: [
                      // Location
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.activity.formattedLieu,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Date
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Price & Rating Row
                  Row(
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.activity.prixFormatted,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Rating
                      if (widget.activity.noteMoyenne > 0) ...[
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.activity.noteMoyenne.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2458),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${widget.activity.nombreAvis})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
