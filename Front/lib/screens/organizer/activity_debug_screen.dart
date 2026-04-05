import 'package:flutter/material.dart';

class ActivityDebugScreen extends StatelessWidget {
  final String title;
  final String category;
  final String description;
  final double price;

  const ActivityDebugScreen({
    super.key,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    // On accepte les autres paramètres mais on ne les utilise pas pour le debug
    dynamic capacity,
    dynamic location,
    dynamic duration,
    dynamic startDateTime,
    dynamic endDateTime,
    dynamic existingPhotos,
    dynamic photos,
    dynamic requirements,
    dynamic optional,
    dynamic pickedLatLng,
    dynamic difficulty,
    dynamic languages,
    dynamic durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent, // Fond bleu pour voir si ça s'affiche enfin
      appBar: AppBar(
        title: const Text('DEBUG PREVIEW'),
        backgroundColor: Colors.white10,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                'L\'aperçu fonctionne !',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('Titre: $title'),
              Text('Catégorie: $category'),
              Text('Prix: $price TND'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('RETOUR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
