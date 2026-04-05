# Chapitre 2 : Analyse et spécification des besoins

---

## 2.1 Introduction

L'analyse et la spécification des besoins représentent l'une des étapes les plus déterminantes du cycle de vie d'un projet informatique. Elles permettent de délimiter le périmètre fonctionnel du système à concevoir, d'identifier les problématiques auxquelles il doit apporter des réponses, et de traduire les attentes des parties prenantes en exigences formelles et mesurables.

Dans le cadre du présent travail, le projet **DJTrip** constitue une plateforme numérique dédiée au secteur touristique à Djerba, en Tunisie. Cette application vise à mettre en relation les touristes désireux de découvrir des activités locales authentiques avec les organisateurs locaux qui proposent ces expériences. Le projet repose sur une architecture full-stack composée d'un serveur backend **Node.js / Express / MongoDB** et d'une application mobile développée avec le framework **Flutter**, offrant un ensemble cohérent de fonctionnalités allant de la gestion des activités touristiques à la messagerie instantanée en temps réel.

Dans ce chapitre, nous procédons dans un premier temps à une étude de l'existant afin d'analyser les solutions actuellement disponibles sur le marché du tourisme numérique. Nous en dégageons ensuite les insuffisances afin de légitimer l'apport de notre solution. Nous effectuons alors une spécification rigoureuse des besoins fonctionnels et non fonctionnels, accompagnée de l'identification des acteurs du système et de la description des cas d'utilisation. Nous concluons ce chapitre par la présentation de la méthodologie de développement retenue.

---

## 2.2 Étude de l'existant

Avant de définir et de concevoir notre solution, il est indispensable d'examiner le paysage des plateformes de tourisme numérique existantes. De nombreuses applications et services en ligne permettent aujourd'hui aux voyageurs de découvrir, de réserver et d'évaluer des expériences touristiques à travers le monde.

On distingue deux grandes catégories de solutions :

- **Les plateformes touristiques mondiales** : des acteurs majeurs tels que TripAdvisor, Viator ou Airbnb Experiences, qui agrègent des offres d'activités à l'échelle internationale. Ces plateformes bénéficient de bases d'utilisateurs considérables et d'une infrastructure technologique robuste, mais demeurent généralistes et peu adaptées aux contextes régionaux spécifiques.

- **Les applications locales génériques** : des solutions développées à l'échelle nationale ou régionale pour promouvoir le tourisme de proximité. Bien qu'elles offrent une meilleure adéquation géographique, elles accusent souvent un retard en termes de maturité technologique, d'ergonomie et de fonctionnalités avancées telles que la messagerie ou les systèmes d'évaluation.

Ces solutions font émerger plusieurs problématiques communes dans le contexte du tourisme à Djerba :

- L'absence de spécialisation sur le marché touristique tunisien et djerbien en particulier ;
- Le manque d'interactions directes entre les touristes et les organisateurs locaux ;
- L'absence d'un système de communication en temps réel intégré à la plateforme ;
- La difficulté pour les petits organisateurs locaux à se faire référencer et à promouvoir leurs offres ;
- Des interfaces peu adaptées à une clientèle internationale et multilingue.

---

### 2.2.1 Analyse de solutions existantes

Afin d'illustrer ces constats, nous présentons ci-après l'analyse comparative de trois plateformes représentatives du marché.

---

#### Solution 1 : TripAdvisor

> **Description** : TripAdvisor est l'une des plateformes de voyage les plus utilisées à l'échelle mondiale. Elle permet aux voyageurs de consulter des avis d'autres utilisateurs sur des hébergements, des restaurants et des activités touristiques, et de comparer les offres disponibles.

| Critères | Évaluation |
|---|---|
| **Interface utilisateur** | Riche, mais parfois surchargée |
| **Fonctionnalités** | Avis, comparatifs, réservations via partenaires |
| **Performance** | Bonne (infrastructure cloud mondiale) |
| **Sécurité** | Robuste (authentification sociale intégrée) |
| **Couverture locale** | Faible concentration sur Djerba et la Tunisie |

**✅ Avantages :**
- Base d'utilisateurs très large, avec des millions d'avis disponibles
- Système de notation et d'évaluation avancé
- Disponible sur toutes les plateformes (web, iOS, Android)

**❌ Inconvénients :**
- Absence d'interaction directe entre le touriste et l'organisateur local
- Absence de messagerie en temps réel intégrée
- Très faible visibilité accordée aux petits organisateurs tunisiens
- Interface orientée comparaison de prix, non adaptée à la gestion d'activités

---

#### Solution 2 : Viator

> **Description** : Viator est une plateforme de réservation d'activités et d'expériences touristiques, filiale de TripAdvisor. Elle met en relation des voyageurs avec des prestataires locaux à travers le monde.

| Critères | Évaluation |
|---|---|
| **Interface utilisateur** | Moderne et intuitive |
| **Fonctionnalités** | Réservation, annulation, orientation |
| **Paiement en ligne** | Intégré (Stripe, PayPal) |
| **Portée géographique** | Internationale |
| **Personnalisation** | Limitée pour l'organisateur |

**✅ Avantages :**
- Circuit de réservation simple et fiable
- Système de paiement sécurisé intégré
- Politique d'annulation claire et transparente

**❌ Inconvénients :**
- Commission élevée prélevée sur chaque réservation (de 15 à 30 %)
- Autonomie très limitée de l'organisateur concernant la présentation de ses activités
- Absence de messagerie directe entre le touriste et l'organisateur
- Absence de gestion des archives et de l'historique des activités

---

#### Solution 3 : Airbnb Experiences

