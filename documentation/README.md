# 📚 Documentation Travelo

Bienvenue dans la documentation du projet **Travelo** - une application mobile de voyage complète.

## 📁 Structure de la Documentation

| Document                                                             | Description                                                                                             |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| [README_INDEX.md](./README_INDEX.md)                                 | 📚 **Index de tous les README** - Liste complète de tous les fichiers README avec dates et descriptions |
| [SETUP.md](./SETUP.md)                                               | 🚀 **Guide d'Installation Complet** - Configuration du projet, prérequis, installation étape par étape  |
| [ARCHITECTURE.md](./ARCHITECTURE.md)                                 | 🏗️ **Architecture Technique** - Structure du projet, flux de données, design patterns                   |
| [API_REFERENCE.md](./API_REFERENCE.md)                               | 📡 **Référence API** - Documentation complète de toutes les routes backend                              |
| [FEATURES.md](./FEATURES.md)                                         | 🎯 **Liste des Fonctionnalités** - Catalogue détaillé de toutes les features disponibles                |
| [GOOGLE_SIGNIN_FIX_2026-03-08.md](./GOOGLE_SIGNIN_FIX_2026-03-08.md) | 🔧 **Fix Google Sign-In** - Guide complet pour résoudre ApiException: 10                                |
| [CHANGELOG_2026-03-08.md](./CHANGELOG_2026-03-08.md)                 | 📝 **Changelog du 08/03/2026** - Modifications du 8 mars 2026                                           |
| [CHANGELOG_28-02-2026.md](./CHANGELOG_28-02-2026.md)                 | 📝 **Changelog du 28/02/2026** - Modifications du 28 février 2026                                       |

## 🚀 Quick Start

1. **Nouveau développeur ?** Commencez par [SETUP.md](./SETUP.md)
2. **Comprendre l'architecture ?** Lisez [ARCHITECTURE.md](./ARCHITECTURE.md)
3. **Développer des features ?** Consultez [FEATURES.md](./FEATURES.md)
4. **Intégration API ?** Voir [API_REFERENCE.md](./API_REFERENCE.md)
5. **Changements récents ?** Lisez [CHANGELOG_28-02-2026.md](./CHANGELOG_28-02-2026.md)

## 🏗️ Architecture du Projet

### Frontend (Flutter)

```
FrontFlutter/
├── lib/
│   ├── config/          # Configuration (API endpoints)
│   ├── models/          # Modèles de données (User, etc.)
│   ├── screens/         # Pages de l'application
│   │   ├── auth/        # Authentification (Login, Signup)
│   │   ├── onboarding/  # Processus d'intégration
│   │   └── main/        # Écrans principaux
│   ├── services/        # Services API (auth, user, etc.)
│   ├── utils/           # Utilitaires (Countries, Languages)
│   └── widgets/         # Composants réutilisables
└── assets/              # Ressources (images, fonts)
```

### Backend (Node.js/Express)

```
Back/pfe_backend-main/
├── config/              # Configuration (DB, Cloudinary)
├── controllers/         # Logique métier
├── models/              # Schémas MongoDB
├── routes/              # Routes API
├── middleware/          # Middleware (auth, upload)
└── server.js            # Point d'entrée
```

## 🔑 Fonctionnalités Clés

### Authentification & Gestion Utilisateur

- ✅ Inscription/Connexion avec JWT
- ✅ Deux types d'utilisateurs : Touriste et Organisateur
- ✅ Gestion automatique du statut de compte (actif/inactif)
- ✅ Déconnexion avec mise à jour du statut

### Profil Utilisateur

- ✅ Upload de photo de profil (Cloudinary)
- ✅ Sélection de pays avec drapeaux (195 pays)
- ✅ Sélection de langue (49 langues)
- ✅ Centres d'intérêt personnalisables
- ✅ Partage de profil
- ✅ Édition complète du profil

### Onboarding

- ✅ Processus d'intégration en 3 étapes
- ✅ Collecte d'informations progressives
- ✅ Gestion des permissions (notifications, données)

### Navigation

- ✅ Bottom navigation avec 4 onglets
- ✅ Page d'accueil avec recherche et catégories
- ✅ Profil complet avec paramètres

## 🛠️ Technologies Utilisées

### Frontend

- **Flutter** (Dart 3.11.0) - Framework mobile
- **http** - Requêtes API
- **shared_preferences** - Stockage local
- **image_picker** - Sélection d'images
- **intl** - Internationalisation

### Backend

- **Node.js** - Runtime JavaScript
- **Express** - Framework web
- **MongoDB** - Base de données NoSQL
- **JWT** - Authentification sécurisée
- **Cloudinary** - Stockage d'images
- **bcryptjs** - Hachage de mots de passe
- **Multer** - Upload de fichiers

## 🚀 Démarrage Rapide

### Prérequis

- Flutter SDK (3.11.0+)
- Node.js (16+)
- MongoDB
- Compte Cloudinary

### Installation Backend

```bash
cd Back/pfe_backend-main
npm install
# Configurer .env avec les variables d'environnement
node server.js
```

### Installation Frontend

```bash
cd FrontFlutter
flutter pub get
flutter run
```

## 📱 Configuration Réseau

**Backend** : `http://192.168.3.12:3000`

- CORS activé pour tous les origins
- Firewall configuré pour le port 3000

## 🔐 Sécurité

- JWT avec access token (15min) et refresh token
- Mots de passe hachés avec bcrypt
- Validation des données côté serveur
- Permissions Android pour caméra et stockage

## 📊 Base de Données

### Collections MongoDB

- **users** - Utilisateurs (base)
  - Champs communs : fullname, email, age, avatar, bio, etc.
- **touristes** - Hérite de users
  - Champs : centres_interet, langue_preferee
- **organisators** - Hérite de users
  - Champs spécifiques aux organisateurs

## 📞 Contact & Support

Pour toute question ou problème :

- Consultez la documentation détaillée
- Référez-vous au CHANGELOG pour les dernières modifications
- Vérifiez les erreurs dans les logs

## 📝 Licence

Ce projet est développé dans le cadre d'un PFE (Projet de Fin d'Études).

---

**Dernière mise à jour** : 28 février 2026
