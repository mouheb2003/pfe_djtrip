# Configuration rapide Google & Facebook OAuth

## ✅ État actuel

L'application est maintenant configurée avec les plugins Google et Facebook. Les configurations Android ont été ajoutées :

### Fichiers modifiés

- ✅ `AndroidManifest.xml` - Permissions et configuration ajoutées
- ✅ `strings.xml` - Valeurs Facebook ajoutées (TEMPORAIRES - à remplacer)
- ✅ Plugins installés et fonctionnels

### Erreurs actuelles

- ❌ Erreurs Facebook visibles dans les logs : **NORMAL** - L'App ID est temporaire
- ✅ Google Sign-In : Prêt avec configuration minimale

---

## 🔑 Obtenir les vraies clés

### 1. Facebook App ID (REQUIS pour Facebook Login)

#### Créer une application Facebook :

1. Aller sur https://developers.facebook.com/
2. Cliquer sur "Mes applications" → "Créer une application"
3. Choisir "Consommateur" ou "Aucun" comme type
4. Donner un nom à votre app : **Travelo**
5. Cliquer sur "Créer une app"

#### Récupérer l'App ID et le Client Token :

1. Dans le tableau de bord → **Paramètres** → **Général**
2. Copier :
   - **Identifiant de l'app** (App ID)
   - **Clé secrète de l'app** (App Secret)
   - **Jeton client** (Client Token)

#### Configurer Facebook Login :

1. Dans le menu gauche → **Ajouter des produits**
2. Chercher **Facebook Login** et cliquer sur **Configurer**
3. Choisir **Android**
4. Suivre les étapes :
   - Package name : `com.djtrip.app`
   - Classe d'activité par défaut : `com.djtrip.app.MainActivity`
   - Hash des clés : Obtenir avec la commande ci-dessous

#### Obtenir le Key Hash (Facebook) :

```powershell
cd C:\Users\ASUS\.android
keytool -exportcert -alias androiddebugkey -keystore debug.keystore -storepass android | openssl sha1 -binary | openssl base64
```

**Note** : Si `openssl` n'est pas disponible, utiliser Git Bash ou installer OpenSSL pour Windows.

#### Mettre à jour strings.xml :

```powershell
code C:\Users\ASUS\travelo\FrontFlutter\android\app\src\main\res\values\strings.xml
```

Remplacer les valeurs :

```xml
<string name="facebook_app_id">VOTRE_VRAI_APP_ID</string>
<string name="facebook_client_token">VOTRE_VRAI_CLIENT_TOKEN</string>
<string name="fb_login_protocol_scheme">fbVOTRE_VRAI_APP_ID</string>
```

#### Activer l'application en mode Live :

1. Dans Facebook Developer Console
2. Aller dans **Paramètres de l'app** → **Général**
3. En haut : Basculer de "Développement" à **"En ligne"** (Live)
4. Confirmer

---

### 2. Google Sign-In Configuration (REQUIS pour Google Login)

#### Créer un projet Google Cloud :

1. Aller sur https://console.cloud.google.com/
2. Créer un nouveau projet : **Travelo**
3. Sélectionner le projet

#### Activer Google Sign-In API :

1. Aller dans **APIs & Services** → **Library**
2. Chercher "Google Sign-In API" ou "Google Identity"
3. Cliquer sur **Enable** (Activer)

#### Créer des identifiants OAuth 2.0 pour Android :

1. Aller dans **APIs & Services** → **Credentials** (Identifiants)
2. Cliquer sur **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Si demandé, configurer l'écran de consentement OAuth :
   - Type : **Externe**
   - Nom de l'application : **Travelo**
   - Email d'assistance : Votre email
   - Ajouter les scopes : `email`, `profile`
   - Sauvegarder
4. Retourner à **Credentials** → **+ CREATE CREDENTIALS** → **OAuth client ID**
5. Sélectionner **Android**
6. Remplir :
   - Name : `Travelo Android`
   - Package name : `com.djtrip.app`
   - SHA-1 certificate fingerprint : Obtenir avec la commande ci-dessous

#### Obtenir le SHA-1 Certificate Fingerprint :

