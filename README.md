# DJTrip – Application de voyage (Djerba)

Application mobile **Flutter** et API **Node.js/Express** pour découvrir des activités à Djerba : réservations, messagerie, avis et profils organisateurs/touristes.

---

## Structure du projet

| Dossier | Stack | Rôle |
|--------|------|------|
| **Front/** | Flutter (Dart) | App mobile Android/iOS |
| **Back/** | Node.js, Express, MongoDB, Socket.io | API REST + temps réel |
| **documentation/** | — | Docs (setup, API, architecture) |

- **Back** : `server.js` = point d’entrée ; routes sous `/api/*` ; Socket.io pour la messagerie.
- **Front** : `lib/main.dart` → `SplashScreen` → login ou `MainScreen` / `OrganizerMainScreen`.

---

## Démarrage rapide

### Backend

```bash
cd Back
npm install
# Créer un fichier .env (MONGODB_URI, JWT_SECRET, etc.)
npm run dev
```

Serveur par défaut : `http://localhost:3000`.

### Frontend

```bash
cd Front
flutter pub get
# Ajuster l’URL dans lib/config/api_config.dart (IP de votre machine pour émulateur/appareil)
flutter run
```

---

## Fonctionnalités principales

- **Authentification** : Inscription / connexion (email, Google, Facebook), JWT, vérification email.
- **Utilisateurs** : Touristes et organisateurs ; profil, avatar (Cloudinary), pays, langues.
- **Activités** : CRUD, recherche, carte ; inscriptions (réservations).
- **Réservations** : Demandes, approbation/refus par l’organisateur, messages optionnels.
- **Messagerie** : Conversations, chat en temps réel (Socket.io), marquage lu.
- **Avis** : Notes et commentaires sur les activités/organisateurs.

---

## Messagerie – corrections et améliorations

- Connexion Socket.io au chargement du **ChatScreen** pour recevoir les messages en direct.
- Filtrage des événements **message_sent** / **new_message** par conversation (partnerId / receiverId) pour éviter les messages dans la mauvaise conversation.
- Éviction des doublons par `id` de message.
- Gestion des erreurs (connexion, envoi) et état de chargement / erreur dans le chat.
- Design du chat : bulles (couleurs thème), zone de saisie, indicateur d’envoi, écran d’erreur avec « Réessayer ».

---

## Améliorations déjà intégrées

- **Thème global** : `lib/theme/app_theme.dart` (AppColors, AppTextStyles) utilisé dans main, chat, conversations, home, activités.
- **Squelettes** : ShimmerBox, ActivityCardSkeleton, ConversationTileSkeleton pour listes activités et conversations.
- **Favoris** : User.favorites, routes GET/POST/DELETE `/api/users/me/favorites/:activityId`, FavoritesService, bouton cœur sur cartes.
- **Partage** : share_plus, bouton partage sur chaque carte d'activité (titre, description, prix).
- **Config env** : `EnvConfig` (dart-define ENV), `api_config.dart` pour l'URL.
- **Rate limiting** : express-rate-limit sur `/api` (100 req/min) et sur signin/signup/forgot-password (20/15 min).

---

## Suggestions d’améliorations (fonctionnalités & design)

### Messagerie

- [x] **Marquer comme lu** : appel à `mark_read` à l’ouverture du chat.
- [x] **Indicateur « en ligne »** : pastille verte + statut dans le chat.
- [x] **Typing indicator** : « En train d’écrire… » via Socket.
- [ ] **Notifications push** : Firebase (FCM) pour nouveaux messages en arrière-plan.
- [ ] **Pièces jointes** : images dans les messages (upload + affichage).

### Réservations & activités

- [ ] **Rappels** : notifications avant la date de l’activité.
- [ ] **Annulation avec politique** : délai d’annulation, remboursement partiel/total selon les règles métier.
- [ ] **Calendrier** : vue calendrier des réservations (organisateur et touriste).
- [ ] **Filtres avancés** : par prix, date, durée, type d’activité, note moyenne.

### Profil & découverte

- [ ] **Profils publics** : améliorer la page organisateur (activités, avis).
- [x] **Favoris** : cœur sur les cartes, API et service Flutter.
- [ ] **Recommandations** : suggestions selon pays/langue/centres d’intérêt.
- [x] **Partage** : bouton partage (titre, description, prix) sur les cartes.

### Design & UX

- [x] **Thème cohérent** : `AppTheme.light`, `AppColors`, `AppTextStyles` (home, chat, conversations, activités).
- [x] **Squelettes de chargement** : shimmers pour activités et conversations.
- [ ] **Accessibilité** : contrastes, labels, lecteurs d’écran.
- [ ] **Animations** : transitions entre écrans, micro-interactions.

### Technique

- [ ] **Cache local** : SQLite ou Hive pour mode hors-ligne partiel.
- [ ] **Pagination** : infinite scroll sur activités et messages.
- [ ] **Tests** : unitaires et widgets.
- [ ] **CI/CD** : pipeline build/tests/déploiement.
- [x] **Environnements** : `EnvConfig` (dart-define `ENV`), `api_config.dart` pour l’URL.

### Sécurité & performance

- [x] **Rate limiting** : `authLimiter` (signin/signup/forgot-password), `apiLimiter` sur `/api`.
- [ ] **Validation** : schémas (Joi/Zod) pour body/params.
- [ ] **HTTPS** : en production uniquement.

---

## Documentation détaillée

- **Installation et configuration** : `documentation/SETUP.md`
- **Architecture** : `documentation/ARCHITECTURE.md`
- **API** : `documentation/API_REFERENCE.md` et `Back/README.md`
- **Fonctionnalités** : `documentation/FEATURES.md`

---

## Licence

Projet à usage éducatif / portfolio. Voir les fichiers du dépôt pour d’éventuelles précisions.
