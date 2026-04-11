# 📋 Système de Review Intelligent - Documentation

## 🏗️ Architecture

Le système de review intelligent est conçu avec une architecture en couches, séparant clairement les responsabilités :

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ ReviewModal  │  │ ReviewBadge  │  │ ReviewList   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│               State Management Layer                     │
│              ReviewQueueProvider                         │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  Service Layer                            │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ReviewQueueService│  │ReviewApiService  │            │
│  └──────────────────┘  └──────────────────┘            │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ReviewStorageSvc  │  │ReviewNotification│            │
│  └──────────────────┘  └──────────────────┘            │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  Data Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ BookingModel │  │QueueItemModel│  │   Hive DB    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📦 Structure des fichiers

```
lib/features/review_queue/
├── models/
│   ├── booking_review_model.dart       # Modèle de base des bookings
│   └── review_queue_item.dart          # Item de queue avec métadonnées
├── services/
│   ├── review_queue_service.dart       # Service principal de queue
│   ├── review_storage_service.dart     # Persistance locale (Hive)
│   ├── review_api_service.dart         # Communication API
│   └── review_notification_service.dart # Notifications FCM
├── providers/
│   └── review_queue_provider.dart      # State management (Provider)
├── ui/
│   ├── widgets/
│   │   ├── review_badge.dart           # Badge indicateur
│   │   └── review_modal.dart           # Modal de review
│   └── screens/
│       └── review_list_screen.dart     # Liste des reviews en attente
└── notifications/
    └── review_notification_service.dart # Service de notifications
```

## 🚀 Utilisation

### 1. Initialisation dans main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ReviewQueueItemAdapter());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Initialiser le service de queue
        ChangeNotifierProvider(
          create: (_) => ReviewQueueProvider(
            service: ReviewQueueService(
              storageService: ReviewStorageService(),
              apiService: ReviewApiService(
                baseUrl: 'https://api.example.com',
              ),
              userToken: 'user_auth_token',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        // ...
      ),
    );
  }
}
```

### 2. Afficher le badge sur un écran

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          ReviewBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewListScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: const Center(child: Text('Home')),
    );
  }
}
```

### 3. Afficher le modal automatiquement

```dart
class SomeScreen extends StatefulWidget {
  @override
  _SomeScreenState createState() => _SomeScreenState();
}

class _SomeScreenState extends State<SomeScreen> {
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    _checkAndShowPopup();
  }

  Future<void> _checkAndShowPopup() async {
    // Attendre un peu avant de vérifier
    await Future.delayed(const Duration(seconds: 2));
    
    final provider = context.read<ReviewQueueProvider>();
    final nextItem = provider.getNextItemToShow();
    
    if (nextItem != null && mounted) {
      await showReviewModal(context, nextItem);
    }
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Some Screen')),
    );
  }
}
```

### 4. Liste des reviews en attente

```dart
class ReviewListScreen extends StatelessWidget {
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

          if (!provider.hasPendingReviews) {
            return const Center(
              child: Text('No pending reviews'),
            );
          }

          return ListView.builder(
            itemCount: provider.queue.length,
            itemBuilder: (context, index) {
              final item = provider.queue[index];
              return ReviewItemCard(
                item: item,
                onReview: () => showReviewModal(context, item),
                onDismiss: () => provider.dismissItem(item.booking.id),
              );
            },
          );
        },
      ),
    );
  }
}
```

## 🔧 Configuration

### Dépendances requises

Ajoutez à votre `pubspec.yaml` :

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State management
  provider: ^6.0.0
  
  # Persistance locale
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # HTTP
  http: ^1.1.0
  
  # Notifications
  firebase_messaging: ^14.6.0
  flutter_local_notifications: ^16.0.0
  
  # Utilitaires
  equatable: ^2.0.5
