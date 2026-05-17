# Chapitre 2 : Analyse et spécification des besoins

---

## 2.1 Introduction

L’analyse et la spécification des besoins constituent une étape fondamentale et déterminante dans le cycle de vie de tout projet de développement logiciel, en particulier pour un Projet de Fin d’Études (PFE). Cette phase permet de structurer la vision globale de l’application, de comprendre les attentes réelles des futurs utilisateurs et de délimiter rigoureusement le périmètre technique et fonctionnel du système à concevoir. Une spécification claire évite les dérives de développement et garantit que les choix architecturaux futurs seront parfaitement alignés avec les besoins métiers.

Dans le cadre de ce projet, **DJTrip** est conçu comme une plateforme numérique innovante et intégrée dédiée au tourisme dans l’île de Djerba (Tunisie). L’application a pour mission de connecter directement les touristes (nationaux et internationaux) avec les organisateurs locaux d’activités de loisirs, sportives, culturelles et gastronomiques. Le système s'articule autour d'une architecture moderne comprenant :
- Un backend robuste en **Node.js / Express / MongoDB** hautement sécurisé ;
- Un frontend mobile multiplateforme performant développé sous **Flutter (Dart)** pour les touristes et les organisateurs ;
- Un tableau de bord d’administration complet en **React / Vite / Material-UI** destiné au suivi opérationnel, financier et modérateur.

L'objectif de ce chapitre est de mener une étude critique des solutions existantes afin d'en dégager les forces et les faiblesses, de formaliser les besoins fonctionnels et non fonctionnels du projet, d'identifier précisément les acteurs et de modéliser les interactions du système via des diagrammes de cas d'utilisation UML. Enfin, nous décrirons la méthodologie agile **Scrum** adoptée pour piloter efficacement la réalisation de cette plateforme.

---

## 2.2 Étude de l'existant

Pour concevoir une solution pertinente et compétitive, il convient d'analyser l'état de l'art des solutions numériques de gestion de voyages et d'activités touristiques. De nombreuses plateformes mondiales et locales dominent le secteur technologique du tourisme en ligne (e-tourisme). L'étude de ces systèmes permet d'identifier les standards ergonomiques attendus par les voyageurs contemporains et d'analyser comment ces outils s'insèrent dans l'expérience utilisateur globale.

---

### 2.2.1 Analyse d'une solution existante : TripAdvisor

**TripAdvisor** est la plus grande plateforme d'orientation et de planification de voyages au monde. Fondée sur la contribution des utilisateurs (User-Generated Content), elle centralise des centaines de millions d'avis, d'opinions et de photos concernant des hôtels, des restaurants, des vols, des croisières et des activités touristiques (attractions et expériences).

#### Mode de fonctionnement et Services
TripAdvisor fonctionne principalement comme un agrégateur d’informations et un comparateur de prix. Les utilisateurs (voyageurs) y recherchent des destinations, consultent les notes et avis de la communauté, et comparent les tarifs d'hôtels ou d'activités. Bien que TripAdvisor permette la réservation d'excursions, celle-ci s'effectue généralement par le biais de redirections vers sa filiale spécialisée **Viator** ou d'autres partenaires affiliés.

```
[Touriste] ──(Recherche & Filtres)──> [ TripAdvisor ] ──(Avis & Comparatif)──> [ Redirection / Réservation ]
```

#### Évaluation de la solution
Le tableau suivant présente une évaluation multicritère de la plateforme TripAdvisor sur une échelle qualitative :

| Critères d'évaluation | Niveau d’adéquation | Justification technique et fonctionnelle |
| :--- | :---: | :--- |
| **Interface utilisateur (UI/UX)** | **Moyen** | Très riche en informations, mais souvent surchargée d'encarts publicitaires et de liens de redirection complexes. |
| **Fonctionnalités métier** | **Très Bon** | Excellent système d’avis enrichis, filtres avancés par notes, budgets et types d'attractions. |
| **Performance technique** | **Excellent** | Infrastructure cloud mondiale (AWS) assurant un temps de réponse minimal et une haute disponibilité. |
| **Sécurité et Authentification** | **Excellent** | Protocoles d'authentification robustes, SSO (Google, Apple, Facebook), conformité RGPD. |
| **Couverture & Visibilité Locale** | **Faible** | Faible pénétration du marché local à Djerba pour les petits prestataires informels ou spécialisés. |

#### Avantages et Limites de TripAdvisor

**Les points forts (Avantages) :**
- **Notoriété et volume de données** : Une communauté active mondiale fournissant un volume colossal d'avis de confiance et de retours d'expérience.
- **Référencement global** : Permet aux grandes structures hôtelières et aux agences d'excursions établies d'avoir une vitrine internationale incontournable.
- **Richesse de la recherche** : Algorithmes de recommandation matures basés sur les préférences historiques et la géolocalisation.