```powershell
cd C:\Users\ASUS\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Chercher la ligne qui commence par `SHA1:` et copier la valeur (format : `AA:BB:CC:...`).

#### Optionnel - Créer un Web Client ID (pour le backend) :

1. **+ CREATE CREDENTIALS** → **OAuth client ID**
2. Sélectionner **Application web**
3. Name : `Travelo Backend`
4. Sauvegarder et copier le **Client ID** (commence par `xxx.apps.googleusercontent.com`)

**Important** : Aucune modification de code n'est nécessaire côté Flutter. Le plugin `google_sign_in` récupère automatiquement le Client ID depuis Google Cloud Console en utilisant le package name et le SHA-1.

---

## 🔄 Après avoir configuré les vraies clés

### Pour tester Facebook Login :

1. Mettre à jour `strings.xml` avec le vrai App ID
2. Arrêter l'app en cours : Appuyer sur `q` dans le terminal
3. Reconstruire :

```powershell
cd C:\Users\ASUS\travelo\FrontFlutter
flutter clean
flutter run
```

### Pour tester Google Sign-In :

- Aucune modification de code nécessaire
- Les identifiants sont automatiquement récupérés depuis Google Cloud Console
- Assurez-vous que le SHA-1 est correct et que l'API est activée

---

## 🧪 Tester l'authentification

### Test sur émulateur Android :

1. **Google Sign-In** :
   - Fonctionne immédiatement si le SHA-1 est configuré
   - L'émulateur doit avoir un compte Google ajouté
   - Paramètres → Comptes → Ajouter un compte

2. **Facebook Login** :
   - Nécessite l'App ID réel
   - L'app Facebook doit être en mode "Live" (En ligne)
   - Peut demander d'installer l'app Facebook ou utiliser le navigateur

### Test sur appareil réel :

- Même chose que l'émulateur
- Pour le release build, créer un nouveau SHA-1 avec le release keystore

---

## 🛠️ Troubleshooting

### Google Sign-In : "Developer Error" ou "Sign in failed"

**Causes** :

- SHA-1 incorrect ou manquant dans Google Cloud Console
- Package name incorrect (`com.djtrip.app`)
- Google Sign-In API non activée

**Solution** :

1. Vérifier le SHA-1 :
   ```powershell
   keytool -list -v -keystore C:\Users\ASUS\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android | findstr SHA1
   ```
2. Aller dans Google Cloud Console → Credentials
3. Vérifier que le SHA-1 et le package name correspondent
4. Attendre 5-10 minutes pour la propagation
5. Rebuild l'app :
   ```powershell
   flutter clean
   flutter run
   ```

### Facebook Login : Erreurs OAuth ou validation

**Erreurs actuelles** :

```
E/com.facebook.GraphResponse: {HttpStatus: 400, errorCode: 190, errorMessage: Error validating application}
```

**Causes** :

- App ID temporaire/invalide dans `strings.xml`
- L'application n'est pas en mode "Live"
- Key Hash manquant dans Facebook Console

**Solution** :

1. Remplacer les valeurs dans `strings.xml` avec le vrai App ID
2. Activer l'app en mode "Live" dans Facebook Developer Console
3. Ajouter le Key Hash dans Facebook Console :
   - Paramètres → Général → Key Hashes (Android)
4. Rebuild l'app

### Les deux : "No implementation found" ou "PlatformException"

**Cause** : Plugins non correctement installés après ajout

**Solution** :

```powershell
cd C:\Users\ASUS\travelo\FrontFlutter
flutter clean
flutter pub get
cd android
.\gradlew clean
cd ..
flutter run
```

---

## 📝 Résumé des étapes minimales

Pour que tout fonctionne immédiatement :

### Facebook (5 minutes) :

1. Créer app sur https://developers.facebook.com/
2. Copier App ID, Client Token
3. Mettre à jour `strings.xml`
4. Activer en mode "Live"
5. Rebuild l'app

### Google (3 minutes) :

1. Créer projet sur https://console.cloud.google.com/
2. Activer Google Sign-In API
3. Créer OAuth Client ID (Android) avec package name + SHA-1
4. Attendre 5 min
5. L'app est prête, aucun code à changer !

---

**Date** : March 5, 2026
**Status** : Configuration de base terminée, prêt pour les vraies clés

# Travelo - Application de Voyage

Application mobile Flutter pour la réservation et la découverte de destinations touristiques, avec authentification via email, Google et Facebook.

## 📱 Fonctionnalités

- ✅ Authentification classique (email/mot de passe)
- ✅ Connexion avec Google (Google Sign-In)
- ✅ Connexion avec Facebook (Facebook Login)
- ✅ Gestion des profils utilisateurs (Touriste & Organisateur)
- ✅ Upload d'images
- ✅ Interface moderne et responsive

## 🚀 Installation et Configuration

### Prérequis

- Flutter SDK ≥ 3.11.0
- Android Studio / VS Code
- JDK 21
- Un compte Google Cloud (pour Google Sign-In)
- Un compte Facebook Developer (pour Facebook Login)

### Installation des dépendances

```bash
cd FrontFlutter
flutter pub get
```

---

## 🔑 Configuration de l'Authentification OAuth

### Qu'est-ce qu'un App ID / Client ID ?

**App ID** (Facebook) et **Client ID** (Google) sont des identifiants uniques qui permettent à votre application de communiquer avec les serveurs d'authentification de Facebook et Google.

#### Comment ça fonctionne ?

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Votre     │         │   Facebook   │         │  Backend    │
│   App       │────────▶│   /Google    │────────▶│  Travelo    │
│  (Flutter)  │  Token  │   Servers    │  Token  │   (API)     │
└─────────────┘         └──────────────┘         └─────────────┘
```

