# Configuration Facebook Login pour DJTrip

## 📝 Guide de configuration étape par étape

### 1. Créer une application Facebook

1. Allez sur [Facebook Developers](https://developers.facebook.com/)
2. Connectez-vous avec votre compte Facebook
3. Cliquez sur **"Mes apps"** → **"Créer une app"**
4. Choisissez le type : **"Grand public"** ou **"Entreprise"**
5. Remplissez les informations :
   - **Nom de l'app** : `DJTrip`
   - **Email de contact** : Votre email
   - **Objectif de l'app** : Authentification et connexion
6. Cliquez sur **"Créer l'app"**

### 2. Activer Facebook Login

1. Dans le tableau de bord de votre app
2. Cliquez sur **"Ajouter un produit"**
3. Trouvez **"Facebook Login"** et cliquez sur **"Configurer"**
4. Sélectionnez la plateforme :
   - ✅ **Android**
   - ✅ **iOS** (si nécessaire)

### 3. Configuration Android

#### A. Récupérer l'App ID et Client Token

1. Dans le tableau de bord, allez dans **"Paramètres" → "Général"**
2. Copiez l'**App ID** (Identifiant de l'app)
3. Allez dans **"Paramètres" → "Avancé"**
4. Copiez le **Client Token** (Token client)

#### B. Mettre à jour les fichiers Android

Ouvrez le fichier : `Front/android/app/src/main/res/values/strings.xml`

```xml
<resources>
    <string name="app_name">DJTrip</string>

    <!-- Remplacez VOTRE_FACEBOOK_APP_ID par votre vrai App ID -->
    <string name="facebook_app_id">123456789012345</string>

    <!-- Remplacez VOTRE_FACEBOOK_CLIENT_TOKEN par votre vrai Client Token -->
    <string name="facebook_client_token">1234567890abcdef1234567890abcdef</string>

    <!-- Remplacez dans fb:// aussi -->
    <string name="fb_login_protocol_scheme">fb123456789012345</string>
</resources>
```

#### C. Générer le Hash Key Android

Le Hash Key est nécessaire pour la sécurité.

**Sur Windows (PowerShell)** :

```powershell
# Si vous avez Java/keytool installé
keytool -exportcert -alias androiddebugkey -keystore "C:\Users\VOTRE_NOM\.android\debug.keystore" | openssl sha1 -binary | openssl base64

# Mot de passe par défaut : android
```

**Sur Windows avec Git Bash** :

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

**Sur macOS/Linux** :

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

#### D. Configurer dans Facebook Developers

1. Dans Facebook Developers, allez dans **"Facebook Login" → "Paramètres"**
2. Ajoutez les **Redirect URIs** :

   ```
   fbVOTRE_APP_ID://authorize
   ```

   Exemple : `fb123456789012345://authorize`

3. Dans **"Paramètres"** → **Android** :
   - **Package Name** : `com.djtrip.app` (ou votre package)
   - **Nom de la classe** : `MainActivity`
   - **Hash Key** : Collez le hash généré à l'étape C

### 4. Configuration iOS (si nécessaire)

#### A. Mettre à jour Info.plist

Le fichier `Front/ios/Runner/Info.plist` :

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fbVOTRE_FACEBOOK_APP_ID</string>
    </array>
  </dict>
</array>

<key>FacebookAppID</key>
<string>VOTRE_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>VOTRE_FACEBOOK_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>DJTrip</string>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>fbapi</string>
  <string>fb-messenger-share-api</string>
  <string>fbauth2</string>
  <string>fbshareextension</string>
