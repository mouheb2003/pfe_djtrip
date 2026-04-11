# Remember Me & Forgot Password - Implementation Guide

**Date:** 8 mars 2026

---

## 🎯 Fonctionnalités Implémentées

### 1. **Remember Me (Local Storage)**

- Stockage sécurisé des credentials avec `flutter_secure_storage`
- Option pour sauvegarder email et mot de passe
- Auto-remplissage du formulaire de connexion
- Possibilité de supprimer les données stockées

### 2. **Forgot Password Flow**

- Page pour demander le reset avec email
- Génération et envoi de code à 6 chiffres
- Page pour entrer le code et nouveau mot de passe
- Validation du code avec expiration (15 minutes)
- Envoi d'email stylisé avec le code de reset

---

## 📁 Fichiers Créés/Modifiés

### Frontend (Flutter)

#### Nouveaux fichiers

1. **`Front/lib/screens/auth/forgot_password_screen.dart`**
   - Page pour entrer l'email
   - Validation de l'email
   - Envoi du code de reset
   - Navigation vers reset_password_screen

2. **`Front/lib/screens/auth/reset_password_screen.dart`**
   - Page pour entrer le code et nouveau mot de passe
   - Validation du code
   - Confirmation du mot de passe
   - Option pour renvoyer le code
   - Redirection vers login après succès

#### Fichiers modifiés

3. **`Front/pubspec.yaml`**
   - Ajout de `flutter_secure_storage: ^9.0.0`

4. **`Front/lib/services/storage_service.dart`**
   - Ajout de `flutter_secure_storage` import
   - Nouvelles méthodes:
     - `saveRememberMeCredentials(email, password)` - Sauvegarde sécurisée
     - `getRememberMeCredentials()` - Récupération des credentials
     - `isRememberMeEnabled()` - Vérifier si Remember Me est actif
     - `clearRememberMeCredentials()` - Supprimer les credentials
     - `clearAllData()` - Supprimer tout (tokens + credentials)

5. **`Front/lib/services/auth_service.dart`**
   - Nouvelles méthodes:
     - `forgotPassword(email)` - Demander un code de reset
     - `resetPassword(email, code, newPassword)` - Réinitialiser le mot de passe

6. **`Front/lib/config/api_config.dart`**
   - Ajout des endpoints:
     - `forgotPassword = '$baseUrl/users/forgot-password'`
     - `resetPassword = '$baseUrl/users/reset-password'`

7. **`Front/lib/screens/auth/login_screen.dart`**
   - Ajout de `initState()` pour charger les credentials sauvegardés
   - Méthode `_loadRememberMeCredentials()` - Auto-remplissage
   - Méthode `_clearRememberMe()` - Nettoyage
   - Méthode `_handleLogin()` - Login avec Remember Me
   - Navigation vers ForgotPasswordScreen
   - Indicateur de chargement pendant le login

---

### Backend (Node.js/Express)

#### Fichiers modifiés

8. **`Back/models/user.js`**
   - Ajout des champs:
     ```javascript
     passwordResetCode: String,
     passwordResetCodeExpiry: Date,
     ```

9. **`Back/services/user.js`**
   - Nouvelles méthodes:
     - `forgotPassword(email)` - Génère code + envoie email
     - `resetPassword(email, code, newPassword)` - Vérifie code + update password
   - Logging en mode développement pour afficher le code

10. **`Back/services/email.js`**
    - Nouvelle méthode:
      - `sendPasswordResetEmail(email, code, fullname)` - Email stylisé
    - Template HTML avec design cohérent

11. **`Back/controllers/user.js`**
    - Nouveaux controllers:
      - `forgotPassword(req, res)` - POST /forgot-password
      - `resetPassword(req, res)` - POST /reset-password
    - Gestion des erreurs spécifiques

12. **`Back/routes/user.js`**
    - Nouvelles routes:
      ```javascript
      router.post("/forgot-password", userController.forgotPassword);
      router.post("/reset-password", userController.resetPassword);
      ```

---

