# Changelog — 09 Mars 2026

## Vue d'ensemble

Cette journée a été consacrée à l'amélioration de l'expérience touriste (cartes d'activités, gestion des inscriptions), à la fiabilisation des statistiques côté organisateur, et à la mise en place d'un dashboard réactif qui se met à jour automatiquement sans rechargement de page.

---

## 1. Correction de la détection d'inscription (`activity_card_tourist.dart`)

### Problème

Même si un touriste avait déjà une demande de réservation (`inscription`) pour une activité, le bouton **Book Now** restait visible et cliquable. En cliquant, il obtenait une erreur serveur : `Exception: Vous êtes déjà inscrit à cette activité`.

### Cause racine

Le code comparait `inscription.activite?.id` (champ peuplé, nullable — peut être `null` si le serveur ne renvoie pas l'objet peuplé) avec `widget.activity.id`. Cette comparaison échouait silencieusement quand `activite` était `null`.

### Solution

Utiliser le champ direct `inscription.activiteId` (String, toujours présent) avec fallback sur `activite?.id` :

```dart
final insActiviteId = ins.activiteId.isNotEmpty
    ? ins.activiteId
    : (ins.activite?.id ?? '');
if (insActiviteId == widget.activity.id && ...) { ... }
```

### Principe

> **Préférer les champs scalaires directs aux champs peuplés (relations) pour les comparaisons d'identifiants.** Les objets peuplés dépendent du backend incluant la relation — les ID scalaires sont toujours là.

---

## 2. Système de bouton à 3 états pour la réservation

### Logique

| État de l'inscription                      | Bouton affiché                      | Action                         |
| ------------------------------------------ | ----------------------------------- | ------------------------------ |
| Chargement (`_checkingInscription = true`) | Spinner `CircularProgressIndicator` | —                              |
| `statut == 'en_attente'`                   | 🟠 **"Cancel Request"**             | Appelle `_cancelInscription()` |
| `statut == 'approuvee'` ou autre           | ⬜ **"Book Now"** grisé (disabled)  | Aucune action                  |
| Aucune inscription / annulée               | 🟢 **"Book Now"**                   | Ouvre `_showBookingDialog()`   |
| Activité complète (0 places)               | ⬜ **"Complet"** grisé (disabled)   | Aucune action                  |

### Nouvelles méthodes

#### `_checkMyInscription()`

Chargée au `initState()`. Appelle `InscriptionService.getMesInscriptions()`, filtre sur l'activité courante et les statuts actifs (`en_attente` ou `approuvee`). Met à jour `_myInscription` et `_checkingInscription`.

```dart
Future<void> _checkMyInscription() async {
  final inscriptions = await InscriptionService.getMesInscriptions();
  Inscription? found;
  for (final ins in inscriptions) {
    final insActiviteId = ins.activiteId.isNotEmpty
        ? ins.activiteId : (ins.activite?.id ?? '');
    if (insActiviteId == widget.activity.id &&
        (ins.statut == 'en_attente' || ins.statut == 'approuvee')) {
      found = ins; break;
    }
  }
  if (mounted) setState(() { _myInscription = found; _checkingInscription = false; });
}
```

#### `_cancelInscription()`

Affiche un `AlertDialog` de confirmation, puis appelle `InscriptionService.annulerInscription(id)`. En cas de succès, remet `_myInscription = null` (le bouton revient à "Book Now") et appelle `widget.onRefresh()`.

---

## 3. Gestion des erreurs : AlertDialog au lieu de SnackBar

### Avant

Les erreurs s'affichaient dans un SnackBar rouge flottant avec le texte brut de l'exception (incluant le préfixe `Exception: `).

### Après

Les erreurs s'affichent dans un `AlertDialog` propre :

- Titre : icône `error_outline` rouge + "Erreur"
- Contenu : message nettoyé (préfixes `Exception: ` et `Erreur: ` supprimés)
- Bouton OK pour fermer

```dart
String msg = e.toString();
if (msg.startsWith('Exception: ')) msg = msg.substring(11);
if (msg.startsWith('Erreur: ')) msg = msg.substring(8);

showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Row(children: [
      Icon(Icons.error_outline, color: Colors.red),
      Text('Erreur'),
    ]),
    content: Text(msg),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))],
  ),
);
```

### Principe

> **Ne jamais afficher les objets `Exception` Dart directement à l'utilisateur.** Toujours nettoyer le message avant affichage. Préférer les dialogs pour les erreurs bloquantes, les SnackBars pour les confirmations légères.

---

## 4. Redesign des statistiques sur les cartes touriste

### Avant

Trois petits chips inline (icône + valeur sur une ligne) : `Places`, `Durée`, `Rating`.

### Après

Trois grandes cartes (`_buildStatCard`) qui occupent toute la largeur :

```
[ 👥 Places  ] [ ⭐ Rating ] [ 💬 Reviews ]
[   1/99    ] [   New    ] [     0     ]
```

Chaque carte :

- Fond coloré doux (`color.withOpacity(0.1)`)
- Icône centrée en haut
- Valeur en gras
- Label descriptif en dessous

#### Nouveau widget `_buildStatCard`

```dart
Widget _buildStatCard(IconData icon, String value, String label, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, size: 22, color: color),
        SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    ),
  );
}
```

##### Mapping des statistiques

| Stat    | Icône                        | Couleur         | Valeur                             |
| ------- | ---------------------------- | --------------- | ---------------------------------- |
| Places  | `Icons.people`               | `Colors.blue`   | `nombreReservations / capaciteMax` |
| Rating  | `Icons.star`                 | `Colors.amber`  | `noteMoyenne` ou `"New"` si 0      |
| Reviews | `Icons.rate_review_outlined` | `Colors.purple` | `nombreAvis`                       |

---

## 5. Statistiques globales dans l'écran archive (organisateur)

### Problème

Les statistiques (Total Activities, Total Places, Revenue, Avg Rating) n'affichaient que les activités archivées.

### Solution

`ArchiveScreen` charge maintenant **deux listes** en parallèle :

- `_archivedActivities` = activités terminées (pour l'affichage de la liste)
- `_allActivities` = activités actives/futures (pour les stats seulement)

Les calculs utilisent `[..._archivedActivities, ..._allActivities]` :

```dart
final combined = [..._archivedActivities, ..._allActivities];
final totalRevenue = combined.fold<double>(0, (s, a) => s + (a.prix * a.nombreReservations));
final avgRating = combined.where((a) => a.noteMoyenne > 0).map((a) => a.noteMoyenne).average;
```

**Total Activities** utilise `(widget.user as Organisator).listeActivites.length` (source de vérité = backend).

---

## 6. Système de callback `onUserDataChanged`

### Contexte

Après création/suppression d'une activité, le compteur d'activités affiché dans le profil et l'archive ne se mettait pas à jour.

### Solution

`OrganizerMainScreen` maintient `_currentUser` en state et expose `_refreshUserData()` :

```dart
Future<void> _refreshUserData() async {
  final result = await AuthService.getMyInfo();
  if (result['success']) setState(() { _currentUser = result['user']; });
}
```

Ce callback est passé en prop à `MyActivitiesScreen` et `ArchiveScreen` :

```dart
MyActivitiesScreen(user: _currentUser, onUserDataChanged: _refreshUserData)
ArchiveScreen(user: _currentUser, onUserDataChanged: _refreshUserData)
```

### Principe

> **Prop drilling avec callback** : le parent est propriétaire des données, les enfants signalent les mutations via callback. Évite le state management global pour des cas simples.

---

## 7. Système de tri (`_sortBy`)

### Dans `MyActivitiesScreen` (organisateur)

Options : `upcoming` · `recent` · `revenue` · `rating` · `alphabetical`

| Option          | Critère de tri                   |
| --------------- | -------------------------------- |
| Upcoming First  | `dateDebut` ASC                  |
| Most Recent     | `dateDebut` DESC                 |
| Highest Revenue | `prix * nombreReservations` DESC |
| Best Rating     | `noteMoyenne` DESC               |
| A–Z             | `titre` alphabétique             |

### Dans `AllActivitiesTab` (touriste)

Options : `upcoming` · `recent` · `price_low` · `price_high` · `rating`

| Option            | Critère de tri     |
| ----------------- | ------------------ |
| Upcoming First    | `dateDebut` ASC    |
| Most Recent       | `dateDebut` DESC   |
| Price: Low → High | `prix` ASC         |
| Price: High → Low | `prix` DESC        |
| Best Rating       | `noteMoyenne` DESC |

### Implémentation commune

Un `DropdownButton<String>` dans le header de chaque liste. Lors du changement de valeur :

```dart
setState(() { _sortBy = newValue; _sortActivities(); });
```

`_sortActivities()` trie `_activities` in-place avec `.sort()`.

---

## 8. Résumé des fichiers modifiés

| Fichier                                                 | Modifications                                                                                      |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `Front/lib/widgets/activity_card_tourist.dart`          | Détection inscription, système 3 états bouton, annulation, erreurs via dialog, stat cards redesign |
| `Front/lib/screens/activities_tab_screen.dart`          | Tri dans `AllActivitiesTab` (5 options)                                                            |
| `Front/lib/screens/organizer/my_activities_screen.dart` | Tri dans `MyActivitiesScreen` (5 options), callback `onUserDataChanged`                            |
| `Front/lib/screens/organizer/archive_screen.dart`       | Double chargement activités, stats globales, `_buildStatCard` avec subtitle, spread `...[`         |
| `Front/lib/screens/organizer_main_screen.dart`          | `_currentUser` state, `_refreshUserData()`, props callbacks                                        |
| `Front/lib/screens/main_screen.dart`                    | `_currentUser` state, getter `_screens`, timer 30s, refresh au changement d'onglet                 |
| `Front/lib/screens/home_tab_screen.dart`                | Timer 30s pour compteur de demandes en attente, `dispose()` pour annuler le timer                  |

---

## 10. Dashboard réactif — mise à jour automatique sans refresh

### Problème

Les valeurs du dashboard (compteur d'activités, demandes en attente, statistiques) nécessitaient un rechargement complet de la page pour se mettre à jour. Si l'organisateur créait une activité ou approuvait une réservation, les chiffres restaient figés jusqu'au prochain démarrage.

### Architecture mise en place

#### `MainScreen` : owner des données utilisateur

`MainScreen` est promu au rôle de **source de vérité unique** pour `_currentUser`. Deux mécanismes déclenchent un refresh :

1. **Timer automatique toutes les 30 secondes** — appelle `AuthService.getMyInfo()` et met à jour `_currentUser` en state.
2. **Changement d'onglet** — chaque `onTap` sur la barre de navigation déclenche aussi `_refreshUserData()`.

```dart
Timer.periodic(const Duration(seconds: 30), (_) => _refreshUserData());

onTap: (index) {
  setState(() { _currentIndex = index; });
  _refreshUserData(); // fraîcheur garantie à chaque navigation
},
```

#### Getter `_screens` au lieu d'une liste fixe

Avant, `_screens` était assignée une seule fois dans `initState` avec `widget.user` — elle devenait **stale** immédiatement après la première modification.

Après, `_screens` est un **getter** recalculé à chaque rebuild :

```dart
// AVANT — stale après initState
late List<Widget> _screens;
void initState() {
  _screens = [HomeTabScreen(user: widget.user), ...];
}

// APRÈS — toujours frais
List<Widget> get _screens => [
  HomeTabScreen(user: _currentUser),
  ...
];
```

Flutter compare le type des widgets : si le type est identique, il appelle `didUpdateWidget` sur le State existant au lieu d'en créer un nouveau → **pas de perte de scroll, pas de clignotement**.

#### `HomeTabScreen` : polling des demandes en attente

```dart
_pollingTimer = Timer.periodic(
  const Duration(seconds: 30),
  (_) => _loadPendingRequests(),
);

@override
void dispose() {
  _pollingTimer?.cancel(); // OBLIGATOIRE pour éviter les appels réseau orphelins
  super.dispose();
}
```

### Tableau récapitulatif du comportement

| Événement                       | Réaction                                                     |
| ------------------------------- | ------------------------------------------------------------ |
| Toutes les 30 secondes          | `_currentUser` rechargé, compteur demandes mis à jour        |
| Changement d'onglet             | `_currentUser` rechargé immédiatement                        |
| Création/suppression d'activité | Callback `onUserDataChanged` → `_refreshUserData()` immédiat |
| Widget détruit (`dispose`)      | Timers annulés → aucune requête réseau orpheline             |

### Principe

> **Polling léger côté client** est une alternative simple au WebSocket quand la donnée n'est pas critique à la milliseconde. 30 secondes est un bon compromis entre fraîcheur et charge serveur pour un dashboard comme celui-ci.

---

## 11. Bouton "Booked" quand la réservation est approuvée

Quand le statut de l'inscription passe à `approuvee`, le bouton affiche désormais ✓ **"Booked"** en vert (disabled) au lieu d'un "Book Now" grisé neutre, rendant la confirmation visuellement claire pour le touriste.

1. **ID scalaire > objet peuplé** pour les comparaisons — ne pas dépendre de l'hydratation GraphQL/Mongoose.
2. **Callback prop drilling** pour signaler mutations aux parents — simple et traçable sans Bloc/Provider.
3. **État de chargement par widget** (`_checkingInscription`) — UX réactive sans bloquer l'UI globale.
4. **Nettoyage des messages d'erreur à la couche UI** — jamais afficher `Exception:` brut.
5. **Dialogs pour erreurs bloquantes, SnackBars pour confirmations légères.**
6. **Source de vérité backend** pour les compteurs critiques (`listeActivites.length` depuis `getMyInfo()`).
7. **Tri in-place** avec `List.sort()` après chargement — pas de liste dupliquée, pas d'appel API supplémentaire.
8. **`mounted` check** avant tout `setState` après `await` — évite les fuites mémoire sur widgets disposés.
9. **Getter vs liste fixe** pour les écrans — un getter `List<Widget> get _screens` rebuild avec le state courant ; une liste assignée en `initState` est stale.
10. **`Timer.periodic` + `dispose()`** pour le polling léger — toujours annuler le timer dans `dispose()` pour éviter les appels réseau sur des widgets déjà détruits.
11. **`didUpdateWidget`** implicite — Flutter réutilise le State existant quand le type de widget ne change pas, donc passer un `user` mis à jour en prop suffit à propager les nouvelles données sans perdre le scroll ou l'état local.
