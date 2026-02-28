# Système d'Onboarding et Gestion de Statut - Travelo

## Vue d'ensemble

Ce document décrit le nouveau système d'onboarding post-inscription et le système de gestion automatique du statut des comptes utilisateurs.

## 🎯 Fonctionnalités

### 1. Flux d'Onboarding Post-Inscription

Après l'inscription, les utilisateurs passent par un processus d'onboarding en plusieurs étapes pour compléter leur profil:

#### Étape 1: Complétion du Profil (`ProfileCompletionScreen`)

- **Informations personnelles**: Âge (optionnel, avec validation 13-120 ans)
- **Informations de contact**: Numéro de téléphone et pays d'origine
- **Biographie**: Description personnelle (max 500 caractères)
- Interface avec indicateur de progression
- Possibilité de passer les étapes

#### Étape 2: Permissions et Préférences (`PermissionsScreen`)

- **Notifications Email** (par défaut activé)
- **Notifications SMS** (par défaut désactivé)
- **Consentement des données** (OBLIGATOIRE)
- Design avec cartes interactives
- Note de confidentialité explicite

### 2. Gestion Automatique du Statut de Compte

Le système gère automatiquement le statut des comptes en fonction de l'activité:

#### Règles de Statut

- **Actif**: Compte utilisé régulièrement (< 180 jours d'inactivité)
- **Inactif**: Compte suspendu automatiquement après 180 jours d'inactivité

#### Mise à Jour Automatique

- À chaque connexion, le système vérifie la dernière activité
- Si le compte a été inactif > 180 jours: passage automatique en "inactif"
- Si l'utilisateur se reconnecte avant 180 jours: réactivation automatique
- Connexion bloquée pour les comptes inactifs avec message explicite

## 📁 Structure des Fichiers

### Frontend (Flutter)

```
FrontFlutter/lib/
├── screens/
│   ├── onboarding/
│   │   ├── profile_completion_screen.dart  # Écran de complétion du profil
│   │   └── permissions_screen.dart          # Écran des permissions
│   └── auth/
│       └── new_signup_screen.dart           # Modifié pour intégrer l'onboarding
├── services/
│   └── user_service.dart                     # Nouveau service pour la gestion utilisateur
├── models/
│   └── user.dart                             # Modèle utilisateur existant
└── config/
    └── api_config.dart                       # Mis à jour avec nouveaux endpoints
```

### Backend (Node.js)

```
Back/pfe_backend-main/
├── controllers/
│   └── user.js                               # Nouvelles fonctions ajoutées
├── routes/
│   └── user.js                               # Nouvelles routes ajoutées
└── models/
    └── user.js                               # Modèle existant (pas de changement)
```

## 🔌 API Endpoints

### Nouvelles Routes Ajoutées

#### 1. Mettre à jour le profil

```
PUT /api/users/me
Authorization: Bearer {token}
Content-Type: application/json

Body:
{
  "age": 25,
  "num_tel": "+33612345678",
  "bio": "Passionné de voyages...",
  "pays_origine": "France",
  "notifications_email": true,
  "notifications_sms": false,
  "consentement_donnees": true
}

Response: 200 OK
{
  "message": "Profile updated successfully",
  "user": { ... }
}
```

#### 2. Mettre à jour l'avatar

```
PUT /api/users/me/avatar
Authorization: Bearer {token}
Content-Type: multipart/form-data

Body:
avatar: [File]

Response: 200 OK
{
  "message": "Avatar updated successfully",
  "avatar": "https://cloudinary.com/...",
  "user": { ... }
}
```

#### 3. Mettre à jour le statut (Admin)

```
PUT /api/users/:id/status
Authorization: Bearer {token}
Content-Type: application/json

Body:
{
  "status": "actif" | "inactif"
}

Response: 200 OK
{
  "message": "Account status updated successfully",
  "user": { ... }
}
```

## 🎨 Design & UX

### Principes de Design

- **Progressive Disclosure**: Information révélée progressivement
- **Skippable Steps**: Toutes les étapes peuvent être passées sauf le consentement
- **Clear Progress**: Indicateur visuel de progression
- **Validation Friendly**: Messages d'erreur clairs et constructifs
- **Brand Consistency**: Couleurs Travelo (Orange #FF6B1A, Jaune #FFB84D)

### Composants Visuels

- Icônes larges et colorées pour chaque étape
- Cartes arrondies avec ombres légères
- Animations de transition fluides
- Boutons CTA proéminents

## 🔒 Sécurité & Confidentialité

### Protection des Données

- Validation côté client ET serveur
- Champs sensibles protégés (mot de passe, email ne peuvent pas être modifiés via updateProfile)
- Consentement explicite requis avant utilisation
- Message de confidentialité clair et visible

### Tokens & Authentification

- Utilisation de JWT pour l'authentification
- Refresh token pour sessions longues
- Vérification du token à chaque requête protégée

## 📊 Gestion du Statut

### Logique de Statut Automatique

```javascript
// Backend: controllers/user.js
updateAccountStatusBasedOnActivity(userId) {
  - Calcule jours depuis dernière connexion
  - Si > 180 jours && actif => inactif
  - Si < 180 jours && inactif => actif
  - Appelé automatiquement à chaque connexion
}
```

### Statuts Possibles

- `actif`: Compte utilisable normalement
- `inactif`: Connexion bloquée, nécessite réactivation

## 🚀 Flux Utilisateur

### Nouveau Utilisateur

1. **Inscription** → Écran d'inscription (email, mot de passe, nom, type)
2. **Token généré** → Utilisateur authentifié automatiquement
3. **Onboarding Étape 1** → Complétion du profil (3 sous-étapes)
4. **Onboarding Étape 2** → Configuration des permissions
5. **Home Screen** → Accès à l'application

### Utilisateur Existant (Connexion)

1. **Login** → Vérification des identifiants
2. **Vérification statut** → Mise à jour automatique basée sur activité
3. **Si inactif** → Blocage avec message
4. **Si actif** → Mise à jour de `derniere_connexion` + Accès accordé

## 📝 Utilisation

### Pour Tester le Flux Complet

1. **Créer un nouveau compte**:
   - Ouvrir l'app
   - Cliquer sur "S'inscrire"
   - Remplir les informations de base
   - Soumettre

2. **Suivre l'onboarding**:
   - Compléter les informations personnelles (ou passer)
   - Configurer les préférences de notification
   - Accepter le consentement des données (obligatoire)
   - Terminer

3. **Vérifier la mise à jour**:
   - Le profil doit être mis à jour dans la base de données
   - L'utilisateur est redirigé vers l'écran d'accueil

### Pour Tester la Gestion de Statut

1. **Simulation d'inactivité** (pour test en développement):
   - Modifier manuellement `derniere_connexion` dans MongoDB
   - Mettre une date > 180 jours
   - Tenter de se connecter
   - Le compte devrait passer en "inactif"

2. **Réactivation**:
   - Modifier `derniere_connexion` à une date récente
   - Se reconnecter
   - Le compte devrait être réactivé automatiquement

## 🐛 Dépannage

### Problèmes Courants

1. **Erreur "Non connecté"**
   - Vérifier que le token est bien sauvegardé
   - Vérifier `storage_service.dart`
   - Tester `/api/users/me` avec le token

2. **Avatar ne s'upload pas**
   - Vérifier la configuration Cloudinary dans `config/cloudinary.js`
   - Vérifier que le middleware `upload` fonctionne
   - Vérifier les permissions de fichiers

3. **Statut ne se met pas à jour**
   - Vérifier la fonction `updateAccountStatusBasedOnActivity`
   - Vérifier que la date est au bon format
   - Vérifier les logs backend

## 🔄 Améliorations Futures

- [ ] Écran de sélection d'avatar prédéfini
- [ ] Upload de photo depuis la galerie/caméra
- [ ] Validation de numéro de téléphone avec codes pays
- [ ] Sélecteur de pays avec drapeaux
- [ ] Notifications push pour compte inactif
- [ ] Dashboard admin pour gérer les statuts
- [ ] Statistiques d'activité utilisateur
- [ ] Système de badges/achievements

## 📞 Support

Pour toute question ou problème:

- Vérifier ce document en premier
- Consulter les logs backend et frontend
- Tester les endpoints avec Postman/Thunder Client

---

**Version**: 1.0.0  
**Date**: 28 Février 2026  
**Auteur**: Équipe Travelo
