# Fix Google Sign-In Error (ApiException: 10)

## 🔴 Error

```
PlatformException(sign_in_failed,
com.google.android.gms.common.api.ApiException: 10: null, null)
```

**Error 10** = `DEVELOPER_ERROR` - Configuration incorrecte

---

## ✅ Solution

### **1. Obtenir vos SHA-1 et SHA-256 Certificate Fingerprints**

#### Option A : Debug Keystore (Pour le développement)

```bash
cd Front/android
./gradlew signingReport
```

Ou sur Windows :

```powershell
cd Front/android
.\gradlew.bat signingReport
```

Cherchez dans l'output :

```
Variant: debug
Config: debug
Store: C:\Users\ASUS\.android\debug.keystore
Alias: androiddebugkey
MD5: XX:XX:XX...
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA-256: XX:XX:XX:XX...
```

**Copiez SHA-1 et SHA-256**

#### Option B : Commande directe keytool

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Sur Windows :

```powershell
keytool -list -v -keystore C:\Users\ASUS\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

---

### **2. Ajouter SHA-1 dans Firebase Console**

1. **Allez sur Firebase Console** : https://console.firebase.google.com/
2. Sélectionnez votre projet **DJTrip**
3. Cliquez sur ⚙️ **Project Settings** (Paramètres du projet)
4. Descendez jusqu'à **Your apps**
5. Sélectionnez votre application Android (package: `com.example.travelo`)
6. Cliquez sur **Add fingerprint** (Ajouter une empreinte)
7. **Collez votre SHA-1**
8. Répétez pour **SHA-256**
9. Cliquez sur **Save** (Enregistrer)

---

### **3. Télécharger le nouveau google-services.json**

Après avoir ajouté les SHA, Firebase génère un nouveau `google-services.json`

1. Toujours dans **Project Settings**
2. Sous votre app Android, cliquez sur **Download google-services.json**
3. **Remplacez** le fichier existant :
   ```
   Front/android/app/google-services.json
   ```

---

### **4. Vérifier OAuth 2.0 Client IDs dans Google Cloud**

1. Allez sur **Google Cloud Console** : https://console.cloud.google.com/
2. Sélectionnez votre projet
3. Menu **APIs & Services** → **Credentials**
4. Vous devriez voir :
   - ✅ **Android client** (créé automatiquement par Firebase)
   - ✅ **Web client (auto created by Google Service)** ← **Important pour Google Sign‑In**

5. Cliquez sur le **Web client** et copiez le **Client ID**

---

### **5. Vérifier le Client ID dans le code Flutter**

Ouvrez `Front/lib/services/auth_service.dart` et vérifiez :

```dart
// Google Sign-In
static Future<Map<String, dynamic>> signInWithGoogle() async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      // Ajoutez le serverClientId si nécessaire
      serverClientId: 'VOTRE_WEB_CLIENT_ID.apps.googleusercontent.com',
    );
```

**Note** : Le `serverClientId` est le Web Client ID que vous avez obtenu à l'étape 4.

---

### **6. Clean & Rebuild**

```bash
cd Front
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

Sur Windows :

```powershell
cd Front
flutter clean
flutter pub get
cd android
.\gradlew.bat clean
cd ..
flutter run
```

---

### **7. Si ça ne marche toujours pas**

#### A. Vérifier le package name

Dans `Front/android/app/build.gradle` :

```gradle
defaultConfig {
    applicationId "com.example.travelo"  // ← Doit matcher Firebase
}
```

#### B. Activer Google Sign-In API

1. Google Cloud Console → **APIs & Services** → **Library**
2. Recherchez **Google Sign-In API**
3. Cliquez sur **ENABLE**

#### C. Vérifier la clé API dans AndroidManifest.xml

`Front/android/app/src/main/AndroidManifest.xml` doit contenir :

```xml
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

---

## 📝 Résumé des étapes essentielles

1. ✅ Obtenir SHA-1 et SHA-256 : `./gradlew signingReport`
2. ✅ Ajouter dans Firebase Console → Project Settings → Your apps
3. ✅ Télécharger nouveau `google-services.json`
4. ✅ Copier le Web Client ID depuis Google Cloud Console
5. ✅ Ajouter `serverClientId` dans le code Flutter
6. ✅ `flutter clean` + `flutter run`

---

## 🔗 Liens utiles

- Firebase Console: https://console.firebase.google.com/
- Google Cloud Console: https://console.cloud.google.com/
- Google Sign-In Documentation: https://pub.dev/packages/google_sign_in