## 🔐 Sécurité

### Remember Me

- **Stockage sécurisé:** Utilise `flutter_secure_storage`
  - Chiffrement matériel sur iOS (Keychain)
  - Chiffrement matériel sur Android (KeyStore)
  - Credential Manager sur Windows
  - Keyring sur Linux

### Forgot Password

- **Code temporaire:** Expiration 15 minutes
- **Code unique:** Généré aléatoirement (6 chiffres)
- **Hash du mot de passe:** bcrypt avec salt
- **Nettoyage:** Code supprimé après utilisation
- **Validation:** Vérification email + code + expiration

---

## 📧 Emails Envoyés

### Email de Reset Password

- **Sujet:** "Reset Your Password - DJTrip"
- **Contenu:**
  - Code de reset (6 chiffres)
  - Validité (15 minutes)
  - Avertissement de sécurité
  - Design cohérent avec la marque
- **Format:** HTML + texte brut

---

## 🚀 Utilisation

### Remember Me

1. **Activer Remember Me:**

   ```dart
   // L'utilisateur coche "Remember me" lors du login
   // Les credentials sont automatiquement sauvegardés après un login réussi
   ```

2. **Auto-login:**

   ```dart
   // Au prochain démarrage, les champs sont pré-remplis
   // L'utilisateur peut se connecter directement
   ```

3. **Désactiver:**

   ```dart
   // Décocher "Remember me" lors du login
   // Les credentials sont automatiquement supprimés
   ```

4. **Logout complet:**
   ```dart
   await StorageService.clearAllData();
   // Supprime tokens + credentials
   ```

### Forgot Password

1. **Demander un reset:**

   ```dart
   await AuthService.forgotPassword(email: 'user@example.com');
   // Envoie un code à l'email
   ```

2. **Réinitialiser le mot de passe:**
   ```dart
   await AuthService.resetPassword(
     email: 'user@example.com',
     code: '123456',
     newPassword: 'newPassword123',
   );
   // Vérifie le code et met à jour le mot de passe
   ```

---

## 🧪 Tests

### Tests à effectuer

#### Remember Me

- ✅ Cocher Remember Me → credentials sauvegardés
- ✅ Décocher Remember Me → credentials supprimés
- ✅ Redémarrer l'app → champs pré-remplis si Remember Me actif
- ✅ Logout → credentials supprimés
- ✅ Login avec mauvais mot de passe → credentials non sauvegardés

#### Forgot Password

- ✅ Email valide → code envoyé
- ✅ Email invalide → erreur "No account found"
- ✅ Code correct → mot de passe changé
- ✅ Code incorrect → erreur "Invalid reset code"
- ✅ Code expiré (> 15 min) → erreur "expired"
- ✅ Renvoyer code → nouveau code généré
- ✅ Mot de passe trop court → erreur validation

---

## 🔧 Configuration Requise

### Frontend

```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  http: ^1.2.0
  shared_preferences: ^2.2.2
```

### Backend

```javascript
// .env
EMAIL_SERVICE=gmail
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
NODE_ENV=development
```

---

## 📱 Screenshots des Nouveaux Écrans

### 1. Login Screen avec Remember Me

- Checkbox "Remember me"
- Bouton "Forgot Password?"
- Auto-remplissage si Remember Me actif

### 2. Forgot Password Screen

- Logo DJTrip
- Champ email
- Bouton "Send Reset Code"
- Lien "Sign In"

### 3. Reset Password Screen

- Champ "Verification Code"
- Champ "New Password"
- Champ "Confirm Password"
- Bouton "Resend Code"
- Bouton "Reset Password"

---

## 🔗 Flux Complet

### Remember Me Flow

```
Login Screen
    ↓ [Cocher Remember Me + Login]
Credentials sauvegardés dans Secure Storage
    ↓ [Redémarrer app]
Login Screen (champs pré-remplis)
    ↓ [Cliquer Login]
Home Screen
```

### Forgot Password Flow

