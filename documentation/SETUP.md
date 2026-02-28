# 🚀 Guide d'Installation - Travelo

Guide complet pour installer et configurer le projet Travelo sur votre machine.

---

## 📋 Prérequis

### Logiciels Requis

#### Node.js & NPM

- **Version** : Node.js 16.x ou supérieur
- **Installation** : [nodejs.org](https://nodejs.org/)
- **Vérification** :

```powershell
node --version  # v16.0.0 ou supérieur
npm --version   # 8.0.0 ou supérieur
```

#### MongoDB

- **Version** : MongoDB 5.x ou supérieur
- **Options** :
  - **Local** : [mongodb.com/try/download/community](https://www.mongodb.com/try/download/community)
  - **Cloud** : [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) (gratuit)
- **Vérification** :

```powershell
mongo --version  # v5.0.0 ou supérieur
```

#### Flutter SDK

- **Version** : Flutter 3.x ou supérieur
- **Installation** : [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- **Vérification** :

```powershell
flutter --version  # Flutter 3.x.x
flutter doctor     # Vérifie la configuration complète
```

#### Android Studio (pour développement Android)

- **Version** : 2022.1 ou supérieur
- **Installation** : [developer.android.com/studio](https://developer.android.com/studio)
- **SDK Android** : API Level 21 ou supérieur
- **Émulateur** : AVD Manager configuré

#### Visual Studio Code (recommandé)

- **Extensions** :
  - Flutter
  - Dart
  - MongoDB for VS Code
  - Thunder Client (pour tester les API)

---

## 🔧 Installation

### 1. Cloner le Projet

```powershell
# Cloner le repository
git clone <votre-repo-url>
cd travelo
```

### 2. Configuration Backend

#### Installer les Dépendances

```powershell
cd Back/pfe_backend-main
npm install
```

#### Créer le Fichier .env

Créer un fichier `.env` à la racine de `Back/pfe_backend-main/` :

```env
# Port du serveur
PORT=3000

# URI MongoDB
MONGODB_URI=mongodb://localhost:27017/travelo
# OU pour MongoDB Atlas :
# MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/travelo

# JWT Secrets
JWT_SECRET=votre_jwt_secret_super_securise_changez_moi
JWT_REFRESH_SECRET=votre_refresh_secret_super_securise_changez_moi

# JWT Expiration
JWT_EXPIRATION=15m
JWT_REFRESH_EXPIRATION=7d

# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=dx5bpwemu
CLOUDINARY_API_KEY=votre_api_key
CLOUDINARY_API_SECRET=votre_api_secret

# CORS Origins (développement)
CORS_ORIGINS=*
```

⚠️ **IMPORTANT** :

- Changez les valeurs des secrets JWT
- Configurez vos credentials Cloudinary
- En production, spécifiez les origins CORS exactes

#### Démarrer MongoDB (si local)

```powershell
# Démarrer le service MongoDB
mongod
```

#### Démarrer le Serveur Backend

```powershell
# Toujours dans Back/pfe_backend-main/
node server.js
```

**Output attendu** :

```
Server is running on port 3000
Connexion à MongoDB réussie !
```

### 3. Configuration Frontend Flutter

#### Installer les Dépendances

```powershell
# Retour à la racine du projet
cd ../../FrontFlutter

# Installer les dépendances
flutter pub get
```

#### Configurer l'Adresse IP Backend

**IMPORTANT** : Pour tester sur un appareil physique, vous devez utiliser l'IP locale de votre machine (pas localhost).

1. **Obtenir votre IP locale** :

```powershell
# Windows
ipconfig  # Cherchez IPv4 dans Wi-Fi ou Ethernet
```

2. **Mettre à jour l'API Config** :

Ouvrir [lib/config/api_config.dart](../FrontFlutter/lib/config/api_config.dart) et modifier :

```dart
class ApiConfig {
  // REMPLACEZ 192.168.3.12 par VOTRE IP locale
  static const String baseUrl = 'http://192.168.3.12:3000';

  // Exemple avec votre IP :
  // static const String baseUrl = 'http://192.168.1.105:3000';

  // Pour émulateur Android (ne fonctionne PAS sur appareil physique) :
  // static const String baseUrl = 'http://10.0.2.2:3000';

  // Pour émulateur iOS :
  // static const String baseUrl = 'http://localhost:3000';
}
```

#### Vérifier les Permissions Android

Le fichier [android/app/src/main/AndroidManifest.xml](../FrontFlutter/android/app/src/main/AndroidManifest.xml) doit contenir :

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions Internet -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <!-- Permissions Caméra -->
    <uses-permission android:name="android.permission.CAMERA"/>

    <!-- Permissions Stockage -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

    <application>
        <!-- ... -->
    </application>
</manifest>
```

#### Démarrer l'Application Flutter

**Option A : Émulateur Android**

```powershell
# Lancer un émulateur
flutter emulators --launch <emulator_id>

# Lancer l'app
flutter run
```

**Option B : Appareil Physique Android**

```powershell
# Vérifier que l'appareil est connecté
flutter devices

# Lancer l'app
flutter run
```

**Option C : Mode Debug avec Hot Reload**

```powershell
# Lancer en mode debug
flutter run --debug

# Dans le terminal :
# R -> Hot Restart
# r -> Hot Reload
# q -> Quit
```

---

## 🔍 Vérification de l'Installation

### Backend

#### Test de Connexion

```powershell
# Test simple de l'API
curl http://localhost:3000
# OU
Invoke-WebRequest -Uri http://localhost:3000 -Method GET
```

#### Test d'Inscription

Utiliser Thunder Client, Postman ou curl :

```json
POST http://localhost:3000/users/signup
Content-Type: application/json

{
  "email": "test@example.com",
  "password": "Test123!",
  "nom_complet": "Test User",
  "userType": "Touriste"
}
```

**Réponse attendue** : Status 201 avec token et user

### Frontend

#### Checklist de Vérification

- [ ] L'app démarre sans erreur
- [ ] L'écran Splash s'affiche
- [ ] Redirection vers Login
- [ ] Inscription fonctionne
- [ ] Connexion fonctionne
- [ ] Navigation entre onglets fonctionne
- [ ] Profil affiche les données
- [ ] Édition de profil fonctionne
- [ ] Upload de photo fonctionne (caméra/galerie)
- [ ] Sélecteurs pays/langue fonctionnent
- [ ] Déconnexion fonctionne

---

## 🌐 Configuration Réseau

### Firewall Windows

Si vous ne pouvez pas accéder au backend depuis l'appareil physique :

```powershell
# Autoriser le port 3000
New-NetFirewallRule -DisplayName "Node Server 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### Même Réseau Wi-Fi

⚠️ **Assurez-vous que** :

- L'ordinateur ET l'appareil sont sur le même réseau Wi-Fi
- Le réseau n'est pas en "isolation AP" (mode public)
- Votre IP n'a pas changé (DHCP)

### Test de Connectivité

Depuis le navigateur de votre téléphone :

```
http://192.168.3.12:3000
```

Vous devriez voir une réponse

---

## 🐛 Résolution de Problèmes

### Backend ne démarre pas

**Problème** : `Error: Cannot find module 'express'`

```powershell
# Solution
cd Back/pfe_backend-main
npm install
```

**Problème** : `MongoNetworkError: connect ECONNREFUSED`

```powershell
# Solution 1: Démarrer MongoDB
mongod

# Solution 2: Vérifier l'URI dans .env
# Assurez-vous que MONGODB_URI est correct
```

**Problème** : `Error: Port 3000 already in use`

```powershell
# Solution 1: Tuer le processus sur le port 3000
Get-Process -Id (Get-NetTCPConnection -LocalPort 3000).OwningProcess | Stop-Process -Force

# Solution 2: Changer le port dans .env
PORT=3001
```

### Flutter ne démarre pas

**Problème** : `Waiting for another flutter command to release the startup lock...`

```powershell
# Solution
rm $env:LOCALAPPDATA\flutter\.flutter_lock
# OU
flutter clean
flutter pub get
```

**Problème** : `Target of URI doesn't exist: 'package:image_picker/image_picker.dart'`

```powershell
# Solution
flutter clean
flutter pub get
flutter pub upgrade
```

**Problème** : `Gradle build failed`

```powershell
# Solution
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Connexion Backend Échoue

**Problème** : `SocketException: OS Error: Connection refused`

Solutions :

1. Vérifier que le backend est démarré
2. Vérifier l'IP dans [api_config.dart](../FrontFlutter/lib/config/api_config.dart)
3. Vérifier le même réseau Wi-Fi
4. Désactiver temporairement le firewall
5. Utiliser l'IP locale, pas localhost :

```powershell
ipconfig  # Obtenir l'IPv4
```

**Problème** : `HandshakeException: Handshake error`

- Assurez-vous d'utiliser `http://` et non `https://` en développement

### Upload d'Image Échoue

**Problème** : `Cloudinary upload failed`

Solutions :

1. Vérifier les credentials dans `.env`
2. Vérifier la connexion Internet
3. Vérifier les logs backend
4. Tester avec un petit fichier (<1MB)

**Problème** : `PlatformException: Permission denied`

```powershell
# Solution Android
# Désinstaller l'app et réinstaller pour demander à nouveau les permissions
flutter clean
flutter run
```

---

## 📱 Configuration Appareil Physique

### Android

#### 1. Activer le Mode Développeur

- Paramètres → À propos du téléphone
- Taper 7 fois sur "Numéro de build"

#### 2. Activer le Débogage USB

- Paramètres → Options développeur
- Activer "Débogage USB"

#### 3. Connecter via USB

```powershell
# Vérifier la connexion
flutter devices

# Autoriser sur le téléphone si demandé
```

#### 4. Configuration ADB (si problèmes)

```powershell
# Redémarrer ADB
adb kill-server
adb start-server
adb devices
```

### iOS (si disponible)

#### 1. Configuration Xcode

- Ouvrir `ios/Runner.xcworkspace` dans Xcode
- Sélectionner "Runner" → Signing & Capabilities
- Choisir votre Apple ID

#### 2. Déploiement

```powershell
flutter run -d <device-id>
```

---

## 🔒 Configuration Cloudinary

### 1. Créer un Compte Gratuit

- Aller sur [cloudinary.com](https://cloudinary.com/)
- S'inscrire gratuitement

### 2. Obtenir les Credentials

- Dashboard → Account Details
- Copier :
  - Cloud Name
  - API Key
  - API Secret

### 3. Mettre à Jour .env

```env
CLOUDINARY_CLOUD_NAME=votre_cloud_name
CLOUDINARY_API_KEY=votre_api_key
CLOUDINARY_API_SECRET=votre_api_secret
```

### 4. Configuration Avancée (Optionnel)

Dans [Back/pfe_backend-main/config/cloudinary.js](../Back/pfe_backend-main/config/cloudinary.js) :

```javascript
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true, // HTTPS
});
```

---

## 🚀 Commandes Utiles

### Backend

```powershell
# Développement
cd Back/pfe_backend-main
node server.js

# Avec Nodemon (auto-restart)
npm install -g nodemon
nodemon server.js

# Vérifier les dépendances
npm list

# Mettre à jour les dépendances
npm update
```

### Frontend

```powershell
cd FrontFlutter

# Installer les dépendances
flutter pub get

# Mettre à jour les dépendances
flutter pub upgrade

# Nettoyer le cache
flutter clean

# Analyser le code
flutter analyze

# Formater le code
flutter format .

# Lancer l'app
flutter run

# Build APK
flutter build apk --release

# Build APK optimisé (plus petit)
flutter build apk --split-per-abi

# Lister les appareils
flutter devices

# Voir les logs
flutter logs
```

### MongoDB

```powershell
# Démarrer MongoDB
mongod

# Connecter au shell
mongo

# Dans le shell MongoDB :
use travelo              # Sélectionner la base
db.users.find()          # Voir les utilisateurs
db.users.countDocuments()  # Compter
db.dropDatabase()        # ATTENTION: Supprimer la base
```

---

## 📊 Structure des Données MongoDB

### Collection: users

```javascript
{
  _id: ObjectId("..."),
  email: "user@example.com",
  password: "$2b$10$...", // Hash bcrypt
  nom_complet: "John Doe",
  userType: "Touriste",  // ou "Organisator"

  // Profil
  age: 25,
  telephone: "+212600000000",
  pays: "Maroc",
  langue_preferee: "Français",  // Seulement Touriste
  bio: "Passionné de voyages...",
  avatar: "https://res.cloudinary.com/.../image.jpg",

  // Préférences
  centres_interet: ["Plages", "Aventure", "Culture"],

  // Notifications
  accept_notifications_email: true,
  accept_notifications_sms: false,

  // État
  status: "actif",  // ou "inactif"
  derniere_connexion: ISODate("2026-02-28T10:30:00Z"),

  // Timestamps
  createdAt: ISODate("2026-01-01T00:00:00Z"),
  updatedAt: ISODate("2026-02-28T10:30:00Z")
}
```

---

## 🎯 Prochaines Étapes

Après l'installation réussie :

1. **Créer un compte** de test (Touriste et Organisator)
2. **Compléter l'onboarding** (3 étapes)
3. **Tester l'upload** de photo
4. **Configurer les préférences**
5. **Partager votre profil**
6. **Consulter la documentation** :
   - [README.md](README.md) - Vue d'ensemble
   - [FEATURES.md](FEATURES.md) - Liste des fonctionnalités
   - [CHANGELOG_28-02-2026.md](CHANGELOG_28-02-2026.md) - Derniers changements

---

## 📞 Support

### Problèmes Courants

Consultez la section "Résolution de Problèmes" ci-dessus

### Logs

```powershell
# Backend logs
# Voir la console où node server.js tourne

# Flutter logs
flutter logs

# Android logs
adb logcat
```

### Documentation Officielle

- [Flutter Docs](https://docs.flutter.dev/)
- [Express.js Docs](https://expressjs.com/)
- [MongoDB Docs](https://docs.mongodb.com/)
- [Cloudinary Docs](https://cloudinary.com/documentation)

---

**Installation complétée avec succès** ? Consultez [FEATURES.md](FEATURES.md) pour découvrir toutes les fonctionnalités disponibles !

**Dernière mise à jour** : 28 Février 2026
