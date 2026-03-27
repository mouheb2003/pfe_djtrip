# Changelog — 14 Mars 2026

## Vue d'ensemble

Cette journée a été consacrée à l'amélioration complète du module de messagerie, à l'ajout d'un support média plus robuste, à la refonte des profils publics, et à plusieurs raffinements UX autour des conversations, profils et activités.

---

## 1. Messagerie temps réel et envoi média

### Objectif

Fiabiliser l'envoi des messages texte, audio et vidéo dans les conversations.

### Modifications principales

- Ajout du support vidéo dans le modèle backend des messages.
- Ajout d'un endpoint backend d'envoi vidéo avec upload média.
- Ajout de la route multipart dédiée à la vidéo.
- Ajout de `sendVideoMessage()` côté Flutter.
- Intégration de la sélection vidéo depuis la galerie dans l'écran de conversation.
- Affichage spécifique des messages vidéo dans les bulles du chat.

### Fichiers concernés

- `Back/models/message.js`
- `Back/controllers/message.js`
- `Back/routes/message.js`
- `Front/lib/services/message_service.dart`
- `Front/lib/screens/shared/chat_conversation_screen.dart`

---

## 2. Enregistrement vocal avancé dans le chat

### Objectif

Transformer l'envoi vocal en une expérience plus claire, proche des applications de messagerie modernes.

### Améliorations apportées

- Ajout d'un indicateur d'enregistrement avec timer temps réel.
- Ajout d'une vraie gestion d'erreur au démarrage / arrêt de l'enregistrement.
- Ajout de la permission `RECORD_AUDIO` côté Android.
- Remplacement du mode auto-send par des actions explicites :
  - annuler via corbeille,
  - envoyer via bouton dédié.
- Refonte du composer vocal avec :
  - minuterie,
  - slide to cancel,
  - pause / reprise,
  - bouton d'envoi explicite pendant l'enregistrement.
- Suppression des SnackBars inutiles pendant l'annulation/envoi.

### Fichiers concernés

- `Front/android/app/src/main/AndroidManifest.xml`
- `Front/lib/screens/shared/chat_conversation_screen.dart`

---

## 3. Raffinement UI du chat et des bulles de message

### Objectif

Rendre l'interface de conversation plus propre et plus proche du design ciblé.

### Changements

- Réduction de la hauteur de la barre supérieure du chat.
- Ajout d'une zone cliquable avatar + nom + statut dans le header.
- Refonte du style des bulles reçues.
- Prise en charge améliorée des messages emoji courts.
- Affichage du vrai avatar du partenaire dans les bulles reçues.
- Remplacement du badge `TODAY` par une date réelle dynamique.

### Fichiers concernés

- `Front/lib/screens/shared/chat_conversation_screen.dart`

---

## 4. Navigation vers les profils publics

### Objectif

Permettre une navigation fluide entre chat, reviews et profils publics.

### Changements

- Depuis le header du chat, clic sur l'organisateur vers son profil public réel.
- Depuis les reviews organisateur, clic sur l'auteur vers son profil public utilisateur.
- Depuis le bouton `Message` du profil organisateur, ouverture directe d'une conversation existante ou nouvelle.
- Depuis le profil public utilisateur, bouton `Message` vers la conversation dédiée.

### Fichiers concernés

- `Front/lib/screens/shared/chat_conversation_screen.dart`
- `Front/lib/screens/shared/public_organizer_profile_screen.dart`
- `Front/lib/screens/shared/public_tourist_profile_screen.dart`
- `Front/lib/screens/shared/public_user_profile_screen.dart`

---

## 5. Refonte du profil public organisateur

### Objectif

Passer d'un écran statique à un écran basé sur des données réelles tout en respectant une nouvelle maquette visuelle.

### Fonctionnalités ajoutées

- Chargement dynamique du profil organisateur via API.
- Chargement dynamique des activités de l'organisateur.
- Chargement réel des reviews de l'organisateur via endpoint public.
- Hero image + avatar superposé + boutons d'action.
- Section `About Us` dynamique.
- Section `Activity Specialties` dérivée des activités.
- Section `Our Activities` avec cartes réelles et navigation vers le détail.
- Bloc `Global Rating` redesigné.
- Distribution de rating temporairement figée à :
  - 77%
  - 6%
  - 3%

### Fichiers concernés

- `Front/lib/screens/shared/public_organizer_profile_screen.dart`
- `Front/lib/services/review_service.dart`

### Note

La distribution exacte des notes est encore statique côté frontend en attendant un endpoint backend dédié.

---

## 6. Profil public utilisateur / touriste

### Objectif

Afficher un profil public consultable depuis les reviews, avec un design inspiré de la maquette fournie.

### Changements

- Création d'un écran public utilisateur/touriste dynamique.
- Affichage des données réelles :
  - avatar,
  - nom,
  - bio,
  - pays,
  - intérêts,
  - reviews,
  - favoris,
  - réservations lorsque possible.
- Suppression du bouton `Share` pour ne garder qu'un bouton `Message`.
- Remplacement du libellé `Bookings` par `Reservations`.
- Les cartes d'activités récentes ouvrent le détail activité en mode consultation (`viewOnly`) sans bouton Réserver.

### Fichiers concernés

- `Front/lib/screens/shared/public_tourist_profile_screen.dart`
- `Front/lib/screens/shared/public_user_profile_screen.dart`

### Limitation actuelle

Le total des réservations d'un autre touriste n'est pas exposé publiquement par le backend. Le compteur ne peut donc être réel que pour certains cas (ex: profil connecté ou logique dérivée côté organisateur).

---

## 7. Compatibilité et corrections d'import

### Objectif

Éviter les erreurs de compilation liées aux renommages récents d'écrans publics.

### Changements

- Création d'un fichier alias `public_user_profile_screen.dart` qui ré-exporte l'écran public touriste.
- Correction d'un parsing JSON invalide dans le profil public utilisateur.

### Fichiers concernés

- `Front/lib/screens/shared/public_user_profile_screen.dart`
- `Front/lib/screens/shared/public_tourist_profile_screen.dart`

---

## 8. Validation effectuée

### Vérifications réalisées

- Vérification d'erreurs après chaque série de modifications majeures.
- Validation Flutter/Dart sur les écrans et services modifiés.
- Validation des nouveaux imports et des nouveaux fichiers ajoutés.

### Point d'attention

Les validations réalisées ont confirmé l'absence d'erreurs statiques sur les fichiers modifiés, mais certains flux restent à confirmer manuellement en exécution complète :

- envoi vocal sur appareil réel,
- navigation complète entre profils publics,
- données publiques exposées selon le rôle utilisateur.

---

## Résumé final

Le 14 mars 2026 a principalement permis de:

- stabiliser la messagerie texte/audio/vidéo,
- moderniser l'expérience d'enregistrement vocal,
- introduire une vraie navigation entre profils publics,
- remplacer plusieurs écrans statiques par des écrans dynamiques,
- aligner les profils publics sur les nouvelles maquettes fournies.