1. **L'utilisateur clique sur "Connexion avec Facebook/Google"**
2. **Votre App ID est envoyé** aux serveurs Facebook/Google
3. **L'utilisateur s'authentifie** dans le navigateur ou l'app native
4. **Un token d'accès est généré** et retourné à votre app
5. **Votre app envoie ce token** à votre backend
6. **Le backend vérifie le token** et crée/connecte l'utilisateur

**Pourquoi c'est obligatoire ?**

- Sécurité : Identifie votre app de manière unique
- Contrôle : Facebook/Google peuvent désactiver votre app si nécessaire
- Analytics : Permet de suivre l'utilisation de votre app

---

## 📘 Configuration Facebook Login

### Étape 1 : Créer une Application Facebook

1. **Aller sur** : https://developers.facebook.com/
2. **Se connecter** avec votre compte Facebook
3. Cliquer sur **"Mes applications"** → **"Créer une application"**
4. Choisir le type : **"Consommateur"** (pour les apps grand public)
5. Remplir les informations :
   - **Nom de l'app** : `Travelo` (ou votre choix)
   - **Email de contact** : Votre email
   - Cliquer sur **"Créer une app"**

### Étape 2 : Récupérer l'App ID et le Client Token

1. Dans le tableau de bord de votre app
2. Aller dans **"Paramètres"** → **"Général"** (menu de gauche)
3. Vous verrez :
   - **Identifiant de l'app** : `123456789012345` ← C'est votre **APP ID**
   - **Clé secrète de l'app** : `abc123...` ← NE PAS PARTAGER
4. Faire défiler jusqu'à **"Jeton client"** (Client Token)
   - Copier ce jeton : `def456...`

### Étape 3 : Configurer Facebook Login pour Android

1. Dans le menu gauche, cliquer sur **"Ajouter des produits"**
2. Chercher **"Facebook Login"** → Cliquer sur **"Configurer"**
3. Choisir la plateforme **"Android"**
4. Remplir les informations :
   - **Package name** : `com.djtrip.app`
   - **Classe d'activité par défaut** : `com.djtrip.app.MainActivity`
5. **Ajouter le Key Hash** :

#### Obtenir votre Key Hash (Windows PowerShell) :

```powershell
# Si vous avez OpenSSL installé :
cd C:\Users\ASUS\.android
keytool -exportcert -alias androiddebugkey -keystore debug.keystore -storepass android | openssl sha1 -binary | openssl base64
```

**Alternative sans OpenSSL** :

```powershell
# 1. Exporter le certificat
cd C:\Users\ASUS\.android
keytool -exportcert -alias androiddebugkey -keystore debug.keystore -storepass android -file cert.cer

# 2. Aller sur un site web comme https://tomeko.net/online_tools/hex_to_base64.php
# 3. Convertir cert.cer en base64
# 4. Copier le résultat dans Facebook Console
```

6. Copier le Key Hash dans Facebook Console → **"Key Hashes"**
7. Cliquer sur **"Enregistrer"**

### Étape 4 : Activer l'App en mode "Live" (Production)

⚠️ **IMPORTANT** : Par défaut, votre app est en mode "Développement"

1. En haut à droite du tableau de bord
2. Vous verrez un switch : **"En développement"**
3. Cliquer sur le switch pour passer en **"En ligne"** (Live)
4. Confirmer le passage en production

**Pourquoi ?** : En mode développement, seuls les testeurs ajoutés peuvent se connecter.

### Étape 5 : Mettre à jour les valeurs dans votre code

**Fichier à modifier** : `android/app/src/main/res/values/strings.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Travelo</string>

    <!-- REMPLACER CES VALEURS ↓ -->
    <string name="facebook_app_id">1234567890123456</string>
    <string name="facebook_client_token">abc123def456ghi789</string>
    <string name="fb_login_protocol_scheme">fb1234567890123456</string>
    <!-- ↑ fb + votre App ID -->
</resources>
```

