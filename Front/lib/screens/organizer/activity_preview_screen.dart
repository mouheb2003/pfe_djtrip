import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ActivityPreviewScreen extends StatelessWidget {
  final String title;
  final String category;
  final String description;
  final double price;
  final int capacity;
  final String location;
  final double duration;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final List<String> existingPhotos;
  final List<XFile> photos;
  final List<String> requirements;
  final List<String> optional;
  final LatLng? pickedLatLng;
  final String difficulty;
  final List<String> languages;

  const ActivityPreviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.capacity,
    required this.location,
    required this.duration,
    this.startDateTime,
    this.endDateTime,
    this.existingPhotos = const [],
    this.photos = const [],
    this.requirements = const [],
    this.optional = const [],
    this.pickedLatLng,
    this.difficulty = 'Medium',
    this.languages = const ['Français'],
    String durationLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> allPhotos = [...existingPhotos, ...photos];
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Preview Mode', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Image Preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
              child: allPhotos.isEmpty 
                  ? const Icon(Icons.image, size: 50, color: Colors.grey)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _buildFirstImage(allPhotos[0]),
                    ),
            ),
            const SizedBox(height: 24),
            
            // Title & Price
            Text(title.isEmpty ? 'No Title' : title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$price TND', style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            
            // Information Grid
            _buildInfoRow(Icons.category, 'Category', category),
            _buildInfoRow(Icons.timer, 'Duration', '$duration hours'),
            _buildInfoRow(Icons.people, 'Capacity', '$capacity persons'),
            _buildInfoRow(Icons.location_on, 'Location', location),
            
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description.isEmpty ? 'No description provided.' : description, style: const TextStyle(height: 1.5, color: Colors.black87)),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Back to Edit', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildFirstImage(dynamic item) {
    try {
      if (item is String) return Image.network(item, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error));
      if (item is XFile) return Image.file(File(item.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error));
    } catch (_) {}
    return const Icon(Icons.image_not_supported);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