**Les points faibles (Limites) :**
- **Absence de communication directe en temps réel** : Pas de chat instantané intégré entre le voyageur et le guide/organisateur local. Les échanges se font par e-mails asynchrones ou formulaires génériques.
- **Frais de commission élevés** : Les intermédiaires (Viator/TripAdvisor) prélèvent des commissions importantes (souvent entre 20% et 30%), ce qui pénalise lourdement les artisans et guides locaux de Djerba.
- **Avis falsifiables** : N'importe quel utilisateur peut rédiger un avis sur un lieu sans obligation d'avoir effectivement acheté ou participé à l'activité, ce qui favorise les faux avis (positifs comme négatifs).
- **Faible réactivité pour les ajustements** : Impossible pour un organisateur d'adapter son itinéraire en temps réel ou de proposer des activités sur-mesure de manière dynamique.

---

## 2.3 Critique de l'existant

L’analyse de la solution TripAdvisor, complétée par l'observation des autres géants du secteur (comme Airbnb Experiences ou Viator), met en évidence plusieurs limites structurelles majeures. Ces défaillances constituent des opportunités fonctionnelles pour le projet **DJTrip** :

1. **L’absence d'ancrage local et de spécialisation géographique** :
   Les plateformes mondiales traitent Djerba comme une sous-destination mineure. Elles mettent en avant les grands complexes hôteliers et les excursions standards (telles que les balades en bateau pirate), au détriment de l'artisanat d'art (poterie de Guellala), des visites historiques (synagogue de la Ghriba, mosquées souterraines) ou des randonnées écologiques au cœur de l'île. Les petits guides locaux indépendants se retrouvent totalement invisibilisés par les algorithmes de classement favorisant les acteurs à gros budgets.