> **Description** : Airbnb a élargi son offre aux « Experiences », permettant à des particuliers et à des professionnels de proposer des activités uniques dans une destination donnée.

**✅ Avantages :**
- Interface épurée et esthétique, offrant une excellente expérience utilisateur
- Mise en valeur du profil de l'organisateur
- Processus de validation garantissant un niveau de qualité minimal

**❌ Inconvénients :**
- Processus d'inscription long et sélectif pour les organisateurs locaux
- Absence de messagerie instantanée de type chat — uniquement des échanges de messages standards
- Absence de gestion différenciée des statuts de réservation (en attente, approuvée, refusée)
- Aucun système de notification par courriel ou par notification push natif

---

## 2.3 Critique de l'existant

L'analyse comparative des solutions présentées dans la section précédente met en évidence des lacunes structurelles qui justifient pleinement la conception et le développement d'une plateforme spécialisée telle que **DJTrip**.

Les principales insuffisances identifiées sont les suivantes :

- **Absence de spécialisation locale** : Aucune des solutions analysées n'est dédiée spécifiquement à l'île de Djerba et à son écosystème touristique particulier. Les organisateurs djerbiens peinent à s'y faire référencer efficacement, tandis que les touristes n'ont pas accès à une offre locale structurée et certifiée.

- **Manque de communication directe** : Les plateformes existantes ne proposent pas de messagerie instantanée entre touristes et organisateurs. Or, dans un contexte touristique local, la capacité à négocier, personnaliser et confirmer rapidement une activité constitue un facteur essentiel de satisfaction. DJTrip pallie cette lacune en intégrant une messagerie en temps réel fondée sur **Socket.io**, prenant en charge les messages de type texte, image, audio et vidéo.

- **Contrôle insuffisant accordé aux organisateurs** : Sur les plateformes tierces, les prestataires locaux ne disposent que d'une marge de personnalisation très réduite. Ils ne sont pas en mesure de gérer aisément les statuts de leurs réservations (en attente, approuvée, refusée, annulée), d'archiver leurs activités passées, ni de consulter en temps réel des indicateurs de participation.

- **Gestion des réservations non différenciée** : Les plateformes actuelles ne distinguent pas clairement les réservations annulées à l'initiative du touriste de celles rejetées par l'organisateur, ce qui nuit à la transparence des échanges et au suivi de l'historique.

- **Évaluations non liées aux participations effectives** : Sur la majorité des plateformes concurrentes, tout internaute peut publier un avis sans avoir participé à l'activité concernée. DJTrip impose qu'un avis ne puisse être soumis que par un touriste disposant d'une réservation préalablement **approuvée**, garantissant ainsi l'authenticité et la fiabilité des évaluations.

- **Absence de cartographie locale intégrée** : Les plateformes généralistes ne proposent pas de module de cartographie interactive dédié aux destinations locales. DJTrip intègre un module **Lieux** complet, permettant de recenser les points d'intérêt de Djerba (Plages, Musées, Villages, Nature) avec leurs coordonnées GPS et leurs liens avec des activités correspondantes.

---

## 2.4 Solution proposée

Forts des enseignements tirés de l'analyse critique de l'existant, nous proposons le développement de **DJTrip** — une plateforme mobile full-stack dédiée à la mise en relation des touristes et des organisateurs d'activités sur l'île de Djerba, en Tunisie.

### Objectifs de la solution

La plateforme DJTrip vise à atteindre les objectifs suivants :

- **Centraliser l'offre touristique djerbienne** en permettant aux organisateurs locaux de publier, de gérer et de promouvoir leurs activités — visites guidées, excursions, randonnées, sports nautiques, gastronomie, culture — au sein d'une seule et même plateforme dédiée.

- **Fluidifier le processus de réservation** en offrant aux touristes un parcours ergonomique de découverte, d'inscription et de suivi de leurs réservations, avec une gestion explicite des statuts : en attente, confirmée, refusée ou annulée.

- **Faciliter la communication directe et en temps réel** entre touristes et organisateurs, grâce à une messagerie instantanée intégrée reposant sur **Socket.io** et prenant en charge les messages texte, images, fichiers audio et vidéo.

- **Renforcer la confiance des utilisateurs** au moyen d'un système d'évaluation conditionné à une participation effective, d'une authentification sécurisée par **JWT** et d'une protection active contre les attaques par force brute.

- **Valoriser le territoire djerbien** à travers un module de cartographie interactive recensant les points d'intérêt de l'île : plages, musées, villages, sites naturels.

- **Offrir aux organisateurs un espace de gestion complet** leur permettant de piloter leurs activités, de traiter les demandes d'inscription, d'approuver ou de refuser des réservations, et d'archiver leurs événements passés.

### Stack technologique

