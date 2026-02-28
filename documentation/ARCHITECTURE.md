# 🏗️ Architecture Technique - Travelo

Documentation détaillée de l'architecture du projet Travelo.

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Frontend Flutter](#frontend-flutter)
3. [Backend Node.js](#backend-nodejs)
4. [Base de Données MongoDB](#base-de-données-mongodb)
5. [Services Externes](#services-externes)
6. [Flux de Données](#flux-de-données)
7. [Sécurité](#sécurité)
8. [Performance](#performance)

---

## 🌐 Vue d'Ensemble

### Stack Technique

```
┌─────────────────────────────────────────────┐
│           Frontend - Flutter                │
│  • Dart 3.11.0                             │
│  • Material Design 3                       │
│  • SharedPreferences (persistence)         │
│  • image_picker (photos)                   │
└──────────────┬──────────────────────────────┘
               │ HTTP/REST API
               │ JWT Authentication
┌──────────────▼──────────────────────────────┐
│          Backend - Node.js/Express         │
│  • Express.js (routing)                    │
│  • JWT (auth)                              │
│  • Multer (file upload)                    │
│  • Bcrypt (passwords)                      │
└──────────────┬──────────────────┬───────────┘
               │                  │
      ┌────────▼─────┐   ┌───────▼──────┐
      │   MongoDB    │   │  Cloudinary  │
      │  (Database)  │   │   (Images)   │
      └──────────────┘   └──────────────┘
```

### Architecture Pattern

**Frontend** : MVC-like (Model-View-Controller)

- **Models** : Classes de données (`User`, `Touriste`, `Organisator`)
- **Views** : Widgets Flutter (screens + components)
- **Controllers** : Services (`AuthService`, `UserService`)

**Backend** : MVC (Model-View-Controller)

- **Models** : Schémas Mongoose
- **Views** : Responses JSON
- **Controllers** : Logique métier

---

## 📱 Frontend Flutter

### Structure des Dossiers

```
FrontFlutter/lib/
├── main.dart                    # Point d'entrée
├── splash_screen.dart           # Écran de chargement
├── home_screen.dart             # Page d'accueil principale
│
├── config/
│   └── api_config.dart          # Configuration API (baseUrl, endpoints)
│
├── models/
│   └── user.dart                # Modèles User/Touriste/Organisator
│
├── services/
│   ├── auth_service.dart        # Authentification (signup, signin, logout)
│   └── user_service.dart        # Profil utilisateur (update, avatar, preferences)
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart    # Connexion
│   │   └── signup_screen.dart   # Inscription
│   │
│   ├── onboarding/
│   │   ├── profile_completion_screen.dart  # Formulaire 3 étapes
│   │   └── permissions_screen.dart         # Accordeur de permissions
│   │
│   ├── profile_screen.dart             # Affichage du profil
│   ├── edit_profile_screen.dart        # Édition du profil
│   ├── preferences_screen.dart         # Centres d'intérêt
│   ├── country_selection_screen.dart   # Sélecteur de pays
│   └── language_selection_screen.dart  # Sélecteur de langue
│
└── utils/
    ├── countries.dart           # Data: 195 pays
    └── languages.dart           # Data: 49 langues
```

### Gestion d'État

**Approche** : StatefulWidget avec setState

**Pourquoi ?**

- Simplicité pour un projet de taille moyenne
- Pas de complexité inutile (Provider, Bloc, etc.)
- Performances suffisantes avec setState ciblé

**Exemple** :

```dart
class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await UserService.getUserProfile();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Navigation

**Pattern** : Navigator 2.0 avec routes nommées

**Écran Principal** : Bottom Navigation Bar (4 tabs)

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
    BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorer'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Réservations'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
  ],
)
```

**Flux de Navigation** :

```
SplashScreen
    ↓
LoginScreen ←→ SignupScreen
    ↓
ProfileCompletionScreen (3 étapes)
    ↓
PermissionsScreen
    ↓
HomeScreen (Bottom Nav)
    ├── Home Tab
    ├── Explore Tab
    ├── Bookings Tab
    └── Profile Tab
            ↓
        EditProfileScreen
            ├→ CountrySelectionScreen
            ├→ LanguageSelectionScreen
            └→ PreferencesScreen
```

### Services

#### AuthService

```dart
class AuthService {
  // Inscription
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String nomComplet,
    required String userType,
  })

  // Connexion
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  })

  // Déconnexion
  static Future<void> logout()

  // Vérification
  static Future<bool> isLoggedIn()
  static Future<String?> getAccessToken()
}
```

#### UserService

```dart
class UserService {
  // Récupérer le profil
  static Future<User> getUserProfile()

  // Mettre à jour le profil
  static Future<User> updateProfile(Map<String, dynamic> data)

  // Upload avatar
  static Future<String> updateAvatar(String imagePath)

  // Préférences
  static Future<void> updatePreferences(List<String> preferences)
}
```

### Persistance Locale

**Package** : `shared_preferences`

**Données Stockées** :

```dart
SharedPreferences prefs = await SharedPreferences.getInstance();

// Tokens
prefs.setString('access_token', token);
prefs.setString('refresh_token', refreshToken);

// User Info
prefs.setString('user_id', userId);
prefs.setString('user_email', email);
prefs.setString('user_type', userType);

// État
prefs.setBool('is_logged_in', true);
```

**Nettoyage à la Déconnexion** :

```dart
await prefs.remove('access_token');
await prefs.remove('refresh_token');
await prefs.remove('user_id');
await prefs.remove('user_email');
await prefs.setBool('is_logged_in', false);
```

### Gestion des Images

**Package** : `image_picker`

**Sources** :

- 📷 Caméra
- 🖼️ Galerie

**Workflow** :

```dart
// 1. Sélection
final XFile? image = await ImagePicker().pickImage(
  source: ImageSource.camera, // ou ImageSource.gallery
  maxWidth: 800,
  maxHeight: 800,
  imageQuality: 85,
);

// 2. Upload
if (image != null) {
  final avatarUrl = await UserService.updateAvatar(image.path);

  // 3. Mise à jour UI
  setState(() {
    _user.avatar = avatarUrl;
  });
}
```

---

## 🖥️ Backend Node.js

### Structure des Dossiers

```
Back/pfe_backend-main/
├── server.js                    # Point d'entrée
│
├── config/
│   ├── db.js                    # Connexion MongoDB
│   └── cloudinary.js            # Configuration Cloudinary
│
├── models/
│   ├── user.js                  # Schéma User (base)
│   ├── touriste.js              # Schéma Touriste (extends User)
│   └── organisator.js           # Schéma Organisator (extends User)
│
├── controllers/
│   ├── user.js                  # Logique User (signup, signin, profile, etc.)
│   ├── touriste.js              # Logique spécifique Touriste
│   └── organisator.js           # Logique spécifique Organisator
│
├── routes/
│   ├── user.js                  # Routes User (/users/*)
│   ├── touriste.js              # Routes Touriste (/touristes/*)
│   └── organisator.js           # Routes Organisator (/organisators/*)
│
└── middleware/
    ├── auth.js                  # Middleware d'authentification JWT
    └── upload.js                # Middleware Multer (upload fichiers)
```

### Modèles MongoDB

#### Schéma User (Base)

```javascript
const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true }, // Hash bcrypt
    nom_complet: { type: String, required: true },
    userType: {
      type: String,
      enum: ["Touriste", "Organisator"],
      required: true,
    },

    // Profil
    age: { type: Number, min: 13, max: 120 },
    telephone: { type: String },
    pays: { type: String },
    bio: { type: String, maxlength: 500 },
    avatar: { type: String },

    // Préférences
    centres_interet: [{ type: String }],

    // Notifications
    accept_notifications_email: { type: Boolean, default: true },
    accept_notifications_sms: { type: Boolean, default: false },

    // État
    status: {
      type: String,
      enum: ["actif", "inactif"],
      default: "inactif",
    },
    derniere_connexion: { type: Date },
  },
  {
    timestamps: true, // createdAt, updatedAt
    discriminatorKey: "userType",
  },
);
```

#### Touriste (extends User)

```javascript
const touristeSchema = new mongoose.Schema({
  langue_preferee: { type: String },
  // Champs spécifiques aux touristes
});

const Touriste = User.discriminator("Touriste", touristeSchema);
```

#### Organisator (extends User)

```javascript
const organisatorSchema = new mongoose.Schema({
  nom_entreprise: { type: String },
  // Champs spécifiques aux organisateurs
});

const Organisator = User.discriminator("Organisator", organisatorSchema);
```

### Middleware

#### Auth Middleware

```javascript
const jwt = require("jsonwebtoken");

module.exports = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];

    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    req.userType = decoded.userType;

    next();
  } catch (error) {
    return res.status(401).json({ message: "Invalid token" });
  }
};
```

#### Upload Middleware

```javascript
const multer = require("multer");

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "/tmp");
  },
  filename: (req, file, cb) => {
    cb(null, `avatar-${Date.now()}-${file.originalname}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith("image/")) {
      cb(null, true);
    } else {
      cb(new Error("Only images are allowed"));
    }
  },
});

module.exports = upload;
```

### Controllers

#### Exemple : updateProfile

```javascript
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.userId; // Depuis auth middleware
    const updateData = req.body;

    // Validation
    if (updateData.age && (updateData.age < 13 || updateData.age > 120)) {
      return res
        .status(400)
        .json({ message: "Age must be between 13 and 120" });
    }

    // Mise à jour
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { new: true, runValidators: true },
    ).select("-password");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "Profile updated successfully",
      user,
    });
  } catch (error) {
    console.error("Update profile error:", error);
    res.status(500).json({ message: "Server error" });
  }
};
```

### Routes

```javascript
const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const authMiddleware = require("../middleware/auth");
const upload = require("../middleware/upload");

