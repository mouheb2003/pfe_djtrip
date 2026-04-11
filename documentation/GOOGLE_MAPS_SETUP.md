# Configuration Google Maps API

## Vue d'ensemble

L'application utilise Google Maps pour permettre aux organisateurs de sélectionner précisément la localisation de leurs activités via une carte interactive.

## Configuration requise

### 1. Obtenir une clé API Google Maps

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créez un nouveau projet ou sélectionnez un projet existant
3. Activez les APIs suivantes :
   - **Maps SDK for Android**
   - **Maps SDK for iOS** (si vous supportez iOS)
   - **Geocoding API** (pour la conversion adresse ↔ coordonnées)
   - **Places API** (optionnel, pour l'autocomplétion)

4. Créez une clé API :
   - Menu → APIs & Services → Credentials
   - Create Credentials → API Key
   - Copiez la clé générée

### 2. Configurer la clé API

#### Android

Ouvrez `Front/android/app/src/main/AndroidManifest.xml` et remplacez :

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

Par votre vraie clé API :

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"/>
```

#### iOS (si applicable)

Ouvrez `Front/ios/Runner/AppDelegate.swift` et ajoutez :

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Restrictions de clé API (Recommandé)

Pour sécuriser votre clé API :

1. Dans Google Cloud Console → Credentials
2. Cliquez sur votre clé API
3. Sous "Application restrictions" :
   - Choisissez **Android apps**
   - Ajoutez votre package name : `com.example.travelo`
   - Ajoutez vos SHA-1 fingerprints (utilisez les mêmes que pour Google Sign-In)

4. Sous "API restrictions" :
   - Choisissez **Restrict key**
   - Sélectionnez uniquement :
     - Maps SDK for Android
     - Geocoding API

### 4. Tester la configuration

Une fois configuré, lancez l'application et testez :

1. Créez une nouvelle activité
2. Sélectionnez "Location" → Mode "On Map"
3. Cliquez sur "Select Location on Map"
4. La carte devrait s'afficher avec Djerba par défaut
5. Cherchez une adresse dans la barre de recherche
6. Ou tapez directement sur la carte

## Fonctionnalités

### Sélection de localisation

L'organisateur peut choisir entre deux modes :

#### Mode 1 : Liste prédéfinie

- Dropdown avec des lieux populaires en Tunisie
- Actuellement : Tunis, Carthage, Sidi Bou Said, Hammamet, Sousse, Djerba, Tozeur, Kairouan
- **À développer** : Liste dynamique depuis la base de données

#### Mode 2 : Carte interactive

- Recherche d'adresse avec autocomplétion
- Tap sur la carte pour sélectionner
- Marker draggable pour ajuster la position
- Conversion automatique coordonnées → adresse (reverse geocoding)
- Affichage de l'adresse sélectionnée en temps réel

### Upload d'images

- Upload multiple d'images (galerie ou caméra)
- Grille de prévisualisation 3 colonnes
- Suppression d'images individuelles
- Support des images existantes (édition)
- **À développer** : Upload vers Cloudinary

## Coûts

Google Maps API est **gratuit** jusqu'à certaines limites mensuelles :

- **Maps SDK for Android** : 100 000 chargements/mois gratuits
- **Geocoding API** : 40 000 requêtes/mois gratuites

Au-delà, environ $7 pour 1000 chargements supplémentaires.

Pour une application de startup, les quotas gratuits sont largement suffisants.

## Troubleshooting

### Problème : La carte n'apparaît pas (écran gris)

**Solutions** :

1. Vérifiez que la clé API est correctement configurée dans AndroidManifest.xml
2. Vérifiez que Maps SDK for Android est activé dans Google Cloud Console
3. Vérifiez les logs Android : `flutter run` et recherchez "Google Maps"
4. Attendez quelques minutes après avoir créé la clé (propagation)

### Problème : "This API project is not authorized to use this API"

**Solution** :

- La clé API a des restrictions trop strictes
- Vérifiez que l'API nécessaire est activée
- Vérifiez que le package name dans les restrictions correspond

### Problème : La recherche d'adresse ne fonctionne pas

**Solution** :

- Activez **Geocoding API** dans Google Cloud Console
- Vérifiez les restrictions de la clé API

## Améliorations futures

- [ ] Autocomplete pour la recherche d'adresse (Places API)
- [ ] Afficher plusieurs markers pour les activités à proximité
- [ ] Calculer la distance entre utilisateur et activité
- [ ] Mode satellite/terrain
- [ ] Sauvegarde des lieux favoris
- [ ] Liste dynamique de lieux depuis la base de données

## Documentation officielle

- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Geocoding Flutter](https://pub.dev/packages/geocoding)
- [Google Cloud Console](https://console.cloud.google.com/)