**Exemple avec de vraies valeurs** :

```xml
<!-- Si votre App ID est : 987654321098765 -->
<string name="facebook_app_id">987654321098765</string>

<!-- Si votre Client Token est : abcXYZ123... -->
<string name="facebook_client_token">abcXYZ123456def789ghi</string>

<!-- Le protocol scheme : fb + App ID -->
<string name="fb_login_protocol_scheme">fb987654321098765</string>
```

### Étape 6 : Tester

```bash
# Nettoyer et reconstruire l'app
flutter clean
flutter run
```

**Les erreurs** `E/com.facebook.GraphResponse: {HttpStatus: 400, errorCode: 190...}` **doivent disparaître !**

---

## 🔎 Configuration Google Sign-In

### Étape 1 : Créer un Projet Google Cloud

1. **Aller sur** : https://console.cloud.google.com/
2. Cliquer sur le sélecteur de projet (en haut)
3. Cliquer sur **"NOUVEAU PROJET"**
4. Remplir :
   - **Nom du projet** : `Travelo`
5. Cliquer sur **"Créer"**
6. Attendre quelques secondes, puis sélectionner votre projet

### Étape 2 : Activer l'API Google Sign-In

1. Dans le menu de gauche : **"APIs & Services"** → **"Library"**
2. Chercher : `Google Sign-In API` ou `Google Identity`
3. Cliquer sur l'API
4. Cliquer sur **"ENABLE"** (Activer)

### Étape 3 : Configurer l'Écran de Consentement OAuth

1. Menu gauche : **"APIs & Services"** → **"OAuth consent screen"**
2. Choisir : **"Externe"** (External)
3. Cliquer sur **"Créer"**
4. Remplir :
   - **Nom de l'application** : `Travelo`
   - **Email d'assistance utilisateur** : Votre email
   - **Logo** : Optionnel
   - **Domaine de l'application** : Laisser vide pour l'instant
   - **Email du développeur** : Votre email
5. Cliquer sur **"Enregistrer et continuer"**
6. **Scopes** : Cliquer sur **"Add or remove scopes"**
   - Sélectionner : `.../auth/userinfo.email`
   - Sélectionner : `.../auth/userinfo.profile`
7. Cliquer sur **"Enregistrer et continuer"**
8. **Utilisateurs de test** : Laisser vide (ou ajouter votre email pour tester)
9. Cliquer sur **"Enregistrer et continuer"**

### Étape 4 : Obtenir le SHA-1 Certificate Fingerprint

**Qu'est-ce que le SHA-1 ?**
Le SHA-1 est une empreinte digitale unique de votre certificat de signature d'app. Google l'utilise pour vérifier que c'est bien votre app qui demande l'authentification.

**Comment l'obtenir ?** (Windows PowerShell)

```powershell
# Pour le debug (développement)
cd C:\Users\ASUS\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Résultat attendu** :

```
Certificate fingerprints:
     MD5:  XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
     SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:11:22:33:44
     SHA256: ...
