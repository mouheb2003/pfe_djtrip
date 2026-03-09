# 📱 TRAVELO FRONTEND - GUIDE COMPLET FLUTTER

## 🎯 Vue d'ensemble

**Travelo Frontend** est une application mobile Flutter connectée à l'API backend Travelo. Elle permet aux utilisateurs de s'inscrire, se connecter et gérer leur profil (Touriste ou Organisateur).

---

## 📂 Structure du Projet

```
FrontFlutter/lib/
├── config/
│   └── api_config.dart          # Configuration de l'API
├── models/
│   ├── user.dart                # Modèle User
│   ├── touriste.dart            # Modèle Touriste (hérite de User)
│   └── organisator.dart         # Modèle Organisator (hérite de User)
├── screens/
│   ├── auth/
│   │   ├── new_signup_screen.dart   # Page d'inscription
│   │   └── new_login_screen.dart    # Page de connexion
│   └── welcome_screen.dart      # Page de bienvenue après connexion
├── services/
│   ├── auth_service.dart        # Service d'authentification
│   └── storage_service.dart     # Gestion du stockage local
├── main.dart                    # Point d'entrée de l'app
└── splash_screen.dart           # Écran de démarrage
```

---

## 🚀 Installation

### Prérequis

- **Flutter SDK** (version 3.11.0 ou supérieur)
- **Android Studio** ou **VS Code** avec extension Flutter
- **Un appareil Android/iOS** ou un émulateur

### Installation des dépendances

```bash
cd FrontFlutter
flutter pub get
```

### Démarrage de l'application

```bash
flutter run
```

---

## 📦 Dépendances

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8 # Icônes iOS
  http: ^1.2.0 # Client HTTP pour les appels API
  shared_preferences: ^2.2.2 # Stockage local des tokens
  intl: ^0.20.2 # Internationalisation et formatage
```

---

## ⚙️ Configuration de l'API

### Modifier l'URL de l'API

Dans `lib/config/api_config.dart` :

```dart
class ApiConfig {
  // Pour émulateur Android
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // Pour appareil physique, utilisez l'IP de votre machine
  // static const String baseUrl = 'http://192.168.1.X:3000/api';

  // Pour production
  // static const String baseUrl = 'https://api.travelo.com/api';
}
```

**Notes importantes :**

- **Émulateur Android** : Utilisez `10.0.2.2` au lieu de `localhost`
- **Appareil physique** : Trouvez l'IP avec `ipconfig` (Windows) ou `ifconfig` (Mac/Linux)
- **iOS Simulator** : Utilisez `localhost` ou `127.0.0.1`

---

## 📱 Écrans (Screens)

### 1. Splash Screen

**Fichier** : `splash_screen.dart`

**Fonctionnalités :**

- Logo animé pendant 3 secondes
- Vérification automatique de connexion
- Navigation intelligente (Welcome si connecté, Signup sinon)

### 2. Signup Screen

**Fichier** : `screens/auth/new_signup_screen.dart`

**Fonctionnalités :**

- Formulaire avec validation complète
- Choix Touriste ou Organisator
- Champ entreprise conditionnel
- API call + navigation automatique

**Champs :**

- Nom complet (requis)
- Email (requis, validation)
- Type d'utilisateur
- Nom d'entreprise (si Organisator)
- Mot de passe + confirmation
- Acceptation des conditions

### 3. Login Screen

**Fichier** : `screens/auth/new_login_screen.dart`

**Fonctionnalités :**

- Email + mot de passe
- Option "Se souvenir de moi"
- Mot de passe oublié (TODO)
- Connexion réseaux sociaux (TODO)

### 4. Welcome Screen

**Fichier** : `screens/welcome_screen.dart`

**Fonctionnalités :**

- Profil utilisateur avec avatar
- Badge type d'utilisateur
- Animation d'entrée
- Déconnexion

---

## 🔧 Services

### Storage Service

**Fichier** : `services/storage_service.dart`

**Méthodes :**

```dart
// Sauvegarder les tokens
await StorageService.saveTokens(accessToken, refreshToken);

// Récupérer les tokens
final token = await StorageService.getAccessToken();
final refresh = await StorageService.getRefreshToken();

// Sauvegarder les infos user
await StorageService.saveUserInfo(userId, email, userType);

// Vérifier si connecté
final isLoggedIn = await StorageService.isLoggedIn();

// Tout effacer (logout)
await StorageService.clearAll();
```

---

### Auth Service

**Fichier** : `services/auth_service.dart`

**Méthodes :**

#### Inscription

```dart
final result = await AuthService.signUp(
  fullname: 'John Doe',
  email: 'john@example.com',
  password: 'password123',
  userType: 'Touriste',
  nomEntreprise: 'Ma Société',  // si Organisator
);
```

#### Connexion

```dart
final result = await AuthService.signIn(
  email: 'john@example.com',
  password: 'password123',
);
```

#### Info utilisateur

```dart
final result = await AuthService.getMyInfo();
if (result['success']) {
  User user = result['user'];
}
```

#### Rafraîchir le token

```dart
final success = await AuthService.refreshAccessToken();
```

#### Déconnexion

```dart
await AuthService.logout();
```

---

## 📊 Modèles

### User

```dart
class User {
  final String id;
  final String fullname;
  final String email;
  final String userType;  // "Touriste" ou "Organisator"
  // ... autres champs

  factory User.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

### Touriste (extends User)

```dart
class Touriste extends User {
  final List<String> centresInteret;
  final String languePreferee;
  // ...
}
```

### Organisator (extends User)

```dart
class Organisator extends User {
  final String nomEntreprise;
  final List<String> specialites;
  final double noteMoyenne;
  // ...
}
```

---

## 🎨 Design

### Couleurs

```dart
Color(0xFFFF6B1A)  // Orange principal
Color(0xFFFFB84D)  // Orange clair
Color(0xFF2D5016)  // Vert foncé
```

### Composants réutilisables

TextField personnalisé, boutons, cards, etc. utilisent un design cohérent avec :

- Bords arrondis (12-16px)
- Ombres subtiles
- Animations fluides

---

## 🔐 Flow d'authentification

```
App démarre → Splash (3s) → Vérification
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
              Connecté?            Pas connecté
                    ↓                   ↓
            WelcomeScreen          SignupScreen
```

---

## 🧪 Tests

### Test inscription

1. Lancez le backend
2. Configurez l'URL dans `api_config.dart`
3. `flutter run`
4. Remplissez le formulaire
5. Vérifiez la navigation vers Welcome

### Test persistance

1. Connectez-vous
2. Fermez l'app
3. Relancez
4. → Auto-login vers Welcome

---

## 🐛 Débogage

### "Connection refused"

- Vérifiez que le backend est démarré
- Utilisez `10.0.2.2` pour émulateur Android
- Utilisez l'IP de votre machine pour appareil physique

### "Token expired"

- Implémentez le refresh automatique
- Vérifiez la date/heure de l'appareil

---

## 📱 Build

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

---

## 📞 Ressources

- [Flutter Docs](https://flutter.dev/docs)
- [Package http](https://pub.dev/packages/http)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)

---

**🎉 Application Flutter Travelo prête !**