// Publiques
router.post("/signup", userController.signUp);
router.post("/signin", userController.signIn);
router.post("/refresh", userController.refreshToken);

// Protégées
router.get("/profile", authMiddleware, userController.getProfile);
router.put("/profile", authMiddleware, userController.updateProfile);
router.put("/preferences", authMiddleware, userController.updatePreferences);
router.post(
  "/avatar",
  authMiddleware,
  upload.single("avatar"),
  userController.uploadAvatar,
);
router.post("/logout", authMiddleware, userController.logout);

module.exports = router;
```

---

## 🗄️ Base de Données MongoDB

### Collections

#### users

Contient tous les utilisateurs (Touristes et Organisators) grâce au discriminator pattern.

**Index** :

```javascript
// Unique sur email
db.users.createIndex({ email: 1 }, { unique: true });

// Performance sur status
db.users.createIndex({ status: 1 });

// Performance sur derniere_connexion
db.users.createIndex({ derniere_connexion: 1 });
```

**Exemple de Document** :

```json
{
  "_id": ObjectId("65abc123..."),
  "email": "john@example.com",
  "password": "$2b$10$...",
  "nom_complet": "John Doe",
  "userType": "Touriste",
  "age": 25,
  "telephone": "+212600000000",
  "pays": "Maroc",
  "langue_preferee": "Français",
  "bio": "Passionné de voyages",
  "avatar": "https://res.cloudinary.com/.../avatar.jpg",
  "centres_interet": ["Plages", "Aventure"],
  "accept_notifications_email": true,
  "accept_notifications_sms": false,
  "status": "actif",
  "derniere_connexion": ISODate("2026-02-28T10:00:00Z"),
  "createdAt": ISODate("2026-01-01T00:00:00Z"),
  "updatedAt": ISODate("2026-02-28T10:00:00Z"),
  "__v": 0
}
```

### Discriminator Pattern

**Avantages** :

- ✅ Une seule collection pour tous les utilisateurs
- ✅ Champs communs dans User
- ✅ Champs spécifiques dans Touriste/Organisator
- ✅ Requêtes polymorphiques possibles
- ✅ Évite les JOIN (MongoDB = NoSQL)

**Fonctionnement** :

```javascript
// Créer un Touriste
const touriste = new Touriste({
  email: "touriste@example.com",
  password: "...",
  nom_complet: "Tourist User",
  langue_preferee: "English",
});
// MongoDB ajoute automatiquement : userType: 'Touriste'