```

### Configuration Hive

Pour utiliser Hive avec des types personnalisés, vous devez créer des adapters :

```dart
import 'package:hive/hive.dart';
import '../models/review_queue_item.dart';

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
```

## 🎯 Fonctionnalités Clés

### 1. Queue Intelligente

- **Tri automatique** : Les bookings sont triés par date de fin (plus récents d'abord)
- **Cooldown anti-spam** : 5 minutes minimum entre chaque popup
- **Session tracking** : Un booking n'est affiché qu'une fois par session
- **Snooze intelligent** : Possibilité de remettre à plus tard

### 2. Persistance Locale

- **Hive** : Base de données NoSQL rapide et performante
- **Queue persistante** : Survit aux redémarrages de l'app
- **Session tracking** : Mémorise les bookings déjà affichés
- **Auto-cleanup** : Nettoie les données anciennes automatiquement

### 3. Notifications Push

- **FCM** : Firebase Cloud Messaging pour les notifications
- **Rappels programmés** : 2j, 5j, 7j après la fin de l'activité
- **Navigation intelligente** : Clique sur notif → ouvre le modal
- **Permission handling** : Gère automatiquement les permissions

### 4. UX Non Intrusive

- **Un seul popup à la fois** : Jamais de popups multiples
- **Design moderne** : Inspiré d'Uber/Airbnb
- **Options claires** : Submit, Later, Don't ask again
- **Feedback haptique** : Vibrations pour les actions

## 📊 Analytics (Optionnel)

Pour tracker les interactions, vous pouvez ajouter :

```dart
// Dans ReviewQueueService
Future<void> _trackEvent(String event, Map<String, dynamic> properties) async {
  // Utiliser Firebase Analytics, Mixpanel, Amplitude, etc.
  await FirebaseAnalytics().logEvent(
    name: event,
    parameters: properties,
  );
}

// Exemple d'utilisation
await _trackEvent('review_popup_shown', {
  'booking_id': bookingId,
  'activity_title': activityTitle,
});
```

## 🧪 Tests

### Exemple de test unitaire

```dart
test('should filter eligible bookings', () {
  final bookings = [
    BookingReviewModel(
      id: '1',
      activityId: 'a1',
      activityTitle: 'Activity 1',
      endDate: DateTime.now().subtract(Duration(days: 1)),
      isReviewed: false,
      isCheckedIn: true,
    ),
    // ...
  ];

  final filtered = service._filterEligibleBookings(bookings);
  expect(filtered.length, greaterThan(0));
});
```

## 🔒 Sécurité

- **Token sécurisé** : Le token utilisateur est stocké en mémoire
- **Validation backend** : L'API valide toutes les soumissions
- **Rate limiting** : Cooldown côté client et serveur

## 🚨 Gestion des erreurs

Le système gère plusieurs scénarios d'erreur :

1. **Offline** : La queue est persistée localement
2. **API timeout** : Retry automatique avec backoff exponentiel
3. **Network error** : Message d'erreur utilisateur-friendly
4. **Corrupted data** : Fallback sur données par défaut

## 📈 Performance

- **Lazy loading** : Les données sont chargées à la demande
- **Efficient queries** : Index Hive optimisés
- **Memory efficient** : Utilisation de `unmodifiable` lists
- **Background sync** : Synchronisation en arrière-plan

## 🎨 Personnalisation

### Changer les couleurs du badge

```dart
ReviewBadge(
  badgeColor: Colors.orange,
  badgeSize: 20.0,
  child: IconButton(...),
)
```

### Modifier les tags

```dart
static const List<String> _customTags = [
  'Custom Tag 1',
  'Custom Tag 2',
  // ...
];
```

### Ajuster les délais de rappel

```dart
static const List<Duration> _customReminderDelays = [
  Duration(hours: 12),  // Plus rapide
  Duration(days: 3),
  Duration(days: 6),
];
```

## 🤝 Contribution

Pour étendre le système :

1. Ajoutez de nouvelles features dans `ReviewQueueService`
2. Créez de nouveaux widgets dans `ui/widgets/`
3. Mettez à jour la documentation
4. Ajoutez des tests unitaires

## 📝 Notes importantes

- Le système nécessite un backend compatible
- Les notifications FCM nécessitent une configuration Firebase
- Hive nécessite des adapters pour les types personnalisés
- Le cooldown est configurable selon vos besoins

## 🆘 Support

Pour toute question ou problème :
1. Vérifiez la documentation
2. Consultez les tests unitaires
3. Regardez les exemples d'utilisation
