import 'package:flutter/material.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final missingRoute = routeName == null || routeName!.isEmpty
        ? 'unknown'
        : routeName!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page introuvable'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              const Text(
                '404 - Route introuvable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Route demandee: $missingRoute',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Retour a l accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
