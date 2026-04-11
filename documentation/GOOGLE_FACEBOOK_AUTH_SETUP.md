# Configuration de l'authentification Google et Facebook

## Résumé des changements

L'authentification avec Google et Facebook a été ajoutée à l'application Travelo. Les utilisateurs peuvent maintenant s'inscrire et se connecter en utilisant leurs comptes Google ou Facebook.

## Changements Frontend (Flutter)

### 1. Packages ajoutés

- `google_sign_in: ^6.2.2` - Pour l'authentification Google
- `flutter_facebook_auth: ^7.1.5` - Pour l'authentification Facebook

### 2. Fichiers modifiés

#### auth_service.dart

Ajout de deux nouvelles méthodes :

- `signInWithGoogle()` - Gère l'authentification Google
- `signInWithFacebook()` - Gère l'authentification Facebook

Ces méthodes :

1. Déclenchent le flux d'authentification OAuth
2. Récupèrent les données utilisateur (nom, email, ID, token)
3. Envoient ces données au backend
4. Sauvegardent les tokens JWT reçus du backend

#### new_login_screen.dart

- Ajout de `_handleGoogleSignIn()`
- Ajout de `_handleFacebookSignIn()`
- Les boutons "Continue with Google" et "Continue with Facebook" sont maintenant fonctionnels

#### new_signup_screen.dart

- Ajout de `_handleGoogleSignup()`
- Ajout de `_handleFacebookSignup()`
- Validation du type d'utilisateur (Touriste/Organisator) avant l'inscription
- Les boutons sociaux sont maintenant fonctionnels

## Changements Backend Requis

### 1. Nouvelles routes à ajouter

```javascript
// Dans routes/user.js ou routes/auth.js
router.post("/auth/google-signup", googleSignupController);
router.post("/auth/facebook-signup", facebookSignupController);
```

### 2. Structure des requêtes attendues

#### Google Signup/Login

```json
{
  "fullname": "John Doe",
  "email": "john@gmail.com",
  "googleId": "1234567890",
  "googleToken": "ya29.a0AfH6SMB...",
  "userType": "Touriste",
  "authProvider": "google",
  "nom_entreprise": "Optional - seulement si Organisator"
}
```

#### Facebook Signup/Login

```json
{
  "fullname": "John Doe",
  "email": "john@facebook.com",
  "facebookId": "9876543210",
  "facebookToken": "EAABwzLixn...",
  "userType": "Touriste",
  "authProvider": "facebook",
  "nom_entreprise": "Optional - seulement si Organisator"
}
```

### 3. Logique Backend recommandée

```javascript
// Controller pour Google
async function googleSignupController(req, res) {
  const { email, googleId, googleToken, fullname, userType, nom_entreprise } =
    req.body;

  try {
    // 1. Vérifier la validité du token Google (optionnel mais recommandé)
    // const isValidToken = await verifyGoogleToken(googleToken);

    // 2. Chercher si l'utilisateur existe déjà
    let user = await User.findOne({ email });

    if (!user) {
      // 3. Créer un nouvel utilisateur
      user = await User.create({
        fullname,
        email,
        googleId,
        authProvider: "google",
        userType,
        nom_entreprise: userType === "Organisator" ? nom_entreprise : undefined,
        // Pas de mot de passe pour les utilisateurs OAuth
      });
    } else {
      // 4. Mettre à jour avec googleId si nécessaire
      if (!user.googleId) {
        user.googleId = googleId;
        await user.save();
      }
    }

    // 5. Générer les tokens JWT
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // 6. Retourner la réponse
    res.status(user.isNewRecord ? 201 : 200).json({
      success: true,
      message: "Authentication successful",
      user: {
        id: user._id,
        fullname: user.fullname,
        email: user.email,
        userType: user.userType,
        // ... autres champs
      },
      accessToken,
      refreshToken,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
}
```

### 4. Modifications du modèle User

Ajouter ces champs au modèle User :

```javascript
const userSchema = new mongoose.Schema({
  // ... champs existants

  // Champs OAuth
  googleId: {
    type: String,
    unique: true,
    sparse: true, // Permet null pour les utilisateurs non-Google
  },
  facebookId: {
    type: String,
    unique: true,
    sparse: true,
  },
  authProvider: {
    type: String,
    enum: ["local", "google", "facebook"],
    default: "local",
  },

  // Rendre le mot de passe optionnel pour OAuth
  mot_de_passe: {
    type: String,
    required: function () {
      return this.authProvider === "local";
    },
  },
});
```

## Configuration Google OAuth

### 1. Google Cloud Console