// Créer un Organisator
const organisator = new Organisator({
  email: "org@example.com",
  password: "...",
  nom_complet: "Org User",
  nom_entreprise: "Travel Co",
});
// MongoDB ajoute automatiquement : userType: 'Organisator'

// Requêter
const allUsers = await User.find(); // Tous les utilisateurs
const onlyTouristes = await Touriste.find(); // Seulement touristes
```

---

## ☁️ Services Externes

### Cloudinary

**Configuration** :

```javascript
const cloudinary = require("cloudinary").v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true, // HTTPS
});
```

**Upload d'Avatar** :

```javascript
const result = await cloudinary.uploader.upload(filePath, {
  folder: "avatars",
  width: 400,
  height: 400,
  crop: "fill",
  quality: 85,
  format: "jpg",
});

const avatarUrl = result.secure_url;
```

**Avantages** :

- ✅ CDN global (rapide partout)
- ✅ Transformations automatiques (resize, crop, optimize)
- ✅ HTTPS par défaut
- ✅ Pas de stockage local nécessaire
- ✅ Plan gratuit généreux (25GB)

---

## 🔄 Flux de Données

### Inscription (Sign Up)

```
┌─────────┐                 ┌──────────┐                ┌──────────┐
│ Flutter │                 │ Express  │                │ MongoDB  │
└────┬────┘                 └────┬─────┘                └────┬─────┘
     │                           │                           │
     │  POST /users/signup       │                           │
     │  { email, password, ... } │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │                           │  Hash password (bcrypt)   │
     │                           │                           │
     │                           │  User.create(...)         │
     │                           ├──────────────────────────>│
     │                           │                           │
     │                           │  { _id, email, ... }      │
     │                           │<──────────────────────────┤
     │                           │                           │
     │                           │  Generate JWT tokens      │
     │                           │                           │
     │  { token, refreshToken,   │                           │
     │    user }                 │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │  Store tokens locally     │                           │
     │  (SharedPreferences)      │                           │
     │                           │                           │
     │  Navigate to Onboarding   │                           │
     │                           │                           │
