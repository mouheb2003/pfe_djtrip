# 🔧 Configuration Google & Facebook OAuth pour DJTrip

## ✅ Status Actuel

- ✓ Backend: GOOGLE_CLIENT_ID configuré dans `.env`
- ✓ Code Flutter: Corrigé pour supporter ID tokens
- ⚠️ **À FAIRE**: Passer le GOOGLE_CLIENT_ID au frontend

---

## 🚀 Étape 1: Récupérer le Google Server Client ID

Vous avez **déjà** un Google Web Client ID dans votre `.env` backend:

```
GOOGLE_CLIENT_ID=488329502891-h71m67eo5hmk36q81ds4kkkd6kc3c0ot.apps.googleusercontent.com
```

**C'EST LE MÊME ID à utiliser en Flutter!**

---

## 🎯 Étape 2: Lancer l'app Flutter avec le Google Client ID

### Pour Android Emulator/Device:

```bash
cd Front
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=488329502891-h71m67eo5hmk36q81ds4kkkd6kc3c0ot.apps.googleusercontent.com \
  --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

### Pour iOS Simulator/Device:

```bash
cd Front
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=488329502891-h71m67eo5hmk36q81ds4kkkd6kc3c0ot.apps.googleusercontent.com \
  --dart-define=API_URL=http://localhost:3000/api/v1
```

### Pour Web:

```bash
cd Front
flutter run -d chrome \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=891015623935-f9dmcdek9blg8gusgetuu52bor903lv8.apps.googleusercontent.com
```

---

## 🧪 Tester le Login Google

1. **Démarrer le backend**:

```bash
cd Back
npm start
```

2. **Démarrer l'app Flutter** (avec les commandes d'en haut)

3. **Cliquer sur "Sign In with Google"**

4. **Vérifier les logs**:
   - ✓ Pas d'erreur "Google did not return an ID token"
   - ✓ Login réussit ou erreur du backend

---

## ❌ Dépannage

### Erreur: "Google did not return an ID token"

**Cause**: GOOGLE_SERVER_CLIENT_ID vide

**Solution**:

```bash
# Vérifier que c'est passé:
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=votre-id --verbose | grep "GOOGLE_SERVER_CLIENT_ID"

# Ou ajouter un print dans main.dart:
import 'package:djtrip/config/oauth_config.dart';

void main() {
  OAuthConfig.printConfig(); // Affiche le status
  runApp(const MyApp());
}
```

### Erreur: "Invalid Google token"

**Cause**: ID token rejeté par le backend

**Solution**: Vérifier que:

- Le `GOOGLE_CLIENT_ID` dans `.env` backend correspond au frontend
- Le backend est en production/de test correct

---

## 📱 Configuration iOS/Android (Optionnel)

### Pour Android - google-services.json (Optionnel)

Si vous voulez aussi un Android Client ID spécifique:

1. Aller à Google Cloud Console → Credentials
2. Créer une nouvelle credential Android (type: Android)
3. Remplir le SHA-1 de votre signing key:
   ```bash
   cd Front/android/app
   ./gradlew signingReport
   ```
4. Ajouter le `google-services.json` dans `Front/android/app/`

### Pour iOS - Configuration (Optionnel)

1. Google Cloud Console → Credentials → Create iOS credential
2. Ajouter le Bundle ID: `com.example.djtrip`
3. Copier l'URL scheme Google dans `ios/Runner/Info.plist`

---

## 🔐 Facebook OAuth (Similaire)

Pour Facebook, ajouter dans la commande:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=FACEBOOK_APP_ID=votre-facebook-id
```

---

## 📋 Checklist Rapide

## ⚠️ Important

Le fichier `Front/android/app/google-services.json` doit provenir du **même projet Firebase/Google Cloud** que le Web Client ID utilisé par `GOOGLE_CLIENT_ID`.

Si votre `google-services.json` contient un autre `project_id` ou un autre `client_id`, Google Sign-In Android peut afficher `misconfigured on Android` même si le code est correct.

- [ ] Vérifier GOOGLE_CLIENT_ID dans Back/.env
- [ ] Lancer `flutter run` avec `--dart-define=GOOGLE_SERVER_CLIENT_ID`
- [ ] Tester login Google sur device
- [ ] Si error: afficher les logs avec `--verbose`
- [ ] Configurer Facebook App ID (optionnel)

---

**Questions?** Vérifier `documentation/GOOGLE_FACEBOOK_AUTH_SETUP.md` pour plus de détails.