| Couche | Technologie |
|---|---|
| **Backend** | Node.js 18+, Express 5, MongoDB / Mongoose |
| **Authentification** | JWT (access token 15 min + refresh token 7 j), bcrypt |
| **Communication temps réel** | Socket.io 4 (messagerie + signaling WebRTC) |
| **Stockage des fichiers** | Cloudinary (photos de profil, d'activités et de messagerie) |
| **Sécurité** | Helmet, mongo-sanitize, express-rate-limit, Joi |
| **Frontend mobile** | Flutter (Dart) |
| **Gestion d'état** | Provider (Flutter) |
| **Cache** | CacheManager (Hive + mémoire vive, TTL 5 min) |
| **Base de données** | MongoDB Atlas (cloud) |

### Architecture générale

DJTrip repose sur une architecture **client-serveur RESTful** enrichie d'une couche de communication en temps réel :

- Le client Flutter communique avec le serveur via des requêtes HTTP/REST exposées sous le préfixe `/api/v1/*`.
- La messagerie instantanée est assurée par **Socket.io** via le protocole WebSocket.
- Les fichiers multimédias (photos, pièces jointes) sont hébergés et servis par **Cloudinary**.
- Un système de cache côté client — fondé sur **CacheManager** et **Hive** — réduit les appels réseau redondants et assure un fonctionnement partiel en mode hors-ligne.
- Le modèle de données MongoDB tire parti du pattern **Discriminator** pour gérer l'héritage entre les entités `User`, `Touriste` et `Organisator`.

---

## 2.5 Spécifications des besoins

La spécification des besoins constitue la traduction formelle des attentes fonctionnelles et qualitatives du système. On distingue classiquement deux catégories : les besoins fonctionnels, qui décrivent ce que le système doit accomplir, et les besoins non fonctionnels, qui précisent les contraintes de qualité et de performance auxquelles il doit se conformer.

---

### 2.5.1 Besoins fonctionnels

Les besoins fonctionnels décrivent l'ensemble des services et des traitements que le système DJTrip doit être en mesure d'assurer. Ils ont été identifiés par une analyse approfondie du code source — modèles MongoDB, contrôleurs, routes API et écrans Flutter — ainsi que des documents de spécification du projet.

---

**🔐 Gestion des utilisateurs et authentification**

- Le système doit permettre à un utilisateur de créer un compte en sélectionnant son rôle : **Touriste** ou **Organisateur**.
- Lors de l'inscription, le système doit envoyer un courriel de vérification et interdire l'accès aux ressources protégées tant que l'adresse électronique n'a pas été confirmée.
- Le système doit permettre la connexion par identifiant et mot de passe, avec génération d'un jeton d'accès JWT (valide 15 minutes) et d'un jeton de rafraîchissement (valide 7 jours).
- Le système doit prendre en charge la connexion via Google OAuth 2.0.
- Après cinq tentatives d'authentification infructueuses, le système doit verrouiller temporairement le compte concerné et imposer un délai de déverrouillage, afin de protéger la plateforme contre les attaques par force brute.
- Le système doit permettre la réinitialisation du mot de passe par l'envoi d'un code de vérification par courriel.
- Le système doit permettre la déconnexion de l'utilisateur avec invalidation immédiate du jeton de session actif.
- Le système doit permettre à chaque utilisateur de gérer son profil personnel : nom, âge, numéro de téléphone, pays, langue préférée, biographie, photo de profil et centres d'intérêt.

---

**🎯 Gestion des activités (Organisateur)**

- Le système doit permettre à un organisateur de créer une activité en renseignant : titre, description, type (Guided Tour, Excursion, Hiking, Adventure, Culture, Gastronomy, Sport, Other…), lieu, coordonnées GPS (optionnelles), durée, tarif, capacité maximale, langues disponibles, niveau de difficulté, équipements fournis, liste des objets à apporter, photos et dates de disponibilité.
- Le système doit permettre à un organisateur de modifier ou de supprimer ses activités existantes.
- Le système doit permettre à un organisateur de consulter l'ensemble de ses activités selon leur statut : actives, terminées ou archivées.
- Le système doit permettre à un organisateur de consulter le nombre de réservations enregistrées et la note moyenne de chacune de ses activités.
- Le système doit permettre à un organisateur d'archiver une activité lorsqu'elle est terminée.

---

**🧳 Découverte et réservation d'activités (Touriste)**

- Le système doit proposer aux touristes un catalogue d'activités actives, filtrable par catégorie, type, lieu et langue.
- Le système doit permettre au touriste de consulter le détail d'une activité : description, galerie photos, localisation, tarif, profil de l'organisateur et avis des participants.
- Le système doit permettre au touriste de soumettre une demande de réservation en précisant le nombre de participants et, optionnellement, un message à l'attention de l'organisateur.
- Le système doit calculer automatiquement le montant total de la réservation en fonction du nombre de participants et du tarif unitaire de l'activité.
- Le système doit permettre au touriste de suivre le statut de ses réservations : **en attente**, **approuvée**, **refusée** ou **annulée**.
- Le système doit permettre au touriste d'annuler une réservation dont le statut est encore « en attente ».
- Le système doit permettre au touriste d'ajouter des activités à sa liste de favoris.

---

**📋 Gestion des demandes de réservation (Organisateur)**

- Le système doit notifier l'organisateur lors de l'arrivée d'une nouvelle demande de réservation.
- Le système doit permettre à l'organisateur d'approuver ou de refuser une demande de réservation, avec la possibilité d'y joindre un message explicatif.
- Le système doit mettre à jour automatiquement le compteur de réservations de l'activité concernée à chaque approbation.
- Le système doit fournir à l'organisateur des indicateurs statistiques sur ses demandes, ventilées par statut : en attente, approuvées, refusées et annulées.

---

**⭐ Système d'évaluations**

- Le système doit permettre à un touriste disposant d'une réservation **approuvée** de soumettre un avis comprenant une note de 1 à 5 étoiles et un commentaire textuel, portant sur une activité ou sur un organisateur.
- Le système doit garantir l'unicité des évaluations : un touriste ne peut soumettre qu'un seul avis par activité et par organisateur.
- Le système doit recalculer automatiquement la note moyenne de chaque activité et de chaque organisateur à chaque nouvel avis soumis.

---

**💬 Messagerie en temps réel**

- Le système doit permettre une communication instantanée entre touristes et organisateurs via une messagerie en temps réel fondée sur **Socket.io**.
- Le système doit prendre en charge les types de messages suivants : texte, image, audio et vidéo.
- Le système doit gérer les états de lecture des messages : lu / non lu, avec horodatage de la lecture.
- Le système doit permettre à l'expéditeur de modifier un message après son envoi.
- Le système doit afficher la liste des conversations actives en mettant en évidence les messages non lus.
- Le système doit permettre les appels audio et vidéo entre utilisateurs, au moyen de la couche de signaling WebRTC gérée via Socket.io.

---

**🗺️ Module Lieux et destinations**

- Le système doit exposer un catalogue de lieux touristiques de l'île de Djerba — Plages, Musées, Villages, Nature, Autres — enrichi de photos, descriptions, notes, coordonnées GPS et activités associées.
- Le système doit permettre l'affichage de ces lieux sur une carte interactive.
- Le système doit permettre le filtrage des lieux par catégorie et mettre en avant les destinations les plus populaires.

---

**⚙️ Administration**

- Le système doit permettre à un administrateur de gérer les comptes utilisateurs : consultation, suspension, réactivation et bannissement.
- Le système doit permettre à un administrateur de gérer le catalogue de lieux touristiques : création, modification et suppression.
- Le système doit permettre à un administrateur de modérer les activités et les contenus publiés sur la plateforme.
- Le système doit permettre à un administrateur de consulter les statistiques globales de la plateforme.

---

### 2.5.2 Besoins non fonctionnels

Les besoins non fonctionnels définissent les contraintes de qualité, de performance et de sécurité auxquelles le système DJTrip doit se conformer, indépendamment des fonctionnalités métier qu'il implémente.

---

**🔒 Sécurité**

La sécurité des données et des communications constitue une priorité fondamentale dans la conception de DJTrip. Les mesures suivantes ont été mises en œuvre :

- **Authentification par jetons JWT** : les jetons d'accès ont une durée de validité courte (15 minutes) et sont renouvelés automatiquement via des jetons de rafraîchissement (7 jours). Le champ `tokenVersion` présent dans le modèle `User` permet l'invalidation immédiate de l'ensemble des jetons émis, notamment lors d'un changement de mot de passe ou d'une déconnexion globale.
- **Hachage des mots de passe** : les mots de passe sont chiffrés au moyen de la bibliothèque **bcryptjs**, avec application d'un salage robuste.
- **Protection contre les attaques courantes** : le module **Helmet** sécurise les en-têtes HTTP de chaque réponse ; **mongo-sanitize** neutralise les tentatives d'injection NoSQL (opérateurs `$` et `.`) ; **express-rate-limit** limite les tentatives répétées sur les endpoints d'authentification.
- **Verrouillage de compte** : après cinq tentatives d'authentification infructueuses, le compte est temporairement verrouillé. Ce comportement est modélisé par les champs `loginAttempts` et `lockUntil` du modèle `User`.
- **Vérification de l'adresse électronique** : tout nouveau compte doit confirmer son adresse email avant d'accéder aux ressources protégées de la plateforme.
- **Chiffrement des communications** : en environnement de production, l'ensemble des échanges entre le client Flutter et le serveur doit être chiffré via le protocole **HTTPS/TLS**.
- **Contrôle d'accès basé sur les rôles (RBAC)** : les permissions sont différenciées selon le type d'utilisateur (Touriste, Organisateur, Administrateur), déterminé par le champ discriminant `userType` dans MongoDB.

---

**⚡ Performance**

- Le système doit répondre aux requêtes API en moins de **500 millisecondes** dans 95 % des cas.
- Le temps de démarrage de l'application mobile doit être inférieur à **2 secondes**.
- L'envoi d'une photo (profil ou activité) vers le serveur doit s'effectuer en moins de **3 secondes** sur une connexion 4G.
- Le client Flutter intègre un **CacheManager** hybride — combinant un cache mémoire vive et un cache persistant **Hive** avec une durée de validité (TTL) de 5 minutes — afin de réduire les appels réseau redondants et d'assurer un affichage quasi-instantané des données déjà consultées.
- Le cache est automatiquement invalidé lors de toute opération de mutation (POST, PUT, DELETE), garantissant ainsi la cohérence des données affichées.
- Des index MongoDB ont été définis sur les champs à forte sollicitation — `type_activite`, `statut`, `organisateur_id`, `touriste_id` — ainsi qu'un index full-text sur les champs `titre`, `lieu` et `description`, afin d'optimiser les performances des requêtes de filtrage et de recherche.

---

**🖥️ Ergonomie et accessibilité**

- L'application mobile Flutter doit proposer une interface conforme aux principes du **Material Design 3**, avec des animations fluides à 60 images par seconde.
- L'interface doit être cohérente, intuitive et accessible à une clientèle touristique internationale, y compris les utilisateurs non francophones.
- Le système doit proposer une sélection parmi **49 langues** dans le profil utilisateur et parmi **195 pays** dans le sélecteur de nationalité.
- Tous les éléments interactifs doivent respecter une taille minimale de 44 × 44 pixels, conformément aux recommandations d'accessibilité **WCAG AA**.
- Le système doit fournir des retours visuels immédiats à chaque action utilisateur : indicateurs de chargement, messages de succès ou d'erreur, barres de notification (*snackbars*).

---

**🌐 Disponibilité**

- Le backend doit viser un taux de disponibilité d'au moins **99 %**.
- En cas d'indisponibilité du réseau, l'application mobile doit afficher les données préalablement mises en cache, assurant ainsi un fonctionnement dégradé partiel en mode hors-ligne.
- Le système doit intégrer un mécanisme de **réessai automatique** avec backoff exponentiel (500 ms → 1 s → 2 s, avec un maximum de deux tentatives), implémenté dans le composant `NetworkHelper` du client Flutter.

---

**🔧 Maintenabilité**

- Le code du serveur backend doit respecter une séparation stricte des responsabilités, suivant le découpage : **Routes → Contrôleurs → Services → Modèles**.
- Toutes les données reçues sont validées côté serveur via la bibliothèque **Joi** préalablement à tout traitement métier.
- Le frontend Flutter s'appuie sur le patron architectural **BaseDataScreen** afin d'uniformiser la gestion des états courants (chargement, erreur, liste vide) sur l'ensemble des écrans de données.
- L'intégralité des variables sensibles — secrets JWT, clés d'accès Cloudinary, URI MongoDB — est externalisée dans des fichiers `.env`, conformément aux bonnes pratiques de sécurité.

---

**📦 Portabilité**

- L'application mobile DJTrip doit être compatible avec les systèmes **Android** (API niveau 21 et supérieur) et **iOS** (iOS 12 et supérieur).
- Le backend Node.js doit pouvoir être déployé indifféremment sur des plateformes d'hébergement cloud (Railway, Render, AWS, etc.) ou sur des serveurs physiques dédiés (*on-premise*).

---

## 2.6 Identification des acteurs

Dans le contexte de la modélisation du système DJTrip, un **acteur** désigne toute entité externe — personne, système tiers ou service automatisé — qui interagit avec la plateforme en vue d'atteindre un objectif précis. L'identification des acteurs s'appuie directement sur le modèle de données du projet, lequel utilise le patron de conception **Discriminator de MongoDB** (`userType`) pour distinguer les différents profils d'utilisateurs héritant d'un modèle `User` commun.

On distingue deux catégories d'acteurs :

- **Les acteurs primaires** : ils interagissent directement et activement avec le système.
- **Les acteurs secondaires** : ils participent au fonctionnement du système de manière indirecte, via des services automatiques ou des composants tiers.

| Acteur | Catégorie | Rôle et responsabilités |
|---|---|---|
| **Touriste** | Primaire | Découvre les activités touristiques proposées à Djerba, effectue des réservations, suit leur statut (en attente / approuvée / refusée / annulée), soumet des avis, communique avec les organisateurs via la messagerie, consulte la carte des lieux et gère son profil personnel (centres d'intérêt, langue, pays d'origine). |
| **Organisateur** | Primaire | Crée et administre ses activités (création, modification, archivage), traite les demandes de réservation (approbation / refus), consulte les indicateurs de participation, échange avec les touristes via la messagerie en temps réel et gère son profil professionnel. |
| **Administrateur** | Primaire | Supervise l'ensemble de la plateforme : gestion des comptes utilisateurs (suspension, réactivation, bannissement), modération des activités et des contenus publiés, gestion du catalogue de lieux touristiques, consultation des statistiques globales de la plateforme. |
| **Système** | Secondaire | Assure les traitements automatisés : génération et renouvellement des jetons JWT, envoi des courriels de vérification et de réinitialisation de mot de passe, verrouillage des comptes après tentatives excessives, mise à jour des statuts, calcul des moyennes des évaluations et gestion des notifications Socket.io. |
| **Cloudinary** | Secondaire | Service externe de stockage et de traitement des fichiers multimédias (photos de profil, photos d'activités, pièces jointes de messagerie). Il reçoit les envois de fichiers, les redimensionne automatiquement et retourne des URL publiques pérennes. |

---

## 2.7 Cas d'utilisation

### Introduction

Un **cas d'utilisation** (*Use Case*) décrit une interaction concrète entre un acteur et le système DJTrip en vue d'accomplir un objectif métier précis. Les cas d'utilisation présentés dans cette section ont été identifiés directement à partir de l'analyse du code source : routes API, contrôleurs, modèles de données et écrans de l'application Flutter.

---

### UC-01 — S'inscrire et choisir son type de compte

| Champ | Description |
|---|---|
| **Identifiant** | UC-01 |
| **Intitulé** | S'inscrire sur la plateforme DJTrip |
| **Acteurs** | Touriste, Organisateur |
| **Objectif** | Créer un compte utilisateur et accéder aux fonctionnalités de la plateforme |
| **Préconditions** | L'utilisateur dispose d'une adresse électronique valide, non encore enregistrée dans le système |
| **Postconditions** | Un compte est créé avec le rôle sélectionné (Touriste ou Organisateur), un courriel de vérification est expédié et un jeton JWT est généré |
| **Déclencheur** | L'utilisateur appuie sur « S'inscrire » depuis l'écran d'accueil de l'application |

**Scénario nominal :**
1. L'utilisateur ouvre l'application et accède à l'écran d'inscription.
2. Il saisit son nom complet, son adresse électronique et son mot de passe.
3. Il sélectionne son type de compte : **Touriste** ou **Organisateur**.
4. Il soumet le formulaire.
5. Le système vérifie l'unicité de l'adresse électronique et la conformité du mot de passe aux critères de sécurité.
6. Le système crée le compte, génère un code de vérification et en envoie un courriel à l'utilisateur.
7. Le système génère un jeton d'accès JWT et un jeton de rafraîchissement.
8. L'utilisateur est redirigé vers l'écran de vérification de son adresse électronique.

**Scénarios d'erreur :**
- **E1** — L'adresse électronique est déjà associée à un compte existant → le système affiche un message d'erreur et invite l'utilisateur à se connecter.
- **E2** — Le mot de passe ne satisfait pas les critères de sécurité requis → le système affiche les règles de composition à respecter.
- **E3** — L'utilisateur ne procède pas à la vérification de son adresse électronique → l'accès aux ressources protégées lui est refusé jusqu'à validation.

---

### UC-02 — Se connecter

| Champ | Description |
|---|---|
| **Identifiant** | UC-02 |
| **Intitulé** | Se connecter à son compte DJTrip |
| **Acteurs** | Touriste, Organisateur, Administrateur |
| **Objectif** | Accéder à la plateforme et obtenir un jeton d'accès valide |
| **Préconditions** | L'utilisateur possède un compte vérifié et actif |
| **Postconditions** | Un jeton d'accès JWT et un jeton de rafraîchissement sont générés et stockés localement sur l'appareil. L'utilisateur est redirigé vers son tableau de bord |
| **Déclencheur** | L'utilisateur appuie sur « Se connecter » |

**Scénario nominal :**
1. L'utilisateur saisit son adresse électronique et son mot de passe.
2. Le système vérifie la validité des identifiants.
3. Le système s'assure que le compte n'est pas verrouillé (moins de cinq tentatives échouées en cours).
4. Le système génère un jeton d'accès (15 min) et un jeton de rafraîchissement (7 jours).
5. Les jetons sont stockés dans le composant `SharedPreferences` du client Flutter.
6. L'utilisateur est redirigé vers son tableau de bord selon son rôle : `TouristMainScreen` pour le Touriste, `OrganizerMainScreen` pour l'Organisateur.

**Scénarios d'erreur :**
- **E1** — Identifiants incorrects → le compteur `loginAttempts` est incrémenté.
- **E2** — Compte verrouillé après cinq tentatives → le système affiche le délai restant avant déverrouillage.
- **E3** — Compte suspendu ou banni → un message informatif est présenté à l'utilisateur.

---

### UC-03 — Créer une activité (Organisateur)

| Champ | Description |
|---|---|
| **Identifiant** | UC-03 |
| **Intitulé** | Créer et publier une activité touristique |
| **Acteur** | Organisateur |
| **Objectif** | Proposer une nouvelle activité visible par les touristes dans le catalogue |
| **Préconditions** | L'organisateur est authentifié et son adresse électronique est vérifiée |
| **Postconditions** | L'activité est créée avec le statut `active`, associée à l'organisateur et visible dans le catalogue des touristes |
| **Déclencheur** | L'organisateur appuie sur « + Créer une activité » depuis son onglet principal |

**Scénario nominal :**
1. L'organisateur accède au formulaire de création d'activité (`create_activity_screen.dart`).
2. Il renseigne l'ensemble des informations requises : titre, description, type (Guided Tour, Excursion, Hiking…), lieu, coordonnées GPS optionnelles (saisies via le sélecteur de carte `map_picker_screen.dart`), durée, tarif par personne, capacité maximale, langues disponibles, niveau de difficulté (Easy / Moderate / Difficult / Expert), équipements fournis, liste des objets à apporter et galerie de photos.
3. Il sélectionne une ou plusieurs dates de disponibilité.
4. Il soumet le formulaire.
5. Le système valide les données au moyen de Joi côté serveur, puis enregistre l'activité en base de données avec le statut `active`.
6. L'activité apparaît dans l'onglet « Mes activités » de l'organisateur ainsi que dans le catalogue accessible aux touristes.

**Scénarios d'erreur :**
- **E1** — Des champs obligatoires sont absents → le système retourne une erreur de validation et en informe l'organisateur.
- **E2** — Une image dépasse la taille maximale autorisée → le serveur rejette l'envoi et notifie l'organisateur.

---

### UC-04 — Réserver une activité (Touriste)

| Champ | Description |
|---|---|
| **Identifiant** | UC-04 |
| **Intitulé** | Soumettre une demande de réservation pour une activité touristique |
| **Acteur** | Touriste |
| **Objectif** | Formuler une demande de participation à une activité proposée par un organisateur |
| **Préconditions** | Le touriste est authentifié ; l'activité est à l'état `active` ; la capacité maximale n'est pas atteinte |
| **Postconditions** | Une demande de réservation est créée avec le statut `en_attente`. Le montant total est calculé. L'organisateur est notifié. |
| **Déclencheur** | Le touriste appuie sur « Réserver » depuis la page de détail d'une activité |

**Scénario nominal :**
1. Le touriste consulte le détail d'une activité depuis l'écran d'exploration (`explore_tab.dart`).
2. Il sélectionne le nombre de participants et, le cas échéant, saisit un message à l'intention de l'organisateur.
3. Il confirme sa demande via l'écran de sélection (`booking_selection_screen.dart`).
4. Le système calcule le montant total : `prix_total = prix × nombre_participants`.
5. Une réservation est créée en base de données avec le statut `en_attente`.
6. L'organisateur reçoit une notification relative à la nouvelle demande.
7. Le touriste est redirigé vers l'écran de confirmation (`booking_confirmation_screen.dart`).

**Scénarios d'erreur :**
- **E1** — La capacité maximale de l'activité est atteinte → la demande est refusée avec un message explicatif.
- **E2** — L'activité est passée à l'état inactif entre la consultation et la confirmation → la demande est rejetée et le touriste est redirigé vers le catalogue.

---

### UC-05 — Traiter une demande de réservation (Organisateur)

| Champ | Description |
|---|---|
| **Identifiant** | UC-05 |
| **Intitulé** | Approuver ou refuser une demande de réservation |
| **Acteur** | Organisateur |
| **Objectif** | Statuer sur la participation d'un touriste à l'une de ses activités |
| **Préconditions** | Une réservation au statut `en_attente` existe pour l'une des activités de l'organisateur |
| **Postconditions** | Le statut de la réservation est mis à jour (`approuvee` ou `refusee`). La date de réponse est enregistrée. Le touriste est notifié. |
| **Déclencheur** | L'organisateur consulte l'onglet « Demandes » (`requests_tab.dart`) |

**Scénario nominal :**
1. L'organisateur consulte la liste de ses demandes en attente.
2. Il sélectionne une demande et examine le profil du touriste ainsi que les détails de la réservation.
3. Il choisit d'**approuver** ou de **refuser** la demande, avec la possibilité d'y joindre un message explicatif.
4. Le système invoque la méthode `approuver()` ou `refuser()` du modèle `Inscription`.
5. Le statut de la réservation est mis à jour, la date de réponse (`date_reponse`) est enregistrée, et le compteur `nombre_reservations` de l'activité est incrémenté en cas d'approbation.
6. Le touriste reçoit une notification l'informant de la décision.

**Scénarios d'erreur :**
- **E1** — La demande a déjà été traitée → le système avertit l'organisateur que le statut ne peut plus être modifié.
- **E2** — Une erreur serveur survient → un message d'erreur est affiché avec la possibilité de réessayer l'opération.

---

### UC-06 — Soumettre un avis sur une activité

| Champ | Description |
|---|---|
| **Identifiant** | UC-06 |
| **Intitulé** | Évaluer une activité ou un organisateur |
| **Acteur** | Touriste |
| **Objectif** | Soumettre une évaluation (note de 1 à 5 étoiles et commentaire) à l'issue d'une participation |
| **Préconditions** | Le touriste dispose d'une réservation au statut `approuvee` pour l'activité concernée et n'a pas encore soumis d'avis à son sujet |
| **Postconditions** | Un avis est enregistré ; la note moyenne de l'activité et de l'organisateur est recalculée automatiquement |
| **Déclencheur** | Le touriste accède à la section « Mes réservations » et sélectionne une réservation confirmée |

**Scénario nominal :**
1. Le touriste consulte ses réservations approuvées depuis l'écran de détail (`booking_detail_screen.dart`).
2. Il accède au formulaire d'évaluation.
3. Il attribue une note de 1 à 5 étoiles et rédige un commentaire (facultatif, limité à 1 000 caractères).
4. Il soumet l'avis.
5. Le système vérifie l'absence d'un avis antérieur pour cette activité par ce touriste (unicité garantie par un index MongoDB).
6. L'avis est persisté. Le système recalcule les champs `note_moyenne` et `nombre_avis` de l'activité et de l'organisateur.

**Scénarios d'erreur :**
- **E1** — Un avis a déjà été soumis → le système informe le touriste qu'une évaluation existe déjà pour cette activité.
- **E2** — La réservation n'est pas au statut `approuvee` → l'accès au formulaire d'évaluation est refusé.

---

### UC-07 — Échanger via la messagerie en temps réel

| Champ | Description |
|---|---|
| **Identifiant** | UC-07 |
| **Intitulé** | Communiquer via la messagerie instantanée |
| **Acteurs** | Touriste, Organisateur |
| **Objectif** | Échanger des messages en temps réel avec un autre utilisateur de la plateforme |
| **Préconditions** | Les deux utilisateurs sont authentifiés et connectés à la socket |
| **Postconditions** | Le message est persisté en base de données, transmis en temps réel au destinataire et marqué comme non lu |
| **Déclencheur** | L'utilisateur accède à l'écran de messagerie et ouvre ou initie une conversation |

**Scénario nominal :**
1. L'utilisateur accède à l'onglet « Réseau » (`screen_network.dart`).
2. Il sélectionne une conversation existante ou initie un nouveau contact.
3. Il compose un message texte ou joint un fichier multimédia (image, audio ou vidéo).
4. Le message est transmis au serveur via **Socket.io**.
5. Le serveur le persiste dans MongoDB et le diffuse en temps réel au destinataire.
6. L'état `is_read` du message est mis à jour lors de sa lecture par le destinataire, avec enregistrement de l'horodatage.

**Scénarios d'erreur :**
- **E1** — La connexion réseau est interrompue → le message ne peut être transmis et l'utilisateur est averti.
- **E2** — Le fichier joint dépasse la taille autorisée → l'envoi est rejeté et un message d'erreur est affiché.

---

### Récapitulatif des cas d'utilisation

| Identifiant | Intitulé | Acteur(s) |
|---|---|---|
| UC-01 | S'inscrire et choisir son type de compte | Touriste, Organisateur |
| UC-02 | Se connecter à la plateforme | Tous les utilisateurs |
| UC-03 | Créer et publier une activité | Organisateur |
| UC-04 | Réserver une activité | Touriste |
| UC-05 | Traiter une demande de réservation | Organisateur |
| UC-06 | Soumettre un avis | Touriste |
| UC-07 | Communiquer via la messagerie | Touriste, Organisateur |
| UC-08 | Gérer son profil personnel | Touriste, Organisateur |
| UC-09 | Consulter la carte des lieux touristiques | Touriste |
| UC-10 | Administrer la plateforme et les utilisateurs | Administrateur |

---

## 2.8 Méthodologie adoptée

### Aperçu des approches méthodologiques

Le choix d'une méthodologie de développement est une décision fondamentale qui conditionne l'organisation du travail, la qualité des livrables et la capacité de l'équipe à s'adapter aux évolutions des exigences. Deux grandes familles méthodologiques coexistent dans le domaine du génie logiciel :

- **Les méthodologies prédictives** (cycle en V, modèle en cascade) : elles reposent sur une planification exhaustive réalisée en amont du développement et sur une exécution rigoureusement séquentielle des phases. Bien qu'adaptées aux projets dont le périmètre est clairement défini et stable, elles se révèlent peu résilientes face à des besoins changeants.

- **Les méthodologies agiles** : héritières du **Manifeste Agile** (2001), elles privilégient la livraison itérative de valeur fonctionnelle, la collaboration étroite avec les parties prenantes et la capacité d'adaptation au changement. Parmi les cadres agiles les plus répandus figurent **Scrum**, **Kanban** et **XP (eXtreme Programming)**.

### Méthodologie retenue : Scrum

Dans le cadre du projet DJTrip, le cadre **Scrum** a été retenu pour les raisons suivantes :

- La nature multi-modulaire du projet — plateforme intégrant l'authentification, la gestion des activités, les réservations, la messagerie et les lieux — nécessite une approche itérative permettant de livrer des incréments fonctionnels à chaque sprint et d'ajuster les priorités selon les retours obtenus.
- Les besoins ont évolué significativement au cours du projet (intégration de la messagerie WebRTC, refonte du module de réservations, implémentation du système de cache), rendant indispensable l'adoption d'une méthode capable d'absorber ces changements sans remettre en cause l'ensemble de la planification initiale.
- La taille réduite de l'équipe de développement est parfaitement compatible avec les pratiques du cadre Scrum.

### Rôles dans l'équipe projet

| Rôle | Description |
|---|---|
| **Product Owner** | Définit et priorise les éléments du backlog produit ; valide les fonctionnalités livrées à chaque fin de sprint |
| **Scrum Master** | Veille au respect du processus Scrum, lève les obstacles rencontrés par l'équipe et facilite les cérémonies |
| **Équipe de développement** | Conçoit, développe, teste et livre les incréments fonctionnels de DJTrip |

### Cérémonies Scrum

- **Sprint Planning** : réunion de planification au début de chaque sprint pour sélectionner et estimer les éléments du backlog à réaliser.
- **Daily Scrum** : point de synchronisation quotidien de l'équipe (15 minutes au maximum) portant sur les avancées et les obstacles rencontrés.
- **Sprint Review** : présentation des fonctionnalités développées aux parties prenantes à l'issue de chaque sprint.
- **Sprint Retrospective** : analyse du sprint écoulé en vue d'identifier les axes d'amélioration du processus de développement.

### Planification des sprints du projet DJTrip

| Sprint | Durée | Principales fonctionnalités réalisées |
|---|---|---|
| **Sprint 0** | 1 semaine | Initialisation du projet · Configuration du backend Node.js / Express / MongoDB · Mise en place du projet Flutter · Définition des schémas de données (User, Touriste, Organisateur, Activité, Inscription, Avis, Message, Lieu) |
| **Sprint 1** | 2 semaines | Module Authentification complet (inscription, connexion, vérification email, Google OAuth, renouvellement de jeton, déconnexion) · Gestion du profil utilisateur (intégration, centres d'intérêt, sélecteur de pays et de langue) |
| **Sprint 2** | 2 semaines | Module Activités (CRUD organisateur, catalogue et exploration touriste, filtres, recherche full-text) · Module Réservations (soumission, gestion des statuts, approbation et refus) |
| **Sprint 3** | 2 semaines | Module Avis et évaluations · Module Messagerie en temps réel (Socket.io, types de messages, états de lecture) · Module Lieux (catalogue, carte interactive, filtrage par catégorie) |
| **Sprint 4** | 2 semaines | Optimisation des performances (CacheManager, NetworkHelper, BaseDataScreen) · Module Administration · Campagne de tests et corrections · Finalisation de l'interface utilisateur (thème méditerranéen) |

---

## 2.9 Conclusion

Ce chapitre a établi les fondations analytiques et spécificatives du projet **DJTrip**, une plateforme mobile de tourisme connectant touristes et organisateurs d'activités sur l'île de Djerba, en Tunisie.

L'étude de l'existant a permis de confronter les principales solutions du marché — TripAdvisor, Viator, Airbnb Experiences — à la réalité du tourisme local djerbien, révélant des insuffisances structurelles communes : absence de spécialisation géographique, manque de communication directe entre les acteurs, contrôle limité accordé aux organisateurs, et évaluations déconnectées des participations effectives.

Sur la base de ces constats, la solution **DJTrip** a été présentée avec ses objectifs fondateurs : centralisation de l'offre touristique locale, gestion complète du cycle de vie des réservations avec suivi de statut, messagerie instantanée en temps réel, évaluations conditionnées à une participation vérifiée, et cartographie interactive des destinations djerbiennes.

La spécification rigoureuse des besoins, tant fonctionnels — authentification, gestion des activités, réservations, évaluations, messagerie, lieux, administration — que non fonctionnels — sécurité JWT/bcrypt, temps de réponse inférieur à 500 ms, cache à durée de validité limitée, conformité Material Design 3, disponibilité cible de 99 % — a été directement dérivée de l'analyse du code source du projet.

L'identification de cinq acteurs (Touriste, Organisateur, Administrateur, Système et Cloudinary) et la description de dix cas d'utilisation permettent de délimiter avec précision le périmètre fonctionnel de la plateforme et les interactions qui s'y déroulent.

Enfin, l'adoption du cadre **Scrum** et l'organisation du développement en cinq sprints ont garanti une progression itérative, adaptative et maîtrisée tout au long du projet.

Le chapitre suivant sera consacré à la **conception du système**, dans lequel les spécifications définies ici seront traduites en modèles architecturaux, diagrammes de classes et diagrammes de séquences UML.

---

*Fin du Chapitre 2 — Projet DJTrip*
