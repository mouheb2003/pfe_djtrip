# Guide : Création d'Activité avec Localisation et Images

## Vue d'ensemble

Le formulaire de création d'activité a été amélioré avec deux nouvelles fonctionnalités majeures :

1. **Sélection de localisation flexible** : Liste ou carte interactive
2. **Upload multiple d'images** : Jusqu'à plusieurs photos par activité

## 🗺️ Sélection de Localisation

### Option 1 : À partir d'une liste

**Quand l'utiliser** :

- Lieux touristiques populaires
- Destinations courantes
- Sélection rapide

**Comment** :

1. Dans le formulaire, section "Location"
2. Assurez-vous que le bouton **"From List"** est sélectionné (vert)
3. Cliquez sur le dropdown
4. Choisissez parmi les lieux prédéfinis :
   - Tunis, Tunisia
   - Carthage, Tunisia
   - Sidi Bou Said, Tunisia
   - Hammamet, Tunisia
   - Sousse, Tunisia
   - Djerba, Tunisia
   - Tozeur, Tunisia
   - Kairouan, Tunisia

**Notes** :

- La liste sera enrichie avec plus de lieux
- Possibilité future d'ajouter vos propres lieux favoris

---

### Option 2 : Carte interactive Google Maps

**Quand l'utiliser** :

- Adresse précise
- Lieu non listé
- Point GPS exact (coordonnées)

**Comment** :

1. Dans le formulaire, section "Location"
2. Cliquez sur le bouton **"On Map"** (devient vert)
3. Cliquez sur **"Select Location on Map"**
4. Une carte interactive s'ouvre

**Sur la carte, vous pouvez** :

#### A. Rechercher une adresse

1. Tapez l'adresse dans la barre de recherche en haut
2. Appuyez sur Enter ou cliquez sur l'icône de recherche
3. La carte zoom automatiquement sur le lieu
4. Un marker vert apparaît
5. L'adresse complète s'affiche en haut de la carte

#### B. Sélectionner en tapant sur la carte

1. Tapez directement sur n'importe quel point de la carte
2. Un marker vert apparaît à cet endroit
3. L'adresse est automatiquement trouvée (reverse geocoding)
4. L'adresse s'affiche en haut

#### C. Ajuster la position

1. Le marker vert est **draggable** (déplaçable)
2. Appuyez et maintenez le marker
3. Déplacez-le où vous voulez
4. Relâchez - l'adresse se met à jour

#### D. Utiliser votre position actuelle

- Cliquez sur le bouton de localisation (icône GPS) dans le coin
- La carte centre sur votre position actuelle
- Permissions de localisation requises

#### E. Valider la sélection

1. Une fois satisfait de la position
2. Cliquez sur l'icône ✓ (check) en haut à droite
3. Vous revenez au formulaire
4. L'adresse et les coordonnées GPS sont sauvegardées

**Avantages** :

- Précision au mètre près
- Visualisation du lieu
- Coordonnées GPS exactes (latitude/longitude)
- Utile pour partager sur d'autres apps (Google Maps, Waze)

---

## 📷 Upload d'Images

### Comment ajouter des photos

#### État initial (aucune photo)

- Une grande zone grise apparaît avec l'icône photo
- Texte : "Add photos of your activity"
- **Tapez** n'importe où sur cette zone

#### Menu de sélection

Un menu apparaît en bas de l'écran avec 2 options :

**Option 1 : Choose from Gallery**

- Ouvre la galerie de votre téléphone
- ✅ Permet de sélectionner **plusieurs photos en même temps**
- Maintenez pour sélectionner plusieurs
- Tapez "Done" ou "OK"

**Option 2 : Take a Photo**

- Ouvre l'appareil photo
- Prenez une photo
- Elle est ajoutée à la liste

### Prévisualisation des photos

Une fois ajoutées, les photos apparaissent en grille :

- **3 colonnes**
- Chaque photo a un bouton **X rouge** en haut à droite pour la supprimer
- Un bouton **"+ Add"** permet d'ajouter plus de photos

### Compteur de photos

En haut de la section "Photos", un badge affiche le nombre total :

- `0` en gris si aucune photo
- `3` en vert si 3 photos ajoutées

### Ajouter plus de photos

Deux façons :

1. **Via le bouton Add Photos** (en haut à droite de la section)
2. **Via la case "+ Add"** (dernière case de la grille)

Les deux ouvrent le même menu de sélection.

### Supprimer une photo

1. Trouvez la photo dans la grille
2. Tapez sur le **X rouge** en haut à droite de la photo
3. La photo est immédiatement retirée

### Édition d'activité existante

Si l'activité a déjà des photos :

