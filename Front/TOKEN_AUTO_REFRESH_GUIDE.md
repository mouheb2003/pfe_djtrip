# 🔐 Système de Gestion Automatique des Tokens

## Problème Résolu

❌ **Avant** : Quand le token expirait, l'utilisateur était déconnecté brutalement  
✅ **Maintenant** : Le token se rafraîchit automatiquement de manière transparente !

## Architecture

### Backend (Node.js)

#### Durées des Tokens (`.env`)

```env
JWT_EXPIRES_IN=2h              # Token d'accès valide 2 heures
REFRESH_TOKEN_EXPIRES_IN=7d    # Token de rafraîchissement valide 7 jours
```

**Avantages :**

- Token d'accès de 2h au lieu de 15 min → Moins de rafraîchissements
- Token de refresh de 7 jours → L'utilisateur reste connecté une semaine
- Configuration flexible via variables d'environnement

#### Middleware Auth (`middleware/auth.js`)

- Utilise les durées configurées dans `.env`
- Endpoint `/api/users/refresh-token` pour rafraîchir le token

### Frontend (Flutter)

#### 1. HttpClient avec Auto-Refresh (`services/http_client.dart`)

**Fonctionnement :**

```dart
// L'utilisateur fait une requête normale
final response = await HttpClient.get('https://api.example.com/profile');

// Si le serveur répond 401 (token expiré) :
// 1. HttpClient détecte automatiquement l'erreur
// 2. Appelle l'endpoint de refresh pour obtenir un nouveau token
// 3. Sauvegarde le nouveau token
// 4. Réessaye automatiquement la requête originale
// 5. L'utilisateur ne voit rien, tout est transparent !
```

**Avantages :**

- ✅ Transparent pour l'utilisateur
- ✅ Pas de déconnexion brutale
- ✅ Gère les requêtes concurrentes (évite plusieurs refresh en même temps)
- ✅ Nettoie automatiquement si le refresh échoue

#### 2. AuthErrorHandler (`utils/auth_error_handler.dart`)

Gère les cas où le refresh échoue (refresh token expiré) :

- Affiche un dialogue élégant
- Redirige vers la page de connexion
- Permet de personnaliser le comportement

## Utilisation

### Pour les nouvelles API

**Avant (ancien code) :**

```dart
final accessToken = await StorageService.getAccessToken();
final response = await http.get(
  Uri.parse(ApiConfig.myInfo),
  headers: {
    'Authorization': 'Bearer $accessToken',
  },
);
```

**Maintenant (nouveau code) :**

```dart
final headers = await HttpClient.getAuthHeaders();
final response = await HttpClient.get(
  ApiConfig.myInfo,
  headers: headers,
);
// Le token se rafraîchit automatiquement si nécessaire !
```

### Dans les Screens

```dart
class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  Future<void> _loadData() async {
    // Faire une requête API
    final result = await UserService.getUserInfo();

    // Gérer les erreurs (y compris session expirée)
    if (mounted) {
      AuthErrorHandler.handleAuthError(context, result);

      if (result['success']) {
        // Traiter les données
        final user = result['user'];
        setState(() {
          // Mettre à jour l'UI
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthRequiredWidget(
      onSessionExpired: () {
        print('Utilisateur redirigé vers login');
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Mon Écran')),
        body: /* Votre contenu */,
      ),
    );
  }
}
```

## Scénarios Gérés

### Scénario 1 : Token expire pendant l'utilisation

1. Utilisateur clique sur "Mettre à jour profil"
2. Token a expiré (2h écoulées)
3. **HttpClient détecte l'erreur 401**
4. **HttpClient rafraîchit automatiquement le token**
5. **HttpClient réessaye la requête avec le nouveau token**
6. Profil mis à jour ✅
7. **L'utilisateur n'a rien vu ! Expérience fluide**

### Scénario 2 : Refresh token aussi expiré

1. Utilisateur revient après 8 jours (refresh token de 7 jours expiré)
2. Token d'accès expiré
3. HttpClient essaye de rafraîchir → Échec (refresh token expiré)
4. **TokenExpiredException lancée**
5. **AuthErrorHandler affiche un dialogue élégant**
6. **Utilisateur redirigé vers la page de connexion**
7. Message clair : "Votre session a expiré. Veuillez vous reconnecter."

### Scénario 3 : Requêtes multiples simultanées

1. Plusieurs requêtes API envoyées en même temps
2. Toutes échouent avec 401
3. **Première requête déclenche le refresh**
4. **Autres requêtes attendent le résultat du refresh**
5. **Toutes réessayent avec le nouveau token**
6. Évite de multiples appels au refresh endpoint

## Services Mis à Jour

### UserService

```dart
// Utilise maintenant HttpClient au lieu de http directement
import 'http_client.dart';

static Future<Map<String, dynamic>> updateProfile(
  Map<String, dynamic> updateData,
) async {
  final headers = await HttpClient.getAuthHeaders();
  final response = await HttpClient.put(
    ApiConfig.updateProfile,
    headers: headers,
    body: jsonEncode(updateData),
  );
  // Auto-refresh si le token expire !
}
```

### Services à Migrer

Pour migrer vos services existants vers le nouveau système :

1. Importer `http_client.dart`
2. Remplacer `http.get/post/put/delete` par `HttpClient.get/post/put/delete`
3. Utiliser `HttpClient.getAuthHeaders()` pour les headers
4. Attraper `TokenExpiredException` si besoin
5. Utiliser `AuthErrorHandler` dans l'UI

## Configuration Recommandée

### Production

```env
JWT_EXPIRES_IN=1h              # 1 heure
REFRESH_TOKEN_EXPIRES_IN=30d   # 30 jours
```

### Développement

```env
JWT_EXPIRES_IN=2h              # 2 heures (moins de refresh)
REFRESH_TOKEN_EXPIRES_IN=7d    # 7 jours
```

### Tests

```env
JWT_EXPIRES_IN=5m              # 5 minutes (tester le refresh souvent)
REFRESH_TOKEN_EXPIRES_IN=1h    # 1 heure
```

## Sécurité

✅ **Ce qui est sécurisé :**

- Token d'accès court (2h) limite l'exposition si volé
- Refresh token stocké de manière sécurisée (SharedPreferences)
- Refresh automatique transparent
- Nettoyage automatique si refresh échoue

⚠️ **À faire en production :**

- Utiliser HTTPS uniquement
- Implémenter token rotation (nouveau refresh token à chaque refresh)
- Ajouter rate limiting sur l'endpoint refresh
- Logger les tentatives de refresh suspectes
- Ajouter device fingerprinting

## Avantages UX

🎉 **Pour l'utilisateur :**

- Reste connecté pendant 7 jours
- Pas de déconnexion surprise
- Expérience fluide et transparente
- Message clair si reconnexion nécessaire

👨‍💻 **Pour le développeur :**

- Code simple et réutilisable
- Gestion centralisée des erreurs
- Moins de code boilerplate
- Facile à tester

## Dépannage

### Le token ne se rafraîchit pas

1. Vérifier que le refresh token est sauvegardé
2. Vérifier `/api/users/refresh-token` fonctionne
3. Vérifier les logs du HttpClient
4. Vérifier la durée du refresh token dans `.env`

### Déconnexion fréquente

1. Augmenter `REFRESH_TOKEN_EXPIRES_IN`
2. Vérifier que le storage persiste bien
3. Vérifier les logs backend pour les erreurs

### Requêtes lentes

1. Réduire `JWT_EXPIRES_IN` (moins de refresh)
2. Optimiser l'endpoint refresh
3. Vérifier la latence réseau
