# Configuration de Signature Android - DJTrip

## 📋 Informations de Signature

### Empreintes SHA pour le Développement (Debug)

```
Package Name: com.djtrip.app
SHA-1: ED:AC:FB:98:89:64:99:76:5D:3A:94:3A:73:8E:C0:C2:73:CD:B5:4A
SHA-256: 68:A4:33:35:FD:13:03:2F:C0:3D:74:9E:F9:E9:B8:BB:5B:75:9B:2E:67:2C:32:13:48:E2:F3:BA:B1:A4:97:1F
```

**Keystore de Debug:**

- Emplacement: `C:\Users\ASUS\.android\debug.keystore`
- Alias: AndroidDebugKey
- Validité: jusqu'au 19 février 2056

---

## 🔒 Sécurisation des API Google

### 1. Google Maps API

Pour sécuriser votre clé Google Maps API et éviter une utilisation non autorisée:

#### Étape 1: Accéder à Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet
3. Menu: **APIs & Services** > **Credentials**

#### Étape 2: Configurer les restrictions

1. Cliquez sur votre clé API: `AIzaSyDDlkmygDoS11M0VXcEZ9DDIphKWoAOqNA`
2. Dans **Application restrictions**, sélectionnez **Android apps**
3. Cliquez sur **Add an item** et ajoutez:
   ```
   Package name: com.djtrip.app
   SHA-1: ED:AC:FB:98:89:64:99:76:5D:3A:94:3A:73:8E:C0:C2:73:CD:B5:4A
   ```

#### Étape 3: Restreindre les APIs

Dans **API restrictions**, sélectionnez:

- ✅ Maps SDK for Android
- ✅ Geocoding API
- ✅ Places API (si utilisé)

---

### 2. Google Sign-In (OAuth)

Pour configurer l'authentification Google:

#### Étape 1: Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Menu: **APIs & Services** > **Credentials**

#### Étape 2: Créer un identifiant OAuth Android

1. Cliquez sur **Create Credentials** > **OAuth client ID**
2. Sélectionnez **Android**
3. Remplissez:
   ```
   Name: DJTrip Android
   Package name: com.djtrip.app
   SHA-1: ED:AC:FB:98:89:64:99:76:5D:3A:94:3A:73:8E:C0:C2:73:CD:B5:4A
   ```

#### Étape 3: Télécharger le fichier google-services.json

1. Créer un projet Firebase: [Firebase Console](https://console.firebase.google.com/)
2. Ajouter une application Android avec le package `com.djtrip.app`
3. Télécharger `google-services.json`
4. Placer le fichier dans: `Front/android/app/google-services.json`

---

## 🛡️ Production (Release Build)

### ⚠️ Important

Les empreintes SHA ci-dessus sont pour le **keystore de debug uniquement**.

Pour la production, vous devrez:

### 1. Générer un Keystore de Production

```bash
keytool -genkey -v -keystore djtrip-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias djtrip
```

### 2. Obtenir l'empreinte SHA-1 du keystore de production

```bash
keytool -list -v -keystore djtrip-release.jks -alias djtrip
```

### 3. Ajouter l'empreinte de production dans:

- Google Cloud Console (API Keys + OAuth)
- Firebase Console
- Facebook Developer Console

### 4. Configurer signing dans `android/app/build.gradle.kts`

Créer un fichier `android/key.properties`:

```properties
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=djtrip
storeFile=../djtrip-release.jks
```

---

## 📱 Facebook Login

### Configuration Facebook Developer Console

1. Allez sur [Facebook Developers](https://developers.facebook.com/apps/1677963836693965/)
2. Menu: **Settings** > **Basic**
3. Ajoutez les **Key Hashes** (équivalent SHA-1 pour Facebook)

#### Générer le Key Hash pour Facebook:

```bash
# Sur Windows avec PowerShell
cd C:\Users\ASUS\.android
keytool -exportcert -alias AndroidDebugKey -keystore debug.keystore | openssl sha1 -binary | openssl base64
# Mot de passe par défaut: android
```

4. Copiez le résultat dans Facebook Developer Console > **Key Hashes**

---

## 🔄 Régénérer le rapport de signature

Pour obtenir les empreintes SHA à tout moment:

```bash
cd Front/android
./gradlew signingReport
```

---

## 📝 Checklist de Sécurité

### Mode Debug (Développement)

- [x] SHA-1 ajouté dans Google Cloud Console
- [ ] OAuth client ID Android créé
- [ ] google-services.json téléchargé et placé
- [ ] Key Hash ajouté dans Facebook Developer

### Mode Release (Production)

- [ ] Keystore de production généré
- [ ] SHA-1 de production obtenu
- [ ] SHA-1 de production ajouté dans Google Cloud
- [ ] OAuth client ID production créé
- [ ] Key Hash production ajouté dans Facebook
- [ ] Fichier key.properties configuré
- [ ] Signing config dans build.gradle.kts

---

## 🆘 En cas de problème

### Google Sign-In ne fonctionne pas

1. Vérifiez que le SHA-1 est correct dans Google Cloud Console
2. Vérifiez que le package name est exactement `com.djtrip.app`
3. Attendez 5-10 minutes après toute modification dans Google Cloud Console

### Google Maps affiche une carte grise

1. Vérifiez que la clé API est activée
2. Vérifiez que "Maps SDK for Android" est activé dans votre projet
3. Vérifiez que le SHA-1 est ajouté dans les restrictions de la clé

### Facebook Login échoue

1. Vérifiez le Key Hash dans Facebook Developer Console
2. Vérifiez App ID et Client Token dans `strings.xml`
3. Activez "Facebook Login" dans les produits de votre app Facebook

---

**Date de génération:** 8 mars 2026  
**Keystore:** Debug (Développement)  
**Validité:** Jusqu'au 19 février 2056