- Les photos existantes (du serveur) apparaissent en premier
- Vous pouvez les supprimer
- Vous pouvez en ajouter de nouvelles
- Les nouvelles et anciennes sont mélangées dans la grille

---

## 💾 Sauvegarde

### Avant de soumettre

Le formulaire vérifie :

- ✅ Titre rempli
- ✅ Description remplie
- ✅ Localisation sélectionnée (liste OU carte)
- ✅ Dates de début et fin valides
- ✅ Prix et capacité corrects
- ✅ Durée spécifiée

**Note** : Les photos sont **optionnelles** mais fortement recommandées !

### Données sauvegardées

Selon le mode de localisation :

**Mode Liste** :

```json
{
  "lieu": "Tunis, Tunisia"
}
```

**Mode Carte** :

```json
{
  "lieu": "123 Avenue Habib Bourguiba, Tunis 1000, Tunisia",
  "coordonnees": {
    "latitude": 36.8065,
    "longitude": 10.1815
  }
}
```

**Photos** :

- Les fichiers seront uploadés sur Cloudinary (à venir)
- Les URLs seront stockées dans la base de données
- Liste de strings : `["url1", "url2", "url3"]`

---

## 🎯 Bonnes Pratiques

### Pour la localisation

**Utilisez la liste si** :

- C'est un lieu touristique connu
- Vous voulez aller vite
- La précision n'est pas critique

**Utilisez la carte si** :

- Vous avez besoin de l'adresse exacte
- C'est un lieu peu connu
- Vous voulez les coordonnées GPS
- Les touristes auront besoin de navigation GPS

### Pour les images

**Recommandations** :

- **Minimum** : 1 photo (principale)
- **Idéal** : 3-5 photos
- **Maximum** : Pas de limite technique, mais restez raisonnable (10 max)

**Types de photos à inclure** :

1. **Photo principale** : Vue d'ensemble de l'activité
2. **Détails** : Équipements, installations
3. **Contexte** : Paysage, environnement
4. **Action** : Personnes en train de faire l'activité (si possible)
5. **Résultat** : Ce que les touristes verront/vivront

**Qualité** :

- Photos nettes et bien éclairées
- Évitez les photos floues
- Format paysage (horizontal) recommandé
- L'app réduit automatiquement la qualité à 80% pour économiser l'espace

---

## ❓ FAQ

**Q : Puis-je modifier la localisation après création ?**
R : Oui, éditez l'activité et changez le mode ou sélectionnez un nouveau lieu.

**Q : Combien de photos maximum ?**
R : Techniquement illimité, mais restez sous 10 pour de bonnes performances.

**Q : Les photos sont-elles compressées ?**
R : Oui, automatiquement à 80% de qualité pour économiser l'espace et la bande passante.

**Q : Puis-je voir les coordonnées GPS exactes ?**
R : Pas dans l'interface actuellement, mais elles sont sauvegardées en base de données.

**Q : La carte fonctionne hors ligne ?**
R : Non, une connexion internet est requise pour charger la carte et géocoder les adresses.

**Q : Combien coûte Google Maps ?**
R : Gratuit jusqu'à 100 000 utilisations par mois. Largement suffisant pour commencer.

---

## 🐛 Problèmes courants

### La carte n'apparaît pas (écran gris)

**Cause** : Clé API Google Maps manquante ou invalide
**Solution** : Voir `documentation/GOOGLE_MAPS_SETUP.md`

### "Permission denied" pour les photos

**Cause** : Permissions caméra/galerie non accordées
**Solution** :

1. Allez dans Paramètres Android
2. Apps → DJTrip → Permissions
3. Activez Caméra et Stockage

### L'adresse ne se trouve pas

**Cause** : Adresse mal orthographiée ou trop vague
**Solution** :

- Soyez plus précis (ville, rue, numéro)
- Utilisez le mode tap sur la carte
- Ajoutez le pays : "Tunis, Tunisia"

### Photos trop lourdes / lentes à charger

**Cause** : Photos haute résolution
**Solution** :

- L'app compresse automatiquement
- Si problème persiste, réduisez manuellement avant upload
- Ou prenez photos directement avec l'app (qualité 80%)

---

## 🚀 Prochaines améliorations

- [ ] Autocomplétion dans la recherche d'adresse
- [ ] Support de la caméra frontale
- [ ] Édition d'images (crop, rotation, filtres)
- [ ] Réorganisation de l'ordre des photos (drag & drop)
- [ ] Preview en plein écran
- [ ] Upload progressif (barre de progression)
- [ ] Liste dynamique de lieux depuis DB
- [ ] Lieux favoris/récents

---

**Besoin d'aide ?** Consultez `documentation/GOOGLE_MAPS_SETUP.md` pour la configuration technique.