</array>
```

#### B. Configurer dans Facebook Developers

1. Dans **"Paramètres"** → **iOS** :
   - **Bundle ID** : Votre Bundle ID iOS (ex: `com.djtrip.app`)
   - Activez **"Single Sign On"**

### 5. Paramètres de confidentialité

1. Dans **"Paramètres" → "Général"**
2. Ajoutez une **URL de politique de confidentialité**
3. Ajoutez une **URL de conditions d'utilisation**
4. Complétez les **informations de contact**

### 6. Mode de publication

⚠️ **Important** : Par défaut, votre app est en **Mode développement**

#### Passer en mode Production :

1. Allez dans **"Paramètres" → "Général"**
2. En haut, vous verrez **"Mode de développement"**
3. Complétez tous les champs requis :
   - Catégorie de l'app
   - Politique de confidentialité
   - Icône de l'app (1024x1024px)
4. Cliquez sur le bouton pour **passer en direct**

### 7. Tester la connexion

#### Test en mode développement :

1. Ajoutez des **testeurs** dans **"Rôles" → "Testeurs"**
2. Les testeurs doivent accepter l'invitation via leur email/Facebook
3. Lancez l'app et testez le login Facebook

#### Vérifications :

✅ Le bouton "Se connecter avec Facebook" s'affiche  
✅ Clic sur le bouton ouvre la page de connexion Facebook  
✅ Après connexion, l'utilisateur est redirigé vers l'app  
✅ Les données utilisateur sont récupérées (nom, email)

### 8. Données demandées

Par défaut, Facebook Login donne accès à :

- `public_profile` : Nom, photo de profil, ID
- `email` : Adresse email de l'utilisateur

Dans le code Flutter (`auth_service.dart`), on demande :

```dart
final LoginResult result = await FacebookAuth.instance.login(
  permissions: ['email', 'public_profile'],
);
```

Si vous avez besoin d'autres permissions (ex: `user_birthday`, `user_location`), vous devez :

1. Les demander dans le code
2. Faire une **révision de l'app** sur Facebook Developers

### 9. Résolution des problèmes courants

#### Erreur : "Invalid Key Hash"

- Régénérez le Key Hash avec la bonne commande
- Vérifiez que vous utilisez le bon keystore (debug vs release)
- Ajoutez le hash dans Facebook Developers

#### Erreur : "App Not Setup"

- Vérifiez que l'App ID et Client Token sont corrects
- Vérifiez que Facebook Login est activé
- Redémarrez l'app après modification des fichiers

#### Erreur : "Can't Load URL"

- Vérifiez le `fb_login_protocol_scheme` dans strings.xml
- Vérifiez que l'URL est bien `fbVOTRE_APP_ID://authorize`

#### L'app crash au login

- Vérifiez que toutes les dépendances sont à jour
- Vérifiez AndroidManifest.xml (activités Facebook présentes)
- Nettoyez et rebuilder : `flutter clean && flutter pub get && flutter run`

### 10. Checklist finale

Avant de tester :

- [ ] App ID Facebook correctement configuré dans strings.xml
- [ ] Client Token correctement configuré dans strings.xml
- [ ] fb_login_protocol_scheme configuré avec le bon App ID
- [ ] Hash Key généré et ajouté dans Facebook Developers
- [ ] Package name correct dans Facebook Developers
- [ ] Facebook Login activé pour l'app
- [ ] Testeurs ajoutés (si en mode développement)
- [ ] App rebuilt après les changements (`flutter clean && flutter run`)

---

## 📱 Commandes utiles

### Rebuild l'app après configuration :

```bash
cd Front
flutter clean
flutter pub get
flutter run
```

### Voir les logs Android :

```bash
flutter run --verbose
# ou
adb logcat
```

### Vérifier la configuration Facebook :

```bash
# Dans le terminal Flutter
flutter doctor -v
```

---

## 🔗 Liens utiles

- [Facebook Developers](https://developers.facebook.com/)
- [Documentation Facebook Login](https://developers.facebook.com/docs/facebook-login/)
- [Flutter Facebook Auth Package](https://pub.dev/packages/flutter_facebook_auth)
- [Android Key Hash Generator](https://developers.facebook.com/docs/facebook-login/android#6--provide-the-development-and-release-key-hashes-for-your-app)

---

## 📞 Support

Si vous rencontrez des problèmes :

1. Vérifiez la checklist ci-dessus
2. Consultez les logs de l'app
3. Vérifiez le dashboard Facebook Developers pour les erreurs
4. Testez avec un compte testeur d'abord

---

**Dernière mise à jour** : 7 Mars 2026  
**Version de l'app** : 1.0.0