```

### Connexion (Sign In) avec Mise à Jour du Statut

```
┌─────────┐                 ┌──────────┐                ┌──────────┐
│ Flutter │                 │ Express  │                │ MongoDB  │
└────┬────┘                 └────┬─────┘                └────┬─────┘
     │                           │                           │
     │  POST /users/signin       │                           │
     │  { email, password }      │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │                           │  User.findOne({ email })  │
     │                           ├──────────────────────────>│
     │                           │                           │
     │                           │  { user }                 │
     │                           │<──────────────────────────┤
     │                           │                           │
     │                           │  bcrypt.compare(password) │
     │                           │                           │
     │                           │  Check inactivité (180j)  │
     │                           │                           │
     │                           │  Update status = "actif"  │
     │                           │  Update derniere_connexion│
     │                           ├──────────────────────────>│
     │                           │                           │
     │                           │  Generate JWT tokens      │
     │                           │                           │
     │  { token, refreshToken,   │                           │
     │    user }                 │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │  Store tokens locally     │                           │
     │                           │                           │
     │  Navigate to HomeScreen   │                           │
     │                           │                           │
```

### Upload d'Avatar

```
┌─────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐
│ Flutter │   │ Express  │   │ Cloudinary │   │ MongoDB  │
└────┬────┘   └────┬─────┘   └─────┬──────┘   └────┬─────┘
     │             │               │               │
     │  ImagePicker.pickImage()    │               │
     │             │               │               │
     │  POST /users/avatar         │               │
     │  (multipart/form-data)      │               │
     ├────────────>│               │               │
     │             │               │               │
     │             │  Multer save to /tmp          │
     │             │               │               │
     │             │  cloudinary.uploader.upload() │
     │             ├──────────────>│               │
     │             │               │               │
     │             │  { secure_url }               │
     │             │<──────────────┤               │
     │             │               │               │
     │             │  User.findByIdAndUpdate(...)  │
     │             │  { avatar: url }              │
     │             ├───────────────────────────────>│
     │             │               │               │
     │             │  Delete temp file (/tmp)      │
     │             │               │               │
     │  { avatarUrl }              │               │
     │<────────────┤               │               │
     │             │               │               │
     │  Update UI  │               │               │
     │             │               │               │
