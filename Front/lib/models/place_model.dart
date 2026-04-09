import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlaceModel {
  final String id;
  final String name;
  final String description;
  final String location;
  final String city;
  final String category;
  final String? imageUrl;
  final double? rating;
  final int? reviewCount;
  final double? latitude;
  final double? longitude;
  final List<String>? tags;
  final Map<String, dynamic>? contactInfo;
  final String? website;
  final String? openingHours;
  final double? entryFee;
  final List<String>? images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.city,
    required this.category,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.latitude,
    this.longitude,
    this.tags,
    this.contactInfo,
    this.website,
    this.openingHours,
    this.entryFee,
    this.images,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.metadata,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      rating: json['rating']?.toDouble(),
      reviewCount: json['reviewCount']?.toInt() ?? json['review_count']?.toInt(),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'])
          : null,
      contactInfo: json['contactInfo'] ?? json['contact_info'],
      website: json['website']?.toString(),
      openingHours: json['openingHours']?.toString() ?? json['opening_hours']?.toString(),
      entryFee: json['entryFee']?.toDouble() ?? json['entry_fee']?.toDouble(),
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'location': location,
      'city': city,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
      'contactInfo': contactInfo,
      'website': website,
      'openingHours': openingHours,
      'entryFee': entryFee,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  // Helper getters
  String get displayName => name.isNotEmpty ? name : location;
  String get fullLocation => '$location, $city';
  String get ratingText => rating?.toStringAsFixed(1) ?? '0.0';
  String get reviewCountText => reviewCount != null ? '($reviewCount reviews)' : '(0 reviews)';
  bool get hasRating => rating != null && rating! > 0;
  bool get hasImages => images != null && images!.isNotEmpty;
  String get primaryImage => imageUrl ?? (hasImages ? images!.first : '');
  bool get hasWebsite => website != null && website!.isNotEmpty;
  bool get hasContactInfo => contactInfo != null && contactInfo!.isNotEmpty;
  bool get hasOpeningHours => openingHours != null && openingHours!.isNotEmpty;
  bool get hasEntryFee => entryFee != null && entryFee! > 0;
  String get entryFeeText => hasEntryFee ? '\$${entryFee!.toStringAsFixed(2)}' : 'Free';
  bool get isPopular => rating != null && rating! >= 4.0 && reviewCount != null && reviewCount! >= 50;

  // Category helpers
  bool get isMuseum => category.toLowerCase().contains('museum');
  bool get isPark => category.toLowerCase().contains('park');
  bool get isRestaurant => category.toLowerCase().contains('restaurant');
  bool get isHistorical => category.toLowerCase().contains('historical');
  bool get isShopping => category.toLowerCase().contains('shopping');
  bool get isBeach => category.toLowerCase().contains('beach');
  bool get isMountain => category.toLowerCase().contains('mountain');
  bool get isLandmark => category.toLowerCase().contains('landmark');
  bool get isEntertainment => category.toLowerCase().contains('entertainment');

  // Status helpers
  bool get isOpen => _isOpenNow();
  String get statusText => isOpen ? 'Open Now' : 'Closed';
  Color get statusColor => isOpen ? Color(0xFF00B894) : Color(0xFFFF4757);

  bool _isOpenNow() {
    if (openingHours == null || openingHours!.isEmpty) return true; // Assume open if no hours specified
    
    // Simple implementation - you can make this more sophisticated
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Parse opening hours (simplified)
    if (openingHours!.toLowerCase().contains('24/7')) return true;
    
    // Add more sophisticated parsing as needed
    return currentHour >= 9 && currentHour <= 18; // Default 9-6
  }

  // Distance calculation (if coordinates are available)
  double? distanceTo(double userLat, double userLng) {
    if (latitude == null || longitude == null) return null;
    
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(userLat - latitude!);
    final double dLng = _toRadians(userLng - longitude!);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude!)) * math.cos(_toRadians(userLat)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a).toDouble());
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  String get distanceText {
    // This would be calculated based on user's current location
    // For now, return a placeholder
    return '2.5 km away';
  }

  // Contact info helpers
  String? get phoneNumber => contactInfo?['phone']?.toString();
  String? get emailAddress => contactInfo?['email']?.toString();
  String? get address => contactInfo?['address']?.toString();

  // Create a copy with updated fields
  PlaceModel copyWith({
    String? name,
    String? description,
    String? location,
    String? city,
    String? category,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    double? latitude,
    double? longitude,
    List<String>? tags,
    Map<String, dynamic>? contactInfo,
    String? website,
    String? openingHours,
    double? entryFee,
    List<String>? images,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return PlaceModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
      contactInfo: contactInfo ?? this.contactInfo,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      entryFee: entryFee ?? this.entryFee,
      images: images ?? this.images,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }
}
