# Mise à jour du système de statut utilisateur

**Date:** 8 Mars 2026

## 📋 Résumé des changements

Le système de statut a été refactorisé pour séparer l'**état de connexion en temps réel** du **statut du compte** de l'utilisateur.

---

## 🔄 Ancien Système

**Champ unique:** `status`

- Valeurs: `"actif"` / `"inactif"`
- **Problème:** Confusion entre "utilisateur connecté" et "compte actif"
- Changeait automatiquement à "inactif" après 90 jours d'inactivité
- Utilisé pour le logout (mis à "inactif")

---

## ✅ Nouveau Système

### 1. **isOnline** (Boolean)

**Indique l'état de connexion en temps réel**

- `true` = Utilisateur actuellement connecté
- `false` = Utilisateur déconnecté
- **Changement automatique:**
  - Mis à `true` lors du login
  - Mis à `false` lors du logout

### 2. **accountStatus** (String)

**Indique l'état du compte**

- `"active"` = Compte actif et fonctionnel
- `"suspended"` = Compte temporairement suspendu (modération)
- `"banned"` = Compte banni (violation des règles)
- `"inactive"` = Compte inactif (désactivé par admin/utilisateur)

**Changement manuel uniquement** - Nécessite intervention admin

---

## 📊 Schéma User mis à jour

```javascript
{
  fullname: String,
  email: String,
  mot_de_passe: String,

  // NOUVEAU: État de connexion en temps réel
  isOnline: { type: Boolean, default: false },

  // NOUVEAU: Statut du compte
  accountStatus: {
    type: String,
    enum: ["active", "suspended", "banned", "inactive"],
    default: "active"
  },

  derniere_connexion: Date,
  // ... autres champs
}
```

---

## 🔧 Modifications du code

### **Modèle User** (`models/user.js`)

```diff
- status: { type: String, enum: ["actif", "inactif"], default: "actif" }
+ isOnline: { type: Boolean, default: false }
+ accountStatus: {
+   type: String,
+   enum: ["active", "suspended", "banned", "inactive"],
+   default: "active"
+ }
```

### **UserService** (`services/user.js`)

#### Nouvelles méthodes:

- ✅ `updateOnlineStatus(userId, isOnline)` - Change l'état connecté/déconnecté
- ✅ `updateAccountStatus(userId, accountStatus)` - Change le statut du compte (admin)

#### Méthodes modifiées:

- ✅ `updateLastConnection()` - Met maintenant `isOnline: true`
- ✅ `createUser()` - Initialise `accountStatus: "active"` et `isOnline: false`
- ✅ `resetPassword()` - Réactive le compte avec `accountStatus: "active"`
- ✅ `updateAccountStatusBasedOnActivity()` - Ne change plus automatiquement le status (monitoring uniquement)

#### Méthode supprimée:

- ❌ `updateStatus()` - Remplacée par `updateAccountStatus()`

### **UserController** (`controllers/user.js`)

#### Login (`signIn`)

```javascript
// Vérifications de compte:
if (user.accountStatus === "suspended") {
  return res.status(403).json({ message: "Account is suspended" });
}

if (user.accountStatus === "banned") {
  return res.status(403).json({ message: "Account is banned" });
}

if (user.accountStatus === "inactive") {
  return res.status(403).json({ message: "Account is inactive" });
}

// Met isOnline = true
await UserService.updateLastConnection(user._id);
```

#### Logout (`logout`)

```javascript
// Met simplement isOnline = false
await UserService.updateOnlineStatus(userId, false);
```

#### Update Account Status (`updateAccountStatus`)

```javascript
// Admin uniquement - Change accountStatus
const { accountStatus } = req.body;

// Validation: "active", "suspended", "banned", "inactive"
if (!["active", "suspended", "banned", "inactive"].includes(accountStatus)) {
  return res.status(400).json({ message: "Invalid account status" });
}

const user = await User.findByIdAndUpdate(
  id,
  { accountStatus: accountStatus },
  { new: true },
);
```

---

## 🚀 Utilisation

### **Frontend - Vérifier si un utilisateur est en ligne**

```dart
// Dans la liste des utilisateurs
if (user.isOnline) {
  // Afficher un badge "En ligne" ou un point vert
} else {
  // Afficher "Hors ligne" ou dernière connexion
}
```

### **Frontend - Vérifier le statut du compte**

```dart
// Lors du login
if (response.accountStatus == "suspended") {
  showDialog("Votre compte est suspendu. Contactez le support.");
} else if (response.accountStatus == "banned") {
  showDialog("Votre compte a été banni.");
}
```

### **Backend - Admin change le statut**

```javascript
// Suspendre un compte
PUT /api/users/:id/status
{
  "accountStatus": "suspended"
}

// Réactiver un compte
PUT /api/users/:id/status
{
  "accountStatus": "active"
}
```

---

## 🔐 Champs protégés

**Impossible de modifier via `updateProfile()`:**

- `isOnline` - Géré automatiquement par le système
- `accountStatus` - Admin uniquement via `updateAccountStatus()`
- `derniere_connexion` - Géré automatiquement
- `mot_de_passe` - Via `changePassword()` uniquement
- `email`, `userType`, `_id`, etc.

---

## ⚠️ Migration des données existantes

**Si vous avez déjà des utilisateurs dans la base:**

```javascript
// Script de migration (à exécuter une seule fois)
db.users.updateMany(
  { status: "actif" },
  {
    $set: {
      isOnline: false,
      accountStatus: "active",
    },
    $unset: { status: "" },
  },
);

db.users.updateMany(
  { status: "inactif" },
  {
    $set: {
      isOnline: false,
      accountStatus: "inactive",
    },
    $unset: { status: "" },
  },
);
```

---

## 📝 Exemples de scénarios

### Scénario 1: Login normal

1. Utilisateur se connecte → `isOnline = true`
2. Utilisateur se déconnecte → `isOnline = false`
3. `accountStatus` reste `"active"`

### Scénario 2: Compte suspendu

1. Admin suspend le compte → `accountStatus = "suspended"`
2. Utilisateur essaie de se connecter → ❌ Refusé "Account is suspended"
3. `isOnline` reste `false`

### Scénario 3: Reset password

1. Utilisateur oublie son mot de passe
2. Reset password → `accountStatus = "active"` (réactivation automatique)
3. Login réussi → `isOnline = true`

### Scénario 4: Monitoring d'inactivité

1. Utilisateur ne se connecte pas pendant 90+ jours
2. Système log l'information (monitoring)
3. **AUCUN changement automatique de `accountStatus`**
4. Admin décide manuellement de mettre `accountStatus = "inactive"` si nécessaire

---

## 🎯 Avantages du nouveau système

✅ **Clarté:** Séparation nette entre "connecté" et "compte actif"
✅ **Flexibilité:** Multiples statuts de compte (suspended, banned, etc.)
✅ **Contrôle:** Changements de statut manuels uniquement (pas d'automatisation surprise)
✅ **Monitoring:** Suivi des utilisateurs en ligne en temps réel
✅ **Sécurité:** Champs protégés non modifiables par l'utilisateur

---

## 📞 Support

Pour toute question sur cette migration, contactez l'équipe de développement.

**Dernière mise à jour:** 8 Mars 2026
