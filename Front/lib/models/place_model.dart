import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceModel {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final LatLng? coordinates;
  final String? photoReference;
  final double? rating;
  final String? vicinity;
  final List<String>? types;
  final String? iconUrl;
  
  // Legacy properties for backward compatibility
  final String? id;
  final String? description;
  final String? location;
  final String? city;
  final String? category;
  final String? imageUrl;
  final int? reviewCount;
  final double? latitude;
  final double? longitude;
  final List<String>? tags;
  final String? openingHours;
  final double? entryFee;
  final List<String>? images;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? contactInfo;
  final String? website;
  
  const PlaceModel({
    this.placeId = '',
    required this.name,
    this.formattedAddress,
    this.coordinates,
    this.photoReference,
    this.rating,
    this.vicinity,
    this.types,
    this.iconUrl,
    this.id,
    this.description,
    this.location,
    this.city,
    this.category,
    this.imageUrl,
    this.reviewCount,
    this.latitude,
    this.longitude,
    this.tags,
    this.openingHours,
    this.entryFee,
    this.images,
    this.createdAt,
    this.updatedAt,
    this.contactInfo,
    this.website,
  });
  
  factory PlaceModel.fromGooglePlacesJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    
    return PlaceModel(
      placeId: json['place_id'] ?? json['placeId'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? json['vicinity'],
      coordinates: location != null 
          ? LatLng(location!['lat'] as double, location!['lng'] as double)
          : null,
      photoReference: json['photos']?.isNotEmpty == true 
          ? json['photos'][0]['photo_reference'] 
          : null,
      rating: json['rating']?.toDouble(),
      vicinity: json['vicinity'],
      types: json['types']?.cast<String>(),
      iconUrl: json['icon'],
    );
  }
  
  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      placeId: json['id']?.toString() ?? json['placeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      id: json['id']?.toString(),
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      city: json['city']?.toString(),
      category: json['category']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      reviewCount: json['reviewCount'] as int?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      tags: json['tags']?.cast<String>(),
      openingHours: json['openingHours']?.toString(),
      entryFee: json['entryFee'] as double?,
      images: json['images']?.cast<String>(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      contactInfo: json['contactInfo'] as Map<String, dynamic>?,
      website: json['website']?.toString(),
      formattedAddress: json['formattedAddress']?.toString(),
      coordinates: json['latitude'] != null && json['longitude'] != null
          ? LatLng(json['latitude'] as double, json['longitude'] as double)
          : null,
      photoReference: json['photoReference']?.toString(),
      rating: json['rating'] as double?,
      vicinity: json['vicinity']?.toString(),
      types: json['types']?.cast<String>(),
      iconUrl: json['iconUrl']?.toString(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'formattedAddress': formattedAddress,
      'coordinates': coordinates != null 
          ? {'latitude': coordinates!.latitude, 'longitude': coordinates!.longitude}
          : null,
      'photoReference': photoReference,
      'rating': rating,
      'vicinity': vicinity,
      'types': types,
      'iconUrl': iconUrl,
      'id': id,
      'description': description,
      'location': location,
      'city': city,
      'category': category,
      'imageUrl': imageUrl,
      'reviewCount': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
      'openingHours': openingHours,
      'entryFee': entryFee,
      'images': images,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'contactInfo': contactInfo,
      'website': website,
    };
  }
}