```
Login Screen
    ↓ [Cliquer "Forgot Password?"]
Forgot Password Screen
    ↓ [Entrer email + Cliquer "Send Reset Code"]
Backend génère code + envoie email
    ↓
Reset Password Screen
    ↓ [Entrer code + nouveaux mots de passe]
Backend vérifie code + met à jour password
    ↓ [Succès]
Dialog de confirmation
    ↓ [Cliquer OK]
Login Screen
```

---

## 🐛 Gestion des Erreurs

### Frontend

- Validation des champs avant envoi
- Messages d'erreur clairs
- Dialogues d'erreur pour l'utilisateur
- Loading indicators pendant les requêtes

### Backend

- Validation des données reçues
- Messages d'erreur spécifiques
- Logging des opérations en console
- Status codes HTTP appropriés

---

## 📝 Notes Importantes

1. **Remember Me:**
   - Les credentials sont chiffrés par le système
   - Jamais stockés en texte clair
   - Automatiquement supprimés au logout

2. **Forgot Password:**
   - Code valide 15 minutes seulement
   - Un seul code actif par utilisateur
   - Code supprimé après utilisation
   - Email doit être vérifié (user must exist)

3. **Développement:**
   - Les codes sont affichés en console en mode dev
   - Facilite les tests sans configuration email
   - En production, seuls les emails sont envoyés

4. **Production:**
   - Configurer un service email professionnel (SendGrid, Mailgun)
   - Activer HTTPS pour toutes les requêtes
   - Implémenter rate limiting sur les routes forgot-password
   - Logger les tentatives de reset pour détecter les abus

---

## 🎨 Design & UX

- **Cohérence:** Design uniforme avec le reste de l'app
- **Accessibilité:** Messages clairs et indicateurs visuels
- **Feedback:** Loading states et messages de succès/erreur
- **Navigation:** Retours logiques entre les écrans
- **Validation:** Validation en temps réel des champs

---

## 📚 Documentation Technique

### API Endpoints

#### POST /users/forgot-password

```json
Request:
{
  "email": "user@example.com"
}

Success Response (200):
{
  "message": "Password reset code has been sent to your email"
}

Error Response (404):
{
  "message": "No account found with this email address"
}
```

#### POST /users/reset-password

```json
Request:
{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newPassword123"
}

Success Response (200):
{
  "message": "Password has been reset successfully. You can now login."
}

Error Responses (400):
{
  "message": "Invalid reset code"
}
{
  "message": "Reset code has expired. Please request a new one"
}
{
  "message": "Password must be at least 6 characters long"
}
```

---

## ✅ Checklist d'Implémentation

- [x] Ajouter flutter_secure_storage au pubspec.yaml
- [x] Créer méthodes Remember Me dans storage_service.dart
- [x] Créer forgot_password_screen.dart
- [x] Créer reset_password_screen.dart
- [x] Ajouter méthodes forgot/reset dans auth_service.dart
- [x] Ajouter endpoints dans api_config.dart
- [x] Mettre à jour login_screen.dart avec Remember Me
- [x] Ajouter champs dans user model
- [x] Créer méthodes forgot/reset dans user service
- [x] Créer sendPasswordResetEmail dans email service
- [x] Ajouter controllers forgot/reset password
- [x] Ajouter routes forgot/reset password
- [x] Installer les dépendances Flutter
- [x] Tester le flux complet

---

## 🚦 Prochaines Étapes

1. **Tester sur appareil réel:** Vérifier le stockage sécurisé
2. **Configurer email production:** Utiliser SendGrid ou Mailgun
3. **Implémenter rate limiting:** Limiter les tentatives de reset
4. **Ajouter analytics:** Tracker l'utilisation de forgot password
5. **Améliorer l'UI:** Animations et transitions
6. **Ajouter tests unitaires:** Pour les services et controllers
7. **Documentation utilisateur:** Guide pour les utilisateurs finaux

---

**Auteur:** Assistant IA  
**Date:** 8 mars 2026  
**Version:** 1.0  
**Status:** ✅ Implémenté et testé
