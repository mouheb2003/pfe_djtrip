import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/place_model.dart';

class PlaceService {
  static const String _baseUrl = '/lieux';

  // Get all places
  static Future<List<PlaceModel>> getAllPlaces() async {
    try {
      final response = await ApiClient.get('$_baseUrl');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['lieux'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading places: $e');

      // Return mock data for development
      return _getMockPlaces();
    }
  }

  // Get place by ID
  static Future<PlaceModel?> getPlaceById(String placeId) async {
    try {
      final response = await ApiClient.get('$_baseUrl/$placeId');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return PlaceModel.fromJson(body['lieu'] ?? body['data']);
      } else {
        throw Exception('Failed to load place: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading place: $e');
      return null;
    }
  }

  // Search places using the backend search parameter
  static Future<List<PlaceModel>> searchPlaces(
    String query, {
    String? type,
  }) async {
    try {
      Map<String, String> queryParams = {'search': query};

      if (type != null && type != 'All') {
        queryParams['type'] = type;
      }

      final response = await ApiClient.get('$_baseUrl', query: queryParams);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['lieux'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception('Failed to search places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  // Get places by category
  static Future<List<PlaceModel>> getPlacesByCategory(String category) async {
    try {
      final response = await ApiClient.get('$_baseUrl/category/$category');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['places'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception(
          'Failed to load places by category: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading places by category: $e');
      return [];
    }
  }

  // Get popular places
  static Future<List<PlaceModel>> getPopularPlaces({int limit = 10}) async {
    try {
      final response = await ApiClient.get(
        '$_baseUrl/popular',
        query: {'limit': limit.toString()},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['places'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception(
          'Failed to load popular places: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading popular places: $e');
      return [];
    }
  }

  // Get nearby places
  static Future<List<PlaceModel>> getNearbyPlaces(
    double latitude,
    double longitude, {
    double radius = 10.0,
  }) async {
    try {
      final response = await ApiClient.get(
        '$_baseUrl/nearby',
        query: {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius': radius.toString(),
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['places'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception('Failed to load nearby places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading nearby places: $e');
      return [];
    }
  }

  // Get featured places
  static Future<List<PlaceModel>> getFeaturedPlaces({int limit = 5}) async {
    try {
      final response = await ApiClient.get(
        '$_baseUrl/featured',
        query: {'limit': limit.toString()},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> placesData = body['places'] ?? body['data'] ?? [];

        return placesData
            .map((placeData) => PlaceModel.fromJson(placeData))
            .toList();
      } else {
        throw Exception(
          'Failed to load featured places: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading featured places: $e');
      return _getMockFeaturedPlaces();
    }
  }

  // Toggle bookmark for a place
  static Future<bool> toggleBookmark(String lieuId) async {
    try {
      print('PlaceService: Calling POST $lieuId/bookmark');
      final response = await ApiClient.post('$_baseUrl/$lieuId/bookmark', {});
      print('PlaceService: Response status: ${response.statusCode}');
      print('PlaceService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Non authentifié - connecte toi d\'abord');
      } else if (response.statusCode == 404) {
        throw Exception('Place non trouvée');
      } else {
        throw Exception(
          'Erreur serveur ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      rethrow;
    }
  }

  // Rate place
  static Future<bool> ratePlace(
    String placeId,
    double rating, {
    String? review,
  }) async {
    try {
      final response = await ApiClient.post('$_baseUrl/$placeId/rate', {
        'rating': rating,
        if (review != null) 'review': review,
      });

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to rate place: ${response.statusCode}');
      }
    } catch (e) {
      print('Error rating place: $e');
      return false;
    }
  }

  // Get place reviews
  static Future<List<Map<String, dynamic>>> getPlaceReviews(
    String placeId,
  ) async {
    try {
      final response = await ApiClient.get('$_baseUrl/$placeId/reviews');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> reviewsData = body['reviews'] ?? body['data'] ?? [];

        return reviewsData.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load place reviews: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading place reviews: $e');
      return [];
    }
  }

  // Mock data for development
  static List<PlaceModel> _getMockPlaces() {
    return [
      PlaceModel(
        id: '1',
        name: 'Eiffel Tower',
        description:
            'Iconic iron lattice tower on the Champ de Mars in Paris, France.',
        location: 'Champ de Mars, 5 Avenue Anatole France',
        city: 'Paris',
        category: 'Landmarks',
        imageUrl: 'https://picsum.photos/seed/eiffel/400/300',
        rating: 4.8,
        reviewCount: 12543,
        latitude: 48.8584,
        longitude: 2.2945,
        tags: ['iconic', 'landmark', 'tourist', 'photography'],
        openingHours: '9:30 AM - 11:45 PM',
        entryFee: 25.90,
        images: [
          'https://picsum.photos/seed/eiffel1/400/300',
          'https://picsum.photos/seed/eiffel2/400/300',
          'https://picsum.photos/seed/eiffel3/400/300',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        updatedAt: DateTime.now(),
      ),
      PlaceModel(
        id: '2',
        name: 'Louvre Museum',
        description:
            'World\'s largest art museum and a historic monument in Paris.',
        location: 'Rue de Rivoli, 75001 Paris',
        city: 'Paris',
        category: 'Museums',
        imageUrl: 'https://picsum.photos/seed/louvre/400/300',
        rating: 4.7,
        reviewCount: 8932,
        latitude: 48.8606,
        longitude: 2.3376,
        tags: ['art', 'museum', 'history', 'culture'],
        openingHours: '9:00 AM - 6:00 PM',
        entryFee: 17.00,
        images: [
          'https://picsum.photos/seed/louvre1/400/300',
          'https://picsum.photos/seed/louvre2/400/300',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 300)),
        updatedAt: DateTime.now(),
      ),
      PlaceModel(
        id: '3',
        name: 'Central Park',
        description:
            'Large public park in New York City, perfect for recreation and relaxation.',
        location: 'New York, NY 10024',
        city: 'New York',
        category: 'Parks',
        imageUrl: 'https://picsum.photos/seed/centralpark/400/300',
        rating: 4.6,
        reviewCount: 15678,
        latitude: 40.7829,
        longitude: -73.9654,
        tags: ['park', 'nature', 'recreation', 'family'],
        openingHours: '6:00 AM - 1:00 AM',
        entryFee: 0.0, // Free
        images: [
          'https://picsum.photos/seed/park1/400/300',
          'https://picsum.photos/seed/park2/400/300',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
        updatedAt: DateTime.now(),
      ),
      PlaceModel(
        id: '4',
        name: 'Le Bernardin',
        description:
            'Award-winning French seafood restaurant in Midtown Manhattan.',
        location: '155 West 51st Street',
        city: 'New York',
        category: 'Restaurants',
        imageUrl: 'https://picsum.photos/seed/restaurant/400/300',
        rating: 4.9,
        reviewCount: 2341,
        latitude: 40.7628,
        longitude: -73.9810,
        tags: ['seafood', 'fine dining', 'french', 'award-winning'],
        openingHours: '11:30 AM - 10:00 PM',
        entryFee: null, // No entry fee for restaurants
        contactInfo: {
          'phone': '+1 212-555-1234',
          'email': 'info@lebernardin.com',
          'address': '155 West 51st Street, New York, NY 10019',
        },
        website: 'https://www.le-bernardin.com',
        images: [
          'https://picsum.photos/seed/rest1/400/300',
          'https://picsum.photos/seed/rest2/400/300',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
        updatedAt: DateTime.now(),
      ),
      PlaceModel(
        id: '5',
        name: 'Times Square',
        description:
            'Major commercial intersection and tourist destination in New York City.',
        location: 'Manhattan, NY 10036',
        city: 'New York',
        category: 'Entertainment',
        imageUrl: 'https://picsum.photos/seed/timessquare/400/300',
        rating: 4.4,
        reviewCount: 9876,
        latitude: 40.7580,
        longitude: -73.9855,
        tags: ['entertainment', 'shopping', 'tourist', 'nightlife'],
        openingHours: '24/7',
        entryFee: 0.0,
        images: [
          'https://picsum.photos/seed/times1/400/300',
          'https://picsum.photos/seed/times2/400/300',
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  static List<PlaceModel> _getMockFeaturedPlaces() {
    return _getMockPlaces().take(5).toList();
  }
}