2. **Le cloisonnement de la communication (Manque d'interactivité en temps réel)** :
   Aujourd'hui, un touriste souhaitant personnaliser sa sortie ou poser une question rapide sur les conditions météorologiques doit passer par des emails impersonnels ou chercher le numéro de téléphone externe du prestataire. L'absence d'une messagerie instantanée fluide (chat) et d'un système d'appels audio/vidéo intégré au sein de l'application nuit gravement à la réactivité et au taux de conversion des réservations.

3. **Le manque de fiabilité et de vérifiabilité des avis (Problème de confiance)** :
   La prolifération des faux avis nuit à la crédibilité des plateformes existantes. Sur TripAdvisor, le processus d'évaluation n'est pas conditionné à un acte d'achat vérifié. N'importe quel compte peut saboter la réputation d'un concurrent ou gonfler artificiellement sa propre note.

4. **Des processus opérationnels rigides pour les professionnels locaux** :
   Les solutions existantes n'offrent pas d'outils de terrain pour les guides et organisateurs locaux. Il n'y a pas de système de billetterie électronique avec contrôle d'accès sur site (comme un scan de QR code de réservation par l'organisateur via son smartphone), obligeant les prestataires à imprimer des listes ou à vérifier des reçus papier fastidieux.

5. **Des politiques financières contraignantes** :
   Les délais de reversement de fonds par les plateformes internationales sont longs et les commissions sont prohibitives pour l'économie locale tunisienne. Les organisateurs locaux ont besoin d'un système qui protège leurs revenus tout en offrant aux touristes des méthodes de paiement sécurisées et modernes (telles que Stripe) avec gestion automatisée des remboursements en cas d'annulation justifiée.

---

## 2.4 Solution proposée

Pour combler ces lacunes, nous proposons la plateforme **DJTrip**, une solution mobile et web spécifiquement conçue pour l'écosystème touristique de l'île de Djerba. DJTrip ne se contente pas d'être un simple annuaire d'activités, mais se positionne comme un système d'exploitation touristique complet qui valorise les interactions directes, la confiance et l'efficacité opérationnelle.

```
┌────────────────────────────────────────────────────────────────────────┐
│                              DJTrip App                                │
├──────────────────────────┬───────────────────────────┬─────────────────┤
│    Touriste (Flutter)    │   Organisateur (Flutter)  │  Admin (React)  │
├──────────────────────────┴───────────────────────────┴─────────────────┤
│   - Messagerie temps réel & Appels multimédias (Socket.io & WebRTC)    │
│   - Réservations & Paiements Stripe hautement sécurisés (Wallet TND)    │
│   - Check-in mobile instantané par QR Code sécurisé                    │
│   - Itinéraires interactifs multilocations géo-référencés              │
│   - Système d'avis certifiés liés à une participation effective        │
│   - Cache hybride (Hive + RAM) pour un mode hors-ligne fluide          │
└────────────────────────────────────────────────────────────────────────┘
```

### Valeur ajoutée de DJTrip :
* **Messagerie instantanée & Appels intégrés** : Grâce à une intégration native de **Socket.io** et du protocole **WebRTC**, les touristes et les organisateurs peuvent s'envoyer des messages texte, des photos, des mémos vocaux et des vidéos, ou initier des appels audio/vidéo directs pour planifier et personnaliser leurs sorties.
* **Réservations & Paiement Sécurisé (Stripe)** : Un cycle complet de paiement et de réservation avec gestion automatisée des statuts (*pending, approved, rejected, cancelled, verified*). En cas d'annulation conforme à la charte, les fonds sont recrédités de façon sécurisée ou gérés via un solde de portefeuille interne (*Wallet*).
* **Système de Check-in par QR Code** : À l'approbation d'une réservation, un jeton cryptographique QR unique est généré. Le jour de l'activité, l'organisateur scanne ce QR code via l'appareil photo de son smartphone (grâce au module *MobileScanner* de l’application Flutter) pour valider immédiatement et de façon sécurisée la présence du voyageur.
* **Avis certifiés** : Le système empêche techniquement la publication d'un avis si le touriste ne possède pas une inscription validée (*verified* ou *checked-in*) pour l'activité concernée, assurant ainsi une transparence et une véracité absolue des notes affichées.
* **Itinéraires géolocalisés avancés** : Les activités peuvent être configurées sous trois formats de localisation : fixe (avec coordonnées GPS exactes affichées sur une carte interactive Google Maps), personnalisée (lieu d'accueil variable) ou sous forme d'itinéraire multi-étapes avec repères cartographiques successifs (*itinerary*).
* **Robustesse technique et Mode Hors-ligne** : Afin de pallier les problèmes de connexion internet fréquente dans certaines zones reculées de Djerba (plages sauvages, pistes désertiques), l’application mobile intègre un cache intelligent (**CacheManager** reposant sur la base de données locale **Hive**) combiné à un mécanisme de réessai réseau transparent (**NetworkHelper** avec backoff exponentiel).

---

## 2.5 Spécifications des besoins

Les besoins du système DJTrip se divisent en exigences fonctionnelles (les actions que le système doit exécuter) et en exigences non fonctionnels (les attributs de qualité, de sécurité et de performance de l'application).

---

### 2.5.1 Besoins fonctionnels

Les spécifications fonctionnelles décrivent en détail le comportement attendu de l'application DJTrip pour chaque pan métier de la plateforme.

#### 1. Authentification, Inscription et Onboarding
* **Création de compte à rôles distincts** : L'inscription doit exiger le choix d'un profil : **Touriste** ou **Organisateur**. Pour les organisateurs, l'accès à la création d'activités reste gelé jusqu'à l'approbation administrative du compte (champ `is_approved` et soumission du champ `reasonToJoin`).
* **Vérification double canal** : Envoi automatique d'un code OTP par e-mail lors de l'inscription. L'utilisateur ne peut pas requérir de ressources sécurisées si l'adresse e-mail n'est pas marquée `emailVerified: true`.
* **Authentification multi-sources** : Connexion classique par e-mail/mot de passe sécurisé (chiffrement *bcryptjs* avec salage) et intégration de la connexion sociale **Google OAuth 2.0** et **Facebook Login**.
* **Protection contre le piratage par force brute** : Après 5 tentatives de connexion erronées successives, le compte utilisateur doit être automatiquement verrouillé pendant un intervalle configurable (champs `loginAttempts` et `lockUntil` du modèle Mongo).
* **Récupération de compte** : Processus d'oubli de mot de passe sécurisé par code de réinitialisation temporaire envoyé par messagerie électronique.

#### 2. Gestion des Profils et Confidentialité
* **Édition de profil** : Personnalisation des données (nom, bio, photo de profil et de couverture hébergées sur Cloudinary, numéro de téléphone avec indicatif pays, pays d'origine parmi 195 choix et langues parlées).
* **Centres d'intérêt** : Sélection de thématiques touristiques par le touriste (Aventure, Culture, Détente, etc.) pour alimenter les futures recommandations.
* **Contrôle granulaire de la vie privée (Privacy Settings)** : Possibilité de masquer/afficher le statut en ligne (`isOnline`), la dernière heure de connexion (`lastActiveAt`), le numéro de téléphone, l'adresse e-mail et de bloquer des utilisateurs importuns (`blockedUsers`).

#### 3. Catalogue et Gestion des Activités (Organisateur)
* **Création d'activité enrichie** : Formulaire complet permettant de spécifier le titre (max 100 caractères), la description détaillée (max 2000 caractères), le type d'activité (choix parmi *Guided Tour, Excursion, Hiking, Adventure, Culture, Gastronomy, Sport, Other*), le tarif, la durée (en heures), la capacité maximale de participants, les langues de guidage, les équipements inclus, les éléments à apporter, les photos promotionnelles et les plages de dates disponibles.
* **Configurations géographiques** :
  * *Fixed* : Point GPS exact sur la carte Google Maps.
  * *Custom* : Point de rencontre déterminé à la volée.
  * *Itinerary* : Tableau ordonné d'étapes géolocalisées avec titres et descriptions d'étapes.
* **Cycle de vie de l'activité** : Possibilité d'activer, désactiver, modifier (si aucune réservation n'est en attente ou approuvée), terminer ou archiver une activité.

#### 4. Recherche, Exploration et Favoris (Touriste)
* **Recherche textuelle performante** : Moteur de recherche basé sur un index textuel MongoDB filtrant par titre, lieu et description.
* **Filtrage multicritères** : Recherche d'activités par type, catégorie de lieu, tranche de prix, niveau de difficulté (*Easy, Moderate, Difficult, Expert*), dates et langues de l'organisateur.
* **Favoris & Bookmarks** : Ajout d'activités à une liste de souhaits personnelle, avec synchronisation temps réel de l'état du bouton favori.

#### 5. Cycle de Réservation et Gestion Financière
* **Demande de réservation** : Sélection du nombre de participants, de la date souhaitée, et saisie d'un message optionnel à l'organisateur.
* **Calcul et vérification des chevauchements (Overlap Check)** : Le système doit exécuter un contrôle automatique en base de données pour vérifier si le touriste a déjà une autre réservation confirmée ou en attente sur la même plage horaire afin d'éviter les doubles réservations conflictuelles.
* **Intégration Stripe** : Paiement en ligne sécurisé via l'API Stripe Checkout. Les fonds sont sécurisés par la plateforme.
* **Gestion des annulations** : Politique d'annulation dynamique (calcul automatique des frais et des montants à rembourser, alimentation du solde de portefeuille *wallet_balance* de l'utilisateur).
* **Scan et Validation QR** : L'organisateur utilise la caméra intégrée de son application mobile pour scanner le QR Code crypté du touriste. Le backend décode le jeton JWT du QR code, vérifie la signature, marque la réservation comme `verified` (utilisée) et enregistre l'heure de présence (`qr_used_at`).

#### 6. Messagerie Instantanée Multimédia et Appels
* **Messagerie Socket.io** : Échanges en temps réel de messages textes (modifiables et supprimables), d'images, de fichiers audio (notes vocales) et de vidéos.
* **Indicateurs de présence** : Suivi des statuts de lecture (*delivered, read* avec heure précise), indicateur d'écriture en cours (*typing indicator*), et archivage/sourdine/suppression unilatérale des conversations.
* **Appels Voix et Vidéo WebRTC** : Possibilité d'établir une liaison audio/vidéo peer-to-peer en temps réel en utilisant le serveur Socket.io comme serveur de signalisation (signaling).

#### 7. Système d'Avis et Recommandations
* **Soumission d'avis verrouillée** : Le touriste ne peut évaluer (note de 1 à 5 étoiles et commentaire textuel de max 1000 caractères) une activité ou un organisateur que si sa réservation a été marquée comme validée sur site.
* **Mise à jour statistique** : Recalcul automatique et immédiat de la note moyenne (`note_moyenne`) et du nombre total d'avis (`nombre_avis`) de l'activité et du profil public de l'organisateur dès la validation d'une nouvelle note.

#### 8. Notifications et Alertes
* **Push Notifications (FCM)** : Notifications push gérées via *Firebase Cloud Messaging* sur les terminaux mobiles pour les événements majeurs (nouveau message, demande de réservation, acceptation/refus de réservation, rappel d'activité 24h avant).
* **Notifications In-App** : Centre de notifications interne avec possibilité de marquer comme lu ou de supprimer l'historique d'alertes.

#### 9. Espace Administration (Web Admin Dashboard)
* **Modération des utilisateurs** : Consultation, suspension temporaire avec motif, bannissement définitif ou réactivation des comptes touristes et organisateurs.
* **Approbation des organisateurs** : Examen des candidatures des nouveaux organisateurs locaux avant de leur donner les droits de publication.
* **Gestion des Lieux Touristiques** : Outil CRUD complet pour alimenter le catalogue des points d'intérêt de Djerba (Plages, Musées, Villages, Nature) avec leurs coordonnées GPS.
* **Modération des contenus & Litiges** : Suppression d'activités frauduleuses ou d'avis non conformes, résolution des demandes de remboursement manuelles.

---

### 2.5.2 Besoins non fonctionnels

Les besoins non fonctionnels caractérisent les aspects qualitatifs, structurels et techniques indispensables à la viabilité à long terme de DJTrip.

#### 1. Sécurité et Intégrité des Données
* **Double Jeton JWT** : Sécurisation des requêtes API via une authentification par jeton. Utilisation d'un couple `accessToken` court (15 minutes) et `refreshToken` long (7 jours) stocké de façon sécurisée (avec vérification du champ `tokenVersion` pour révoquer instantanément les sessions lors d'une déconnexion ou d'un changement de mot de passe).
* **Protection NoSQL & Injection** : Utilisation du middleware `mongo-sanitize` pour bloquer les tentatives d'injections de requêtes via les opérateurs MongoDB, et du validateur de schéma `Joi` pour vérifier chaque donnée entrante sur le serveur.
* **Protection HTTP** : Implémentation du module `Helmet` pour sécuriser les en-têtes de réponses HTTP et de règles de limitation de débit (`express-rate-limit`) pour contrer les attaques par déni de service (DDoS) et de brute force.

#### 2. Performance et Réactivité
* **Temps de latence réseau** : 95% des requêtes API HTTP GET doivent être traitées en moins de 300 millisecondes côté serveur.
* **Cachage Client Hybride** : Implémentation de `CacheManager` combinant un cache RAM ultra-rapide (<1ms) et un cache persistant sur base locale Hive. La durée de vie (TTL) par défaut est de 5 minutes pour les requêtes de lecture (GET), avec invalidation intelligente immédiate lors des opérations d'écriture (POST, PUT, DELETE) sur la même collection.
* **Optimisation de Base de Données** : Indexation stratégique sur MongoDB (index composites sur les statuts et identifiants, index géospatiaux 2d pour la recherche cartographique de proximité, index plein texte sur les activités).

#### 3. Ergonomie, Accessibilité et Portabilité
* **UI/UX Premium (Material Design 3)** : L'interface utilisateur mobile doit être moderne, fluide (rendu à 60 FPS constants), intégrant des micro-animations interactives et des palettes harmonieuses inspirées de l'environnement méditerranéen de Djerba.
* **Accessibilité** : Respect des standards WCAG 2.1 AA (contraste de couleurs adéquat, zones de clic d'au moins 44x44 pixels pour les écrans tactiles).
* **Internationalisation** : Support multi-langues et adaptabilité aux différents formats de numéros de téléphone mondiaux.
* **Compatibilité Multiplateforme** : Le code source Flutter doit compiler et s'exécuter sans régression majeure sur Android (API 21+) et iOS (iOS 12+). Le site d'administration doit être entièrement "responsive" et compatible avec les principaux navigateurs (Chrome, Safari, Firefox, Edge).

#### 4. Disponibilité et Tolérance aux Pannes (Fiabilité)
* **Disponibilité du Serveur** : Le serveur d'API et la base de données MongoDB Atlas doivent garantir un taux de disponibilité mensuel de **99.9%**.
* **Mode Dégradé (Offline)** : En cas de coupure de réseau internet, l’application mobile ne doit pas planter ni afficher d'écran d'erreur bloquant. Elle doit automatiquement basculer sur l'affichage des dernières données valides stockées en cache local (Hive) et avertir discrètement l'utilisateur.
* **Mécanisme de Résilience Réseau** : Intégration de `NetworkHelper` assurant jusqu'à deux tentatives de réessais automatiques avec un délai de temporisation exponentiel lors d'erreurs réseau temporaires (Timeouts, erreurs 502/503).

---

## 2.6 Identification des acteurs

Dans le cadre de la modélisation UML du système DJTrip, un acteur représente toute entité externe qui interagit avec le système. L'identification claire des acteurs permet de déterminer les rôles et les responsabilités au sein de l'écosystème de la plateforme. En se basant sur l'architecture et les modèles de données, nous identifions les acteurs suivants :

### 1. Acteurs Primaires (Interaction directe)

* **Le Touriste** :
  C'est l'utilisateur final qui voyage et cherche des expériences uniques à Djerba. Il interagit avec l'application mobile Flutter pour explorer les activités, consulter la carte des lieux d'intérêt, réaliser des réservations, payer en ligne, communiquer avec les organisateurs par chat ou appels, afficher son QR code pour l'embarquement et publier des avis.

* **L’Organisateur** :
  C'est un guide, un artisan, une agence de loisirs ou un prestataire de services local basé à Djerba. Il utilise l'application mobile Flutter pour créer et publier des activités (avec descriptifs et itinéraires géo-référencés), gérer le calendrier des disponibilités, approuver ou refuser les demandes d'inscription, scanner les QR codes des touristes le jour de l'activité, et communiquer en direct avec ses clients.

* **L’Administrateur (Admin)** :
  C'est le gestionnaire central de la plateforme DJTrip. Depuis le tableau de bord web React, il valide l'inscription des organisateurs locaux, modère le catalogue général des activités, gère les fiches des lieux d'intérêt de l'île, traite les blocages/suspensions de comptes utilisateurs, analyse les indicateurs financiers et statistiques, et résout les éventuels litiges.

### 2. Acteurs Secondaires (Services externes et processus automatiques)

* **Le Système** :
  Composant interne automatisé (exécuté par le serveur Node.js, les tâches planifiées Cron et les files d'attente Redis/BullMQ). Il gère l'envoi des e-mails OTP, le verrouillage des comptes suspects, le calcul automatique des notes moyennes, le nettoyage des jetons expirés et la mise à jour des statuts des réservations passées.

* **Stripe (Passerelle de Paiement)** :
  Service externe sécurisé assurant le traitement des transactions bancaires, la conservation temporaire des fonds (séquestre) et l'exécution des ordres de remboursement vers les cartes bancaires des touristes en cas d'annulation.

* **Cloudinary (Serveur de Stockage Multimédia)** :
  Service tiers de stockage cloud d'images et de vidéos. Il reçoit les flux médias téléversés depuis l'application Flutter et renvoie des liens URL optimisés et sécurisés au backend DJTrip.

* **Firebase Cloud Messaging (FCM)** :
  Service externe de Google utilisé pour propager instantanément les notifications push système vers les smartphones des touristes et des organisateurs, que l'application soit ouverte ou fermée.

---

## 2.7 Diagrammes du cas d'utilisation

Un diagramme de cas d'utilisation UML structure les exigences fonctionnelles en représentant les relations entre les acteurs et les différents cas d'utilisation du système. Afin d'offrir une vision claire et ciblée, nous présentons le modèle fonctionnel de DJTrip découpé par acteur principal.

---

### 2.7.1 Diagramme de cas d'utilisation de l'administrateur

L'administrateur supervise le bon fonctionnement technique, éthique et commercial de la plateforme. Ses cas d'utilisation englobent la gestion des utilisateurs, des contenus et le suivi statistique.

```mermaid
useCaseDiagram
    rect float
        note "Système DJTrip - Espace Administration (Dashboard React)"
    end

    actor Admin as "Administrateur de la Plateforme"
    actor Stripe as "Stripe (Système Financier)"

    usecase UC_Admin_Login as "Se connecter à l'espace Admin"
    usecase UC_Manage_Users as "Gérer les comptes utilisateurs (Activer, Suspendre, Bannir)"
    usecase UC_Approve_Org as "Valider les candidatures des Organisateurs"
    usecase UC_Mod_Content as "Modérer les Activités et Avis signalés"
    usecase UC_Manage_Lieux as "Gérer le catalogue des Lieux Touristiques (CRUD)"
    usecase UC_View_Stats as "Visualiser les Statistiques & Journaux système (Logs)"
    usecase UC_Resolve_Refunds as "Traiter les litiges de paiement & Remboursements"

    Admin --> UC_Admin_Login
    Admin --> UC_Manage_Users
    Admin --> UC_Approve_Org
    Admin --> UC_Mod_Content
    Admin --> UC_Manage_Lieux
    Admin --> UC_View_Stats
    Admin --> UC_Resolve_Refunds

    UC_Resolve_Refunds --> Stripe : "<<interagit avec>>"
```

---

### 2.7.2 Diagramme de cas d'utilisation du touriste

Le touriste est orienté vers la découverte, la réservation d'excursions locales et la socialisation. Ses cas d'utilisation intègrent la recherche, le paiement sécurisé, le chat en temps réel et l'évaluation.

```mermaid
useCaseDiagram
    rect float
        note "Système DJTrip - Espace Touriste (Application Mobile Flutter)"
    end

    actor Touriste as "Touriste"
    actor Stripe as "Stripe (Paiement)"
    actor Cloudinary as "Cloudinary"

    usecase UC_Register as "S'inscrire (Vérification E-mail)"
    usecase UC_Login as "Se connecter (Classique / Google)"
    usecase UC_Search as "Rechercher & Filtrer les Activités / Lieux"
    usecase UC_Book as "Réserver une Activité (Vérification de chevauchements)"
    usecase UC_Pay as "Payer la réservation via Stripe"
    usecase UC_Cancel_Booking as "Annuler une réservation"
    usecase UC_Manage_Profile as "Gérer son profil & Paramètres de confidentialité"
    usecase UC_Chat as "Discuter par chat en temps réel (Texte, Audio, Vidéo)"
    usecase UC_Call as "Passer un appel Voix/Vidéo (WebRTC)"
    usecase UC_Review as "Laisser un avis (Uniquement si présence validée)"
    usecase UC_Favs as "Gérer ses favoris (Activités)"

    Touriste --> UC_Register
    Touriste --> UC_Login
    Touriste --> UC_Search
    Touriste --> UC_Book
    Touriste --> UC_Manage_Profile
    Touriste --> UC_Chat
    Touriste --> UC_Call
    Touriste --> UC_Review
    Touriste --> UC_Favs

    UC_Book ..> UC_Pay : "<<include>>"
    UC_Pay --> Stripe : "<<exécute>>"
    UC_Cancel_Booking --> Stripe : "<<crédite wallet/carte>>"
    Touriste --> UC_Cancel_Booking
    
    UC_Manage_Profile --> Cloudinary : "<<téléverse médias>>"
    UC_Chat --> Cloudinary : "<<téléverse pièces jointes>>"
```

---

### 2.7.3 Diagramme de cas d'utilisation de l'organisateur

L'organisateur pilote son offre commerciale et assure le contrôle opérationnel sur le terrain. Ses cas d'utilisation sont centrés sur l'édition d'activités, la validation des réservations et la communication avec ses clients.

```mermaid
useCaseDiagram
    rect float
        note "Système DJTrip - Espace Organisateur (Application Mobile Flutter)"
    end

    actor Organisateur as "Organisateur Local"
    actor Cloudinary as "Cloudinary"
    actor FCM as "Firebase Cloud Messaging"

    usecase UC_Org_Onboard as "Soumettre sa candidature d'Organisateur"
    usecase UC_Create_Activity as "Créer / Publier une Activité (Fixe, Custom ou Itinéraire)"
    usecase UC_Edit_Activity as "Modifier / Archiver ses Activités"
    usecase UC_Manage_Bookings as "Traiter les demandes de réservation (Approuver / Refuser)"
    usecase UC_Scan_QR as "Scanner et valider le QR Code de présence (Check-in)"
    usecase UC_Chat_Client as "Discuter avec les clients (Chat instantané)"
    usecase UC_Call_Client as "Passer un appel Voix/Vidéo (WebRTC)"
    usecase UC_View_Stats_Org as "Consulter son tableau de bord d'activités & revenus"

    Organisateur --> UC_Org_Onboard
    Organisateur --> UC_Create_Activity
    Organisateur --> UC_Edit_Activity
    Organisateur --> UC_Manage_Bookings
    Organisateur --> UC_Scan_QR
    Organisateur --> UC_Chat_Client
    Organisateur --> UC_Call_Client
    Organisateur --> UC_View_Stats_Org

    UC_Create_Activity --> Cloudinary : "<<téléverse photos>>"
    UC_Manage_Bookings ..> FCM : "<<déclenche notification push au touriste>>"
```

---

## 2.8 Planification du projet et Méthodologie adoptée

Pour mener à bien le développement de la plateforme DJTrip dans les délais impartis tout en garantissant un niveau de qualité élevé, il s'est avéré nécessaire de choisir une méthodologie de conduite de projet rigoureuse, collaborative et réactive.

---

### 2.8.1 Définition de Scrum

**Scrum** est le cadre méthodologique agile le plus populaire pour la gestion et la réalisation de projets complexes. Issu du génie logiciel, Scrum est une approche itérative et incrémentale. Contrairement aux approches prédictives classiques (comme le cycle en cascade ou le cycle en V) qui exigent de figer l'intégralité des spécifications au démarrage, Scrum accepte le changement comme une composante naturelle d'un projet et s'attache à livrer régulièrement des versions fonctionnelles et testées du produit, appelées **Incréments**.

---

### 2.8.2 Principes de base de Scrum

La méthodologie Scrum repose sur trois piliers fondamentaux :
1. **La transparence** : Toutes les informations concernant le projet (objectifs, blocages, avancement) sont partagées et visibles par tous les membres de l'équipe.
2. **L'inspection** : L'équipe analyse régulièrement l'état d'avancement des livrables et le fonctionnement du processus de travail pour identifier les écarts par rapport aux objectifs.
3. **L'adaptation** : Si l'inspection révèle des dérives ou des opportunités d'amélioration, le processus ou les priorités du produit sont immédiatement ajustés.

Le développement est rythmé par des cycles de travail courts de durée fixe (généralement de 1 à 4 semaines), appelés **Sprints**. Chaque sprint s'articule autour de quatre cérémonies rituelles :

```
[ Backlog Produit ] ──(Planification)──> [ Backlog du Sprint ] ──> [ Sprint (1-2 semaines) ] ──> [ Incrément Fonctionnel ]
                                                                          │
                                                                   (Daily Standup)
```

* **Le Sprint Planning (Planification du Sprint)** : Réunion au cours de laquelle l'équipe sélectionne les fonctionnalités prioritaires du *Product Backlog* (liste globale des besoins) pour les intégrer au *Sprint Backlog* (objectifs spécifiques du cycle à venir).
* **Le Daily Scrum (Mêlée Quotidienne)** : Point de synchronisation de 15 minutes par jour où chaque développeur explique ce qu'il a fait la veille, ce qu'il compte faire aujourd'hui et les obstacles qui freinent son travail.
* **Le Sprint Review (Revue du Sprint)** : Démonstration de l'incrément logiciel potentiellement livrable réalisée à la fin du sprint devant les parties prenantes pour recueillir leurs retours.
* **Le Sprint Retrospective (Rétrospective)** : Réunion interne visant à analyser le déroulement du sprint écoulé (relations humaines, outils, processus techniques) afin d'identifier des axes d'amélioration pour le sprint suivant.

---

### 2.8.3 Pourquoi Scrum ?

Le choix de Scrum pour le projet **DJTrip** est motivé par plusieurs facteurs stratégiques :
* **Développement multi-modules complexe** : Le projet intègre de nombreux sous-systèmes techniques complexes (WebSocket en temps réel, signalisation WebRTC pour appels vocaux/vidéo, paiement sécurisé Stripe, scanner de QR code, double système de cache client Hive/RAM). Développer tout cela en une seule fois sans étapes intermédiaires aurait présenté un risque d'intégration trop élevé. Scrum a permis de livrer et de stabiliser chaque brique logicielle pas à pas.
* **Capacité d'adaptation** : Au fil du projet, des ajustements ergonomiques et techniques ont été nécessaires (ex: amélioration de la gestion d'état Flutter en passant à Provider, intégration du validateur de numéros de téléphone par pays). Scrum nous a offert la souplesse nécessaire pour intégrer ces évolutions sans perturber le plan global.
* **Visibilité continue** : Grâce aux démonstrations régulières en fin de sprint, l'avancement concret de l'application mobile et du tableau de bord d'administration a pu être validé en continu, garantissant une convergence rapide vers le produit final désiré.

---

### 2.8.4 Équipes et rôles

La réussite de la méthodologie Scrum repose sur une définition claire des responsabilités au sein de l'équipe de projet :

* **Le Product Owner (PO)** :
  Représente la voix du client et des utilisateurs. Il est responsable de maximiser la valeur du produit développé. Ses missions consistent à rédiger les *User Stories* (récits utilisateurs), à maintenir et prioriser le *Product Backlog*, et à valider la conformité des fonctionnalités présentées lors des revues de sprint.
  
* **Le Scrum Master (SM)** :
  Garant de l'application correcte du cadre Scrum. Il agit comme un coach et un facilitateur pour l'équipe de développement. Son rôle principal est d'éliminer les obstacles techniques ou organisationnels qui freinent l'équipe, de protéger les développeurs des interférences externes et d'animer les différentes cérémonies agiles.
  
* **L’Équipe de Développement (Development Team)** :
  Groupe pluridisciplinaire de professionnels (concepteurs, développeurs full-stack, testeurs) chargé de transformer les éléments du backlog en incréments de produit finis et testés à chaque sprint. Elle est auto-organisée et responsable collectivement de la qualité technique du produit.

#### Planification opérationnelle des Sprints de DJTrip
Le projet a été découpé en **cinq sprints (un sprint d'initialisation technologique et quatre sprints de développement fonctionnel)** d'une durée moyenne de deux semaines chacun :

* **Sprint 0 : Cadrage, UML et Mise en place de l'Architecture (1 semaine)**
  * Étude de l'existant, rédaction des spécifications fonctionnelles détaillées.
  * Modélisation UML (diagrammes de cas d'utilisation, classes, séquences).
  * Initialisation du serveur Node.js / Express avec configuration de MongoDB Atlas.
  * Création du projet Flutter (arborescence des dossiers `lib/` par features).
  * Conception des schémas de base de données Mongoose (`User`, `Activite`, `Inscription`, `Lieu`).

* **Sprint 1 : Gestion des Profils, Authentification et Onboarding (2 semaines)**
  * Implémentation du système d'authentification classique et des jetons JWT (access & refresh tokens).
  * Développement de la connexion sociale Google et de la vérification OTP e-mail.
  * Création des formulaires d'onboarding touristes (sélection des centres d'intérêt) et organisateurs (spécialités d'activités, motivation d'adhésion).
  * Développement des écrans d'édition de profils et des options de confidentialité.

* **Sprint 2 : Moteur d'Activités, Recherche et Système de Réservation (2 semaines)**
  * Développement du module CRUD complet des activités côté organisateur (gestion des localisations fixes, sur-mesure et itinéraires multi-étapes).
  * Mise en place de l'exploration cartographique et textuelle pour les touristes avec filtres avancés.
  * Implémentation du parcours d'inscription à une activité avec calcul de prix, détection des chevauchements d'horaires (`checkBookingOverlap`) et checkout Stripe.
  * Développement du tableau de bord de traitement des réservations pour l'organisateur.

* **Sprint 3 : Social Feed, Messagerie temps réel WebSockets et Appels WebRTC (2 semaines)**
  * Implémentation de la messagerie instantanée via Socket.io (gestion des statuts de lecture, notifications de saisie, envoi de photos/audio/vidéos).
  * Intégration de la signalisation et de l'interface d'appels audio et vidéo peer-to-peer WebRTC.
  * Création du fil d'actualité partagé (Posts, Commentaires, Likes et système d'abonnement).
  * Développement du module des Lieux d'intérêt de Djerba avec carte interactive Google Maps.

* **Sprint 4 : Optimisation (Cache & Réseau), Administration et Stabilisation (2 semaines)**
  * Intégration du `CacheManager` (Hive) et du `NetworkHelper` sur l'application mobile pour le mode hors-ligne et la résilience réseau.
  * Développement du tableau de bord d'administration React (gestion des utilisateurs, approbation des guides, modération des contenus et litiges financiers).
  * Campagne globale de tests unitaires et d'intégration, résolution des anomalies et polissage graphique final (thème Material Design 3).

---

## 2.9 Conclusion

Dans ce deuxième chapitre, nous avons posé les fondations analytiques et méthodologiques indispensables à la réussite du projet **DJTrip**.

L’étude critique de l’existant, centrée sur la plateforme TripAdvisor, a permis de mettre en relief les limites majeures des solutions généralistes du marché : absence de contextualisation sur Djerba, cloisonnement de la communication, manque de fiabilité des avis et processus financiers rigides. Face à cela, la solution **DJTrip** a été présentée comme une alternative moderne, apportant une réelle valeur ajoutée grâce à sa messagerie temps réel et ses appels intégrés, sa billetterie électronique par QR Code, son système d'avis certifiés et sa résilience réseau via cache local Hive.

Nous avons ensuite formalisé de manière exhaustive les exigences du système en découpant les besoins fonctionnels (gestion du cycle de réservation, moteur d'activités géo-référencées, messagerie multimédia) et non fonctionnels (sécurité renforcée, tolérance aux pannes réseau, performance de navigation). La modélisation par les diagrammes de cas d'utilisation UML a permis de délimiter rigoureusement les frontières du système et le rôle de chaque acteur (Touriste, Organisateur, Administrateur).

Enfin, la planification sous le cadre agile **Scrum** et son découpage en sprints structurés garantissent une approche de développement maîtrisée, itérative et focalisée sur la qualité logicielle. Forts de ces spécifications rigoureuses, nous pouvons désormais aborder le chapitre suivant consacré à la **Conception globale et détaillée du système**.

---
*Fin du Chapitre 2 — Projet DJTrip*