```

---

## 🔒 Sécurité

### JWT (JSON Web Tokens)

**Structure** :

```
Header.Payload.Signature
```

**Payload Example** :

```json
{
  "userId": "65abc123...",
  "email": "user@example.com",
  "userType": "Touriste",
  "iat": 1709116800,
  "exp": 1709117700
}
```

**Génération** :

```javascript
const accessToken = jwt.sign(
  { userId: user._id, email: user.email, userType: user.userType },
  process.env.JWT_SECRET,
  { expiresIn: "15m" },
);

const refreshToken = jwt.sign(
  { userId: user._id },
  process.env.JWT_REFRESH_SECRET,
  { expiresIn: "7d" },
);
```

**Vérification** :

```javascript
const decoded = jwt.verify(token, process.env.JWT_SECRET);
// Si invalide ou expiré → throw error
```

### Mot de Passe

**Hachage** :

```javascript
const bcrypt = require("bcrypt");
const SALT_ROUNDS = 10;

// Inscription
const hashedPassword = await bcrypt.hash(plainPassword, SALT_ROUNDS);
user.password = hashedPassword;

// Connexion
const isMatch = await bcrypt.compare(plainPassword, user.password);
```

**Pourquoi bcrypt ?**

- ✅ Résistant aux attaques par force brute (lent par design)
- ✅ Salage automatique (salt aléatoire par mot de passe)
- ✅ Standard de l'industrie

### CORS

**Configuration Développement** :

```javascript
app.use(cors({ origin: "*" }));
```

**Configuration Production** (recommandé) :

```javascript
app.use(
  cors({
    origin: ["https://travelo.com", "https://app.travelo.com"],
    credentials: true,
  }),
);
```

### Statut de Compte

**Règles** :

- Login → `status = "actif"`
- Logout → `status = "inactif"`
- 180 jours sans connexion → Compte bloqué

**Vérification à chaque login** :

```javascript
const daysSinceLastConnection =
  (Date.now() - user.derniere_connexion) / (1000 * 60 * 60 * 24);

if (daysSinceLastConnection > 180) {
  return res.status(403).json({
    message: "Account inactive for 180 days",
  });
}
```

---

## ⚡ Performance

### Backend

**Optimisations** :

- ✅ Index MongoDB sur `email`, `status`, `derniere_connexion`
- ✅ Select password exclu par défaut (`.select('-password')`)
- ✅ Validation côté serveur (Mongoose validators)
- ✅ Compression des réponses (gzip)

**À Implémenter** :

- [ ] Rate limiting (express-rate-limit)
- [ ] Caching (Redis)
- [ ] Pagination pour les listes
- [ ] Clustering Node.js

### Frontend

**Optimisations** :

- ✅ Images optimisées (85% quality, max 800x800)
- ✅ setState ciblé (pas de rebuild complet)
- ✅ Lazy loading des screens
- ✅ Cache des données utilisateur (SharedPreferences)

**À Implémenter** :

- [ ] Image caching (cached_network_image)
- [ ] Infinite scroll
- [ ] Debounce sur recherche
- [ ] Offline mode

### Cloudinary

**Optimisations** :

- ✅ Auto-format (WebP si supporté)
- ✅ Auto-quality
- ✅ CDN global
- ✅ Lazy loading

---

## 🧪 Tests

### Tests Recommandés

**Backend** :

- [ ] Unit tests (Jest) - Controllers
- [ ] Integration tests - API endpoints
- [ ] Security tests - JWT, auth
- [ ] Load tests - Artillery

**Frontend** :

- [ ] Widget tests - Composants UI
- [ ] Integration tests - User flows
- [ ] Golden tests - Visual regression

---

## 📊 Monitoring

### Logs

**Backend** :

```javascript
console.log("[INFO]", message);
console.error("[ERROR]", error);
```

**Frontend** :

```dart
print('[DEBUG] $message');
debugPrint('[ERROR] $error');
```

### Métriques à Suivre

- ⏱️ Temps de réponse API
- 💾 Taille des payloads
- 📊 Taux d'erreur
- 👥 Utilisateurs actifs
- 📸 Uploads réussis/échoués

---

## 🔗 Liens Utiles

- [Guide d'Installation](SETUP.md)
- [Référence API](API_REFERENCE.md)
- [Liste des Fonctionnalités](FEATURES.md)
- [Changelog](CHANGELOG_28-02-2026.md)

---

**Dernière mise à jour** : 28 Février 2026