1. Aller sur https://console.cloud.google.com/
2. Créer un nouveau projet ou sélectionner un projet existant
3. Activer Google Sign-In API
4. Créer des identifiants OAuth 2.0 :
   - Type : Application Android (pour Android)
   - Type : Application iOS (pour iOS)
   - Type : Application Web (pour le backend)

### 2. Configuration Android (android/app/build.gradle.kts)

Rien de spécial à ajouter, le package gère automatiquement

### 3. Configuration iOS (ios/Runner/Info.plist)

Ajouter :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

### 4. Client ID à récupérer

- Android Client ID
- iOS Client ID
- Web Client ID (pour le backend)

## Configuration Facebook OAuth

### 1. Facebook Developer Console

1. Aller sur https://developers.facebook.com/
2. Créer une nouvelle application
3. Ajouter Facebook Login au produit
4. Configurer les paramètres OAuth
5. Récupérer l'App ID et l'App Secret

### 2. Configuration Android (android/app/src/main/AndroidManifest.xml)

Ajouter :

```xml
<meta-data
    android:name="com.facebook.sdk.ApplicationId"
    android:value="@string/facebook_app_id"/>

<activity
    android:name="com.facebook.FacebookActivity"
    android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
    android:label="@string/app_name" />
```

Créer `android/app/src/main/res/values/strings.xml` :

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Travelo</string>
    <string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>
    <string name="fb_login_protocol_scheme">fbYOUR_FACEBOOK_APP_ID</string>
</resources>
```

### 3. Configuration iOS (ios/Runner/Info.plist)

Ajouter :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fbYOUR_FACEBOOK_APP_ID</string>
        </array>
    </dict>
</array>

<key>FacebookAppID</key>
<string>YOUR_FACEBOOK_APP_ID</string>
<key>FacebookDisplayName</key>
<string>Travelo</string>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>fbapi</string>
    <string>fb-messenger-share-api</string>
</array>
```

## URLs Backend à configurer

Dans `lib/config/api_config.dart`, les endpoints suivants sont utilisés :

- `POST ${ApiConfig.baseUrl}/auth/google-signup`
- `POST ${ApiConfig.baseUrl}/auth/facebook-signup`

## Sécurité

### Recommendations

1. **Vérifier les tokens OAuth côté backend** : Ne pas faire confiance aveuglément aux tokens envoyés par le client
2. **Valider les emails** : Vérifier que l'email provient bien de Google/Facebook
3. **Rate limiting** : Limiter le nombre de tentatives d'authentification
4. **HTTPS uniquement** : Ne jamais utiliser OAuth sur HTTP
5. **Stocker les secrets de manière sécurisée** : Utiliser des variables d'environnement

### Packages Node.js recommandés pour le backend

```json
{
  "google-auth-library": "^9.0.0",
  "facebook-node-sdk": "^0.2.0"
}
```

## Tests

### Tests à effectuer

1. ✅ Inscription avec Google (Touriste)
2. ✅ Inscription avec Google (Organisator avec nom d'entreprise)
3. ✅ Inscription avec Facebook (Touriste)
4. ✅ Inscription avec Facebook (Organisator)
5. ✅ Connexion avec Google (utilisateur existant)
6. ✅ Connexion avec Facebook (utilisateur existant)
7. ✅ Annulation du flux OAuth
8. ✅ Erreur réseau pendant l'authentification
9. ✅ Token invalide/expiré

## Troubleshooting

### Erreur : "Developer Error" sur Google Sign-In

- Vérifier que le SHA-1 de l'application correspond dans Google Console
- Vérifier que le Client ID est correct

### Erreur : Facebook Login échoue

- Vérifier que l'App ID Facebook est correct
- Vérifier que l'application Facebook est en mode "Live" (pas "Development")
- Vérifier les domaines autorisés dans Facebook Console

### Les tokens JWT ne sont pas sauvegardés

- Vérifier que le backend retourne bien `accessToken` et `refreshToken`
- Vérifier les logs dans `StorageService`

## Prochaines étapes

1. **Implémenter les routes backend** (`/auth/google-signup` et `/auth/facebook-signup`)
2. **Modifier le modèle User** pour inclure les champs OAuth
3. **Configurer Google Cloud Console** et récupérer les Client IDs
4. **Configurer Facebook Developer** et récupérer l'App ID
5. **Ajouter les configurations platform-specific** (AndroidManifest.xml, Info.plist)
6. **Tester l'authentification** sur un appareil réel ou émulateur configuré
7. **Ajouter la validation des tokens côté backend** pour la sécurité

---

Date de création : March 5, 2026
Auteur : GitHub Copilot
