import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/lieu_service.dart';
import '../../../widgets/guide_arrow_button.dart';
import 'place_detail_screen.dart';

class AllPlacesSimpleScreen extends StatefulWidget {
  const AllPlacesSimpleScreen({super.key});

  @override
  State<AllPlacesSimpleScreen> createState() => _AllPlacesSimpleScreenState();
}

class _AllPlacesSimpleScreenState extends State<AllPlacesSimpleScreen> {
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Loading all places...');
      final places = await LieuService.getLieuxAsMap();
      print('Loaded ${places.length} places');
      
      if (mounted) {
        setState(() {
          _places = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading places: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToPlaceDetails(Map<String, dynamic> place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'All Places',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2458),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _places.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: const Color(0xFFB8BCC8),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No places found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check your connection and try again',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPlaces,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    return _PlaceCard(
                      place: place,
                      onTap: () => _navigateToPlaceDetails(place),
                    );
                  },
                ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.onTap,
  });

  String get _name => (place['name'] ?? place['title'] ?? place['titre'] ?? place['nom'] ?? 'Place').toString();
  String get _image => (place['main_image'] ?? place['image'] ?? place['imagePortrait'] ?? place['images']?.isNotEmpty == true ? place['images'][0] : '').toString();
  String get _city => (place['city'] ?? place['position']?['description'] ?? 'Djerba').toString();
  String get _rating => (place['rating'] ?? '0.0').toString();
  String get _description => (place['description'] ?? place['short_description'] ?? '').toString();
  bool get _isFeatured => place['is_featured'] == true || place['top_destination'] == true || place['topDestination'] == true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                color: const Color(0xFFF5F5F5),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: _image.isNotEmpty
                    ? Image.network(
                        _image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE8E8F6),
                          child: const Center(
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: Color(0xFFB8BCC8),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE8E8F6),
                        child: const Center(
                          child: Icon(
                            Icons.location_on,
                            size: 40,
                            color: Color(0xFFB8BCC8),
                          ),
                        ),
                      ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with name and featured badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isFeatured) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TOP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Description
                    if (_description.isNotEmpty)
                      Text(
                        _description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _city.isNotEmpty ? _city : 'Location',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Rating and arrow
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _rating,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        GuideArrowButton(onTap: onTap),
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