```

**Copier la valeur après `SHA1:`** : `AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:11:22:33:44`

### Étape 5 : Créer un OAuth Client ID pour Android

1. Menu gauche : **"APIs & Services"** → **"Credentials"** (Identifiants)
2. Cliquer sur **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
3. **Type d'application** : Choisir **"Android"**
4. Remplir :
   - **Name** : `Travelo Android Debug`
   - **Package name** : `com.djtrip.app`
   - **SHA-1 certificate fingerprint** : Coller votre SHA-1 (étape 4)
5. Cliquer sur **"Créer"**

**Résultat** :

```
Client ID créé : 123456789-abcdefgh.apps.googleusercontent.com
```

### Étape 6 : (Optionnel) Créer un Client ID Web pour le Backend

Si votre backend doit vérifier les tokens Google :

1. **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
2. **Type** : **"Application Web"**
3. **Name** : `Travelo Backend`
4. Cliquer sur **"Créer"**
5. Copier le **Client ID** pour votre backend

### Étape 7 : Aucune Modification de Code Nécessaire !

✅ **Bonne nouvelle** : Le plugin `google_sign_in` récupère automatiquement le Client ID !

**Comment ?**

- Il utilise le **package name** (`com.djtrip.app`)
- Et le **certificat de signature** de votre app
- Google Cloud trouve automatiquement le Client ID correspondant

**Donc** : Aucun fichier à modifier dans Flutter ! 🎉

### Étape 8 : Tester

```bash
flutter clean
flutter run
```

**Attendre 5-10 minutes** après la création du Client ID pour que la configuration se propage.

---

## 🐛 Dépannage (Troubleshooting)

### ❌ Facebook : `Error validating application`

**Erreur dans les logs** :

```
E/com.facebook.GraphResponse: {HttpStatus: 400, errorCode: 190, errorMessage: Error validating application}
```

**Causes possibles** :

1. ❌ L'App ID dans `strings.xml` est incorrect ou temporaire
2. ❌ L'App Facebook n'est pas en mode "Live" (En ligne)
3. ❌ Le Key Hash n'est pas configuré dans Facebook Console

**Solutions** :

1. ✅ Vérifier que vous avez remplacé `1234567890123456` par votre vrai App ID
2. ✅ Activer l'app en mode "Live" dans Facebook Developer Console
3. ✅ Ajouter le Key Hash dans Facebook Console → Paramètres → Général
4. ✅ Rebuild l'app : `flutter clean && flutter run`

---

### ❌ Google : `Developer Error` ou `Sign in failed`

**Erreur** : La fenêtre Google Sign-In se ferme sans se connecter

**Causes possibles** :

1. ❌ Le SHA-1 n'est pas configuré dans Google Cloud Console
2. ❌ Le package name est incorrect
3. ❌ L'API Google Sign-In n'est pas activée
4. ⏰ Configuration pas encore propagée (attendre 5-10 minutes)

**Solutions** :

1. ✅ Vérifier le SHA-1 :
   ```powershell
   keytool -list -v -keystore C:\Users\ASUS\.android\debug.keystore -alias androiddebugkey -storepass android | findstr SHA1
   ```
2. ✅ Comparer avec le SHA-1 dans Google Console → Credentials
3. ✅ Vérifier le package name : `com.djtrip.app`
4. ✅ Vérifier que l'API est activée : Google Console → APIs & Services → Library
5. ⏰ Attendre 10 minutes après la configuration
6. ✅ Rebuild : `flutter clean && flutter run`

---

### ❌ `PlatformException` ou `MissingPluginException`

**Erreur** : `No implementation found for method...`

**Cause** : Les plugins natifs ne sont pas correctement initialisés

**Solution** :

```bash
cd FrontFlutter
flutter clean
flutter pub get
cd android
.\gradlew clean
cd ..
flutter run
```

---

## 📁 Structure du Projet

```
FrontFlutter/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── new_login_screen.dart      # Écran de connexion
│   │   │   └── new_signup_screen.dart     # Écran d'inscription
│   │   └── ...
│   ├── services/
│   │   ├── auth_service.dart              # Service d'authentification
│   │   └── ...
│   └── models/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml    # ✏️ Configuration OAuth
│               └── res/
│                   └── values/
│                       └── strings.xml    # ✏️ App IDs Facebook
└── pubspec.yaml                           # Dépendances Flutter
```

---

## 🔐 Sécurité

### ⚠️ À NE JAMAIS PARTAGER :

- ❌ **Facebook App Secret** (Clé secrète de l'app)
- ❌ **Facebook Client Token** (sauf dans le code Android - OK)
- ❌ **Keystores de production** (.jks, .keystore)
- ❌ **Tokens d'accès utilisateurs**

### ✅ Peut être partagé publiquement :

- ✅ Facebook App ID (présent dans l'app)
- ✅ Google Client ID (présent dans l'app)
- ✅ SHA-1 debug certificate (pour le développement)

---

## 📞 Support

Pour plus d'informations détaillées :

- 📖 [QUICK_OAUTH_SETUP.md](../documentation/QUICK_OAUTH_SETUP.md)
- 📖 [GOOGLE_FACEBOOK_AUTH_SETUP.md](../documentation/GOOGLE_FACEBOOK_AUTH_SETUP.md)

**Documentation officielle** :

- [Facebook Login pour Android](https://developers.facebook.com/docs/facebook-login/android)
- [Google Sign-In pour Android](https://developers.google.com/identity/sign-in/android/start)
- [Flutter google_sign_in](https://pub.dev/packages/google_sign_in)
- [Flutter flutter_facebook_auth](https://pub.dev/packages/flutter_facebook_auth)

---

## 📝 Commandes Utiles

```bash
# Installer les dépendances
flutter pub get

# Nettoyer le projet
flutter clean

# Lancer l'app en mode debug
flutter run

# Lancer l'app en mode release
flutter run --release

# Voir les appareils connectés
flutter devices

# Voir les logs
flutter logs

# Construire l'APK
flutter build apk

# Construire l'App Bundle (pour Google Play)
flutter build appbundle
```

---

## 📄 Licence

Ce projet est privé et destiné à un usage interne.

---

**Date de dernière mise à jour** : 5 Mars 2026
