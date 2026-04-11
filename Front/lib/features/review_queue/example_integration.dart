import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/review_queue/models/booking_review_model.dart';
import 'features/review_queue/models/review_queue_item.dart';
import 'features/review_queue/services/review_queue_service.dart';
import 'features/review_queue/services/review_storage_service.dart';
import 'features/review_queue/services/review_api_service.dart';
import 'features/review_queue/providers/review_queue_provider.dart';
import 'features/review_queue/ui/widgets/review_badge.dart';
import 'features/review_queue/ui/widgets/review_modal.dart';

/// Exemple d'intégration complète du système de review
/// Ce fichier montre comment intégrer le système dans votre application

// 1. Adapter Hive pour ReviewQueueItem (nécessaire pour la persistance)
class ReviewQueueItemAdapter extends TypeAdapter<ReviewQueueItem> {
  @override
  final int typeId = 100;

  @override
  ReviewQueueItem read(BinaryReader reader) {
    return ReviewQueueItem.fromJson(reader.readMap());
  }

  @override
  void write(BinaryWriter writer, ReviewQueueItem obj) {
    writer.writeMap(obj.toJson());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialiser Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ReviewQueueItemAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 3. Initialiser le ReviewQueueProvider
        ChangeNotifierProvider(
          create: (_) => ReviewQueueProvider(
            service: ReviewQueueService(
              storageService: ReviewStorageService(),
              apiService: ReviewApiService(
                baseUrl: 'https://api.example.com',
              ),
              userToken: 'YOUR_USER_AUTH_TOKEN', // Récupérer depuis votre auth service
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Review System Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/review-list': (context) => const ReviewListScreen(),
        },
      ),
    );
  }
}

/// Écran d'accueil avec badge de review
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 4. Vérifier et afficher le popup automatiquement après un délai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        _checkAndShowPopup();
      });
    });
  }

  Future<void> _checkAndShowPopup() async {
    if (!mounted) return;

    final provider = context.read<ReviewQueueProvider>();
    final nextItem = provider.getNextItemToShow();

    if (nextItem != null) {
      await showReviewModal(context, nextItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // 5. Badge de review sur l'icône de notifications
          ReviewBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.pushNamed(context, '/review-list');
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Screen'),
            const SizedBox(height: 20),
            Consumer<ReviewQueueProvider>(
              builder: (context, provider, _) {
                return Text(
                  'Pending reviews: ${provider.pendingCount}',
                  style: const TextStyle(fontSize: 18),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran de liste des reviews en attente
class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Reviews'),
      ),
      body: Consumer<ReviewQueueProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.forceSync(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!provider.hasPendingReviews) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No pending reviews',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.forceSync(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.queue.length,
              itemBuilder: (context, index) {
                final item = provider.queue[index];
                return ReviewItemCard(
                  item: item,
                  onReview: () => showReviewModal(context, item),
                  onDismiss: () => _showDismissDialog(context, item, provider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDismissDialog(
    BuildContext context,
    ReviewQueueItem item,
    ReviewQueueProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss review'),
        content: Text(
          'Are you sure you don\'t want to review "${item.booking.activityTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.dismissItem(item.booking.id);
              Navigator.pop(context);
            },
            child: const Text('Dismiss', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Carte d'item de review
class ReviewItemCard extends StatelessWidget {
  final ReviewQueueItem item;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  const ReviewItemCard({
    super.key,
    required this.item,
    required this.onReview,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final booking = item.booking;
    final daysSinceEnd = DateTime.now().difference(booking.endDate).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (booking.activityImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      booking.activityImageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.activityTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ended $daysSinceEnd days ago',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Expires in ${7 - daysSinceEnd} days',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Review Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de badge personnalisé pour la navigation bottom
class ReviewBottomNavBadge extends StatelessWidget {
  final int index;
  final Widget icon;

  const ReviewBottomNavBadge({
    super.key,
    required this.index,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ReviewBadge(
      badgeColor: Colors.red,
      badgeSize: 16,
      child: icon,
    );
  }
}
