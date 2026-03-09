# 📚 TRAVELO BACKEND - DOCUMENTATION COMPLÈTE

## 🎯 Vue d'ensemble

**Travelo** est une API REST pour une application de voyage développée avec **Node.js, Express et MongoDB**. Elle gère l'authentification, les utilisateurs (Touristes et Organisateurs) et utilise un système d'héritage avec **Mongoose Discriminators**.

---

## 📂 Structure du Projet

```
Back/pfe_backend-main/
├── config/          # Configuration de la base de données et services
├── controllers/     # Logique métier des routes
├── middleware/      # Middlewares (authentification, upload, etc.)
├── models/          # Modèles de données Mongoose
├── routes/          # Définition des routes de l'API
├── .env             # Variables d'environnement
├── server.js        # Point d'entrée de l'application
└── package.json     # Dépendances et scripts npm
```

---

## 📦 Installation et Démarrage

### Prérequis

- **Node.js** (v14 ou supérieur)
- **MongoDB** (local ou Atlas)
- **npm** ou **yarn**

### Installation

```bash
cd Back/pfe_backend-main
npm install
```

### Démarrage

```bash
# Mode production
npm start

# Mode développement (avec nodemon)
npm run dev
```

Le serveur démarre sur **http://localhost:3000**

---

## 🔧 Configuration (.env)

Le fichier `.env` contient toutes les variables d'environnement nécessaires :

```env
# Server Configuration
PORT=3000

# MongoDB Configuration
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/database

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production_12345
JWT_EXPIRES_IN=15m
REFRESH_TOKEN_SECRET=your_refresh_secret_key_change_this_in_production_67890

# Cloudinary Configuration (pour upload d'images)
CLOUD_NAME=your_cloudinary_cloud_name
API_KEY=your_cloudinary_api_key
API_SECRET=your_cloudinary_api_secret
```

### Variables expliquées :

- **PORT** : Port d'écoute du serveur (par défaut 3000)
- **MONGODB_URI** : URL de connexion MongoDB
- **JWT_SECRET** : Clé secrète pour signer les access tokens (15 min)
- **REFRESH_TOKEN_SECRET** : Clé secrète pour les refresh tokens (7 jours)
- **CLOUD_NAME, API_KEY, API_SECRET** : Identifiants Cloudinary pour l'upload d'images

---

## 📁 FICHIERS DÉTAILLÉS

---

## 📄 server.js

**Rôle** : Point d'entrée de l'application Express

```javascript
require("dotenv").config(); // Charge les variables .env
const express = require("express"); // Framework web
const db = require("./config/db"); // Connexion MongoDB

const app = express();

// MIDDLEWARE
app.use(express.json()); // Parse le JSON dans les requêtes

// ROUTE RACINE
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to Travelo API",
    endpoints: {
      users: "/api/users",
      touristes: "/api/touristes",
      organisators: "/api/organisators",
    },
  });
});

// ROUTES API
app.use("/api/users", require("./routes/user"));
app.use("/api/touristes", require("./routes/touriste"));
app.use("/api/organisators", require("./routes/organisator"));

// DÉMARRAGE DU SERVEUR
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
```

### Explications mot par mot :

- `require("dotenv").config()` : Charge le fichier .env dans `process.env`
- `express()` : Crée une instance de l'application Express
- `app.use(express.json())` : Middleware pour parser le corps des requêtes en JSON
- `app.get("/")` : Route GET pour la racine (retourne les endpoints disponibles)
- `app.use("/api/users", ...)` : Monte les routes /api/users
- `app.listen(PORT)` : Démarre le serveur HTTP sur le port spécifié

---

## 📂 config/

### 📄 config/db.js

**Rôle** : Connexion à MongoDB avec Mongoose

```javascript
const mongoose = require("mongoose");

const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://localhost:27017/travelo";

mongoose
  .connect(MONGODB_URI)
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => console.error("Error connecting to MongoDB:", err));

module.exports = mongoose;
```

### Explications :

- `mongoose.connect(MONGODB_URI)` : Établit la connexion à MongoDB
- **Promise** : `.then()` en cas de succès, `.catch()` en cas d'erreur
- `module.exports = mongoose` : Exporte l'instance mongoose pour réutilisation

---

### 📄 config/cloudinary.js

**Rôle** : Configuration de Cloudinary pour l'upload d'images

```javascript
const cloudinary = require("cloudinary").v2;

cloudinary.config({
  cloud_name: process.env.CLOUD_NAME,
  api_key: process.env.API_KEY,
  api_secret: process.env.API_SECRET,
});

module.exports = cloudinary;
```

### Explications :

- `cloudinary.v2` : Version 2 de l'API Cloudinary
- `cloudinary.config({...})` : Configure les identifiants depuis .env
- Utilisé pour uploader des avatars et photos

---

## 📂 models/

Les modèles définissent la structure des données dans MongoDB.

### 📄 models/user.js

**Rôle** : Modèle de base (classe abstraite) pour tous les utilisateurs

```javascript
const mongoose = require("mongoose");

// Schéma de base User (classe abstraite)
const userSchema = new mongoose.Schema(
  {
    fullname: String, // Nom complet
    age: Number, // Âge
    num_tel: String, // Numéro de téléphone
    email: {
      type: String,
      required: true, // Obligatoire
      unique: true, // Unique dans la BDD
    },
    mot_de_passe: {
      type: String,
      required: true, // Obligatoire (hashé)
    },
    date_inscription: {
      type: Date,
      default: Date.now, // Date d'inscription par défaut = maintenant
    },
    avatar: String, // URL de l'image de profil
    bio: String, // Biographie
    pays_origine: String, // Pays d'origine
    status: {
      type: String,
      enum: ["actif", "inactif"], // Valeurs possibles
      default: "actif", // Par défaut actif
    },
    derniere_connexion: Date, // Date de dernière connexion
    notifications_email: {
      type: Boolean,
      default: true, // Notifications email activées par défaut
    },
    notifications_sms: {
      type: Boolean,
      default: false,
    },
    consentement_donnees: {
      type: Boolean,
      default: false,
    },
  },
  {
    discriminatorKey: "userType", // Clé pour l'héritage (Touriste/Organisator)
    collection: "users", // Nom de la collection MongoDB
  },
);

const User = mongoose.model("User", userSchema);

module.exports = User;
```

### Explications mot par mot :

- `new mongoose.Schema({...})` : Crée un schéma Mongoose
- `type: String` : Type de données
- `required: true` : Champ obligatoire
- `unique: true` : Valeur unique dans toute la collection
- `enum: [...]` : Liste de valeurs autorisées
- `default: ...` : Valeur par défaut si non fournie
- `discriminatorKey: 'userType'` : Permet l'héritage (Touriste ou Organisator)
- `mongoose.model('User', userSchema)` : Crée le modèle à partir du schéma

---

### 📄 models/touriste.js

**Rôle** : Modèle Touriste qui hérite de User

```javascript
const mongoose = require("mongoose");
const User = require("./user");

// Schéma spécifique au Touriste
const touristeSchema = new mongoose.Schema({
  centres_interet: {
    type: [String], // Tableau de strings
    default: [], // Tableau vide par défaut
  },
  langue_preferee: {
    type: String,
    default: "Français",
  },
});

// Utilisation du discriminator pour hériter de User
const Touriste = User.discriminator("Touriste", touristeSchema);

module.exports = Touriste;
```

### Explications :

- `User.discriminator('Touriste', touristeSchema)` : Crée un modèle qui hérite de User
- Le champ `userType` sera automatiquement défini à `'Touriste'`
- Les documents Touriste et User sont stockés dans la même collection MongoDB (`users`)

---

### 📄 models/organisator.js

**Rôle** : Modèle Organisator (organisateur de voyages)

```javascript
const mongoose = require("mongoose");
const User = require("./user");

// Schéma spécifique pour Organisator
const organisatorSchema = new mongoose.Schema({
  nom_entreprise: {
    type: String,
    required: true, // Obligatoire pour les organisateurs
  },
  numero_licence: String, // Numéro de licence professionnelle
  adresse_entreprise: String,
  site_web: String,
  specialites: {
    type: [String], // Ex: ["Plongée", "Randonnée"]
    default: [],
  },
  note_moyenne: {
    type: Number,
    default: 0,
    min: 0, // Note minimale
    max: 5, // Note maximale
  },
  nombre_avis: {
    type: Number,
    default: 0,
  },
  certifications: {
    type: [String], // Ex: ["ISO 9001", "IATA"]
    default: [],
  },
});

// Utilisation du discriminator pour hériter de User
const Organisator = User.discriminator("Organisator", organisatorSchema);

module.exports = Organisator;
```

### Explications :

- `min: 0, max: 5` : Contraintes de validation
- Tous les champs de `User` sont disponibles + les champs spécifiques à `Organisator`

---

## 📂 middleware/

### 📄 middleware/auth.js

**Rôle** : Gestion de l'authentification JWT (JSON Web Tokens)

```javascript
const jwt = require("jsonwebtoken");

// Clés secrètes depuis .env
const JWT_SECRET = process.env.JWT_SECRET || "your_secret_key";
const REFRESH_TOKEN_SECRET =
  process.env.REFRESH_TOKEN_SECRET || "your_refresh_secret_key";

// Génère un Access Token (courte durée - 15 min)
exports.generateAccessToken = (userId, email, userType) => {
  return jwt.sign(
    { userId, email, userType }, // Payload (données)
    JWT_SECRET, // Clé secrète
    { expiresIn: "15m" }, // Expiration
  );
};

// Génère un Refresh Token (longue durée - 7 jours)
exports.generateRefreshToken = (userId, email, userType) => {
  return jwt.sign({ userId, email, userType }, REFRESH_TOKEN_SECRET, {
    expiresIn: "7d",
  });
};

// Génère les deux tokens
exports.generateTokens = (userId, email, userType) => {
  const accessToken = exports.generateAccessToken(userId, email, userType);
  const refreshToken = exports.generateRefreshToken(userId, email, userType);

  return { accessToken, refreshToken };
};

// Middleware pour vérifier le token
exports.verifyToken = (req, res, next) => {
  try {
    // Récupère le token depuis l'en-tête Authorization
    const token = req.headers.authorization?.split(" ")[1]; // Format: "Bearer TOKEN"

    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }

    // Vérifie et décode le token
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // Ajoute les infos user à la requête
    next(); // Passe au middleware suivant
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expired" });
    }
    return res.status(401).json({ message: "Invalid token" });
  }
};

// Middleware pour vérifier que l'utilisateur est un Organisator
exports.verifyOrganisator = (req, res, next) => {
  if (req.user.userType !== "Organisator") {
    return res
      .status(403)
      .json({ message: "Access denied. Organisator access required." });
  }
  next();
};

// Rafraîchir le token
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({ message: "Refresh token required" });
    }

    // Vérifie le refresh token
    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);

    // Génère un nouveau access token
    const newAccessToken = exports.generateAccessToken(
      decoded.userId,
      decoded.email,
      decoded.userType,
    );

    res.status(200).json({
      message: "Token refreshed successfully",
      accessToken: newAccessToken,
    });
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res
        .status(401)
        .json({ message: "Refresh token expired. Please login again." });
    }
    return res.status(401).json({ message: "Invalid refresh token" });
  }
};
```

### Explications mot par mot :

- `jwt.sign(payload, secret, options)` : Crée un token JWT signé
- `jwt.verify(token, secret)` : Vérifie et décode un token
- `req.headers.authorization` : En-tête HTTP contenant le token
- `.split(' ')[1]` : Extrait le token du format "Bearer TOKEN"
- `req.user = decoded` : Stocke les infos décodées dans la requête
- `next()` : Passe au middleware ou contrôleur suivant
- **Access Token** : Court (15 min), pour les requêtes API
- **Refresh Token** : Long (7 jours), pour renouveler l'access token

---

### 📄 middleware/upload.js

**Rôle** : Configuration de Multer pour l'upload de fichiers vers Cloudinary

```javascript
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinary");

// Configuration du stockage Cloudinary
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "travelo", // Dossier sur Cloudinary
    allowed_formats: ["jpg", "png", "jpeg", "gif"],
    transformation: [{ width: 500, height: 500, crop: "limit" }],
  },
});

const upload = multer({ storage: storage });

module.exports = upload;
```

### Explications :

- `multer` : Middleware Node.js pour gérer les uploads
- `CloudinaryStorage` : Stockage direct sur Cloudinary
- `folder: 'travelo'` : Tous les fichiers vont dans ce dossier
- `allowed_formats` : Types de fichiers autorisés
- `transformation` : Redimensionne automatiquement à 500x500 max

---

## 📂 controllers/

Les contrôleurs contiennent la logique métier.

### 📄 controllers/user.js

**Rôle** : Gestion des utilisateurs (inscription, connexion, etc.)

#### Méthode : `signUp` (Inscription)

```javascript
const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const bcrypt = require("bcryptjs");
const { generateTokens } = require("../middleware/auth");

exports.signUp = async (req, res) => {
  try {
    // 1. Récupère les données du corps de la requête
    const { fullname, email, mot_de_passe, userType, ...additionalData } =
      req.body;

    // 2. Validation des champs requis
    if (!fullname || !email || !mot_de_passe) {
      return res.status(400).json({
        message: "Fullname, email, and password are required",
      });
    }

    // 3. Validation du userType
    if (!userType || !["Touriste", "Organisator"].includes(userType)) {
      return res.status(400).json({
        message: 'userType must be either "Touriste" or "Organisator"',
      });
    }

    // 4. Vérifie si l'email existe déjà
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: "Email already registered" });
    }

    // 5. Hash le mot de passe avec bcrypt (10 rounds)
    const hashedPassword = await bcrypt.hash(mot_de_passe, 10);

    // 6. Prépare les données de base
    const baseData = {
      fullname,
      email,
      mot_de_passe: hashedPassword,
      date_inscription: new Date(),
      status: "actif",
      ...additionalData, // Spread des données supplémentaires
    };

    // 7. Crée le bon type d'utilisateur
    let user;
    if (userType === "Touriste") {
      user = new Touriste(baseData);
    } else if (userType === "Organisator") {
      user = new Organisator(baseData);
    }

    // 8. Sauvegarde dans MongoDB
    await user.save();

    // 9. Génère les tokens JWT
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
    );

    // 10. Retire le mot de passe de la réponse
    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;

    // 11. Envoie la réponse
    res.status(201).json({
      message: "User registered successfully. Please complete your profile.",
      accessToken,
      refreshToken,
      user: userResponse,
    });
  } catch (err) {
    res.status(500).json({
      message: "Error registering user",
      error: err.message,
    });
  }
};
```

### Explications détaillées :

1. **Destructuration** : `const { fullname, ... } = req.body` extrait les champs
2. **Validation** : Vérifie la présence des champs requis
3. **`User.findOne({ email })`** : Cherche un user avec cet email
4. **`bcrypt.hash(password, 10)`** : Hash le mot de passe (10 = "salt rounds")
5. **`new Touriste()`** : Instancie le bon modèle selon `userType`
6. **`await user.save()`** : Sauvegarde asynchrone dans MongoDB
7. **`generateTokens()`** : Crée les JWT
8. **`delete userResponse.mot_de_passe`** : Retire le hash du mot de passe
9. **`res.status(201)`** : Code HTTP 201 = Created

---

#### Méthode : `signIn` (Connexion)

```javascript
exports.signIn = async (req, res) => {
  try {
    const { email, mot_de_passe } = req.body;

    // 1. Validation
    if (!email || !mot_de_passe) {
      return res.status(400).json({
        message: "Email and password are required",
      });
    }

    // 2. Recherche l'utilisateur
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // 3. Vérifie le statut
    if (user.status === "inactif") {
      return res.status(403).json({
        message: "Account is inactive. Please contact support.",
      });
    }

    // 4. Compare le mot de passe avec bcrypt
    const isPasswordValid = await bcrypt.compare(
      mot_de_passe,
      user.mot_de_passe,
    );
    if (!isPasswordValid) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // 5. Met à jour la dernière connexion
    user.derniere_connexion = new Date();
    await user.save();

    // 6. Génère les tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
    );

    // 7. Envoie la réponse
    res.status(200).json({
      message: "Login successful",
      accessToken,
      refreshToken,
    });
  } catch (err) {
    res.status(500).json({ message: "Error logging in", error: err.message });
  }
};
```

### Explications :

- `bcrypt.compare(plainText, hash)` : Compare le mot de passe en clair avec le hash
- **Sécurité** : Même message d'erreur pour email ou mot de passe invalide (pas d'info sur lequel est faux)

---

#### Méthode : `myInfo` (Info utilisateur connecté)

```javascript
exports.myInfo = async (req, res) => {
  try {
    // 1. Récupère l'ID depuis le token (via middleware verifyToken)
    const userId = req.user.userId;

    // 2. Cherche l'utilisateur et exclut le mot de passe
    const user = await User.findById(userId).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // 3. Retourne les infos
    res.status(200).json({
      message: "User info retrieved successfully",
      user: user,
    });
  } catch (err) {
    res.status(500).json({
      message: "Error retrieving user info",
      error: err.message,
    });
  }
};
```

### Explications :

- `req.user.userId` : Injecté par le middleware `verifyToken`
- `.select("-mot_de_passe")` : Exclut le champ mot_de_passe de la requête

---

#### Méthode : `getAllUsers` (Liste tous les users)

```javascript
exports.getAllUsers = async (req, res) => {
  try {
    // Récupère tous les users (Touriste + Organisator)
    const users = await User.find().select("-mot_de_passe");

    res.status(200).json({
      message: "Users retrieved successfully",
      count: users.length,
      users: users,
    });
  } catch (err) {
    res.status(500).json({
      message: "Error retrieving users",
      error: err.message,
    });
  }
};
```

---

#### Méthode : `getUserById` (User par ID)

```javascript
exports.getUserById = async (req, res) => {
  try {
    // Récupère l'ID depuis l'URL (/api/users/:id)
    const user = await User.findById(req.params.id).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "User retrieved successfully",
      user: user,
    });
  } catch (err) {
    res.status(500).json({
      message: "Error retrieving user",
      error: err.message,
    });
  }
};
```

---

### 📄 controllers/touriste.js

**Rôle** : Gestion spécifique aux touristes

#### Méthode : `completeProfileTouriste`

```javascript
const Touriste = require("../models/touriste");

exports.completeProfileTouriste = async (req, res) => {
  try {
    // 1. Récupère l'ID depuis le token
    const userId = req.user.userId;

    // 2. Destructure les champs
    const {
      age,
      num_tel,
      bio,
      pays_origine,
      avatar,
      centres_interet,
      langue_preferee,
      notifications_email,
      notifications_sms,
      consentement_donnees,
    } = req.body;

    // 3. Cherche le touriste
    const touriste = await Touriste.findById(userId);
    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }

    // 4. Vérifie le type
    if (touriste.userType !== "Touriste") {
      return res.status(403).json({
        message: "Cet utilisateur n'est pas un touriste",
      });
    }

    // 5. Met à jour les champs (seulement si fournis)
    if (age !== undefined) touriste.age = age;
    if (num_tel !== undefined) touriste.num_tel = num_tel;
    if (bio !== undefined) touriste.bio = bio;
    if (pays_origine !== undefined) touriste.pays_origine = pays_origine;
    if (avatar !== undefined) touriste.avatar = avatar;
    if (notifications_email !== undefined)
      touriste.notifications_email = notifications_email;
    if (notifications_sms !== undefined)
      touriste.notifications_sms = notifications_sms;
    if (consentement_donnees !== undefined)
      touriste.consentement_donnees = consentement_donnees;

    // Champs spécifiques au touriste
    if (centres_interet !== undefined)
      touriste.centres_interet = centres_interet;
    if (langue_preferee !== undefined)
      touriste.langue_preferee = langue_preferee;

    // 6. Sauvegarde
    await touriste.save();

    // 7. Retourne sans le mot de passe
    const touristeResponse = touriste.toObject();
    delete touristeResponse.mot_de_passe;

    res.status(200).json({
      message: "Profil touriste complété avec succès",
      touriste: touristeResponse,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la complétion du profil touriste",
      error: error.message,
    });
  }
};
```

### Autres méthodes :

- `getAllTouristes` : Liste tous les touristes
- `getTouristeById` : Un touriste par ID
- `updateTouriste` : Met à jour un touriste
- `deleteTouriste` : Supprime un touriste
- `updateCentresInteret` : Met à jour uniquement les centres d'intérêt
- `updateLanguePreferee` : Met à jour uniquement la langue

---

### 📄 controllers/organisator.js

**Rôle** : Gestion spécifique aux organisateurs (structure similaire à touriste.js)

Méthodes principales :

- `completeProfileOrganisator` : Compléter le profil
- `getAllOrganisators` : Liste tous les organisateurs
- `getOrganisatorById` : Un organisateur par ID
- `updateOrganisator` : Mettre à jour
- `deleteOrganisator` : Supprimer

---

## 📂 routes/

Les routes définissent les endpoints de l'API.

### 📄 routes/user.js

```javascript
const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const { refreshToken, verifyToken } = require("../middleware/auth");

// POST /signup - Inscription
router.post("/signup", userController.signUp);

// POST /signin - Connexion
router.post("/signin", userController.signIn);

// POST /refresh-token - Rafraîchir le token
router.post("/refresh-token", refreshToken);

// GET /me - Infos de l'utilisateur connecté (protégé)
router.get("/me", verifyToken, userController.myInfo);

// GET / - Liste tous les users
router.get("/", userController.getAllUsers);

// GET /:id - User par ID
router.get("/:id", userController.getUserById);

module.exports = router;
```

### Explications :

- `router.post('/signup', ...)` : Définit une route POST
- `verifyToken` : Middleware qui protège la route (nécessite un token valide)
- L'ordre des routes est important : `/me` doit être avant `/:id`

---

### 📄 routes/touriste.js

```javascript
const express = require("express");
const router = express.Router();
const touristeController = require("../controllers/touriste");
const { verifyToken } = require("../middleware/auth");

// PUT /complete-profile - Compléter le profil (protégé)
router.put(
  "/complete-profile",
  verifyToken,
  touristeController.completeProfileTouriste,
);

// GET / - Liste tous les touristes
router.get("/", touristeController.getAllTouristes);

// GET /:id - Touriste par ID
router.get("/:id", touristeController.getTouristeById);

// PUT /:id - Mettre à jour (protégé)
router.put("/:id", verifyToken, touristeController.updateTouriste);

// DELETE /:id - Supprimer (protégé)
router.delete("/:id", verifyToken, touristeController.deleteTouriste);

// PATCH /:id/centres-interet - Mettre à jour centres d'intérêt (protégé)
router.patch(
  "/:id/centres-interet",
  verifyToken,
  touristeController.updateCentresInteret,
);

// PATCH /:id/langue-preferee - Mettre à jour langue (protégé)
router.patch(
  "/:id/langue-preferee",
  verifyToken,
  touristeController.updateLanguePreferee,
);

module.exports = router;
```

---

### 📄 routes/organisator.js

```javascript
const express = require("express");
const router = express.Router();
const organisatorController = require("../controllers/organisator");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");

// PUT /complete-profile - Compléter le profil (protégé)
router.put(
  "/complete-profile",
  verifyToken,
  organisatorController.completeProfileOrganisator,
);

// GET / - Liste tous les organisateurs
router.get("/", organisatorController.getAllOrganisators);

// GET /:id - Organisateur par ID
router.get("/:id", organisatorController.getOrganisatorById);

// PUT /:id - Mettre à jour (protégé)
router.put("/:id", verifyToken, organisatorController.updateOrganisator);

// DELETE /:id - Supprimer (protégé, seulement organisateurs)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  organisatorController.deleteOrganisator,
);

module.exports = router;
```

---

## 🔐 Sécurité

### Hashage des mots de passe

- **bcrypt** : Utilise un algorithme de hashage sécurisé avec salt
- `bcrypt.hash(password, 10)` : 10 = nombre de rounds (plus = plus sécurisé mais plus lent)

### JWT (JSON Web Tokens)

- **Access Token** : 15 minutes, pour les requêtes quotidiennes
- **Refresh Token** : 7 jours, pour renouveler l'access token

### Protection des routes

- Middleware `verifyToken` : Vérifie le token avant d'accéder à la route
- Middleware `verifyOrganisator` : Vérifie en plus que l'utilisateur est un Organisator

---

## 🌐 ENDPOINTS DE L'API

### Authentification

#### POST /api/users/signup

**Inscription d'un nouvel utilisateur**

Request Body :

```json
{
  "fullname": "John Doe",
  "email": "john@example.com",
  "mot_de_passe": "password123",
  "userType": "Touriste",
  "nom_entreprise": "Requis si Organisator"
}
```

Response (201 Created) :

```json
{
  "message": "User registered successfully",
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "_id": "65f1a2b3c4d5e6f7a8b9c0d1",
    "fullname": "John Doe",
    "email": "john@example.com",
    "userType": "Touriste",
    "status": "actif",
    "date_inscription": "2024-03-15T10:30:00.000Z"
  }
}
```

---

#### POST /api/users/signin

**Connexion**

Request Body :

```json
{
  "email": "john@example.com",
  "mot_de_passe": "password123"
}
```

Response (200 OK) :

```json
{
  "message": "Login successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

#### POST /api/users/refresh-token

**Rafraîchir l'access token**

Request Body :

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

Response (200 OK) :

```json
{
  "message": "Token refreshed successfully",
  "accessToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

### Utilisateurs

#### GET /api/users

**Liste tous les utilisateurs**

Response (200 OK) :

```json
{
  "message": "Users retrieved successfully",
  "count": 42,
  "users": [
    {
      "_id": "65f1a2b3c4d5e6f7a8b9c0d1",
      "fullname": "John Doe",
      "email": "john@example.com",
      "userType": "Touriste",
      "status": "actif"
    },
    ...
  ]
}
```

---

#### GET /api/users/me

**Infos de l'utilisateur connecté** (Protégé)

Headers :

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

Response (200 OK) :

```json
{
  "message": "User info retrieved successfully",
  "user": {
    "_id": "65f1a2b3c4d5e6f7a8b9c0d1",
    "fullname": "John Doe",
    "email": "john@example.com",
    "userType": "Touriste",
    "age": 30,
    "num_tel": "0612345678",
    "centres_interet": ["Plage", "Randonnée"],
    "langue_preferee": "Français"
  }
}
```

---

#### GET /api/users/:id

**Utilisateur par ID**

Response (200 OK) : (même structure que /me)

---

### Touristes

#### GET /api/touristes

**Liste tous les touristes**

#### GET /api/touristes/:id

**Touriste par ID**

#### PUT /api/touristes/complete-profile

**Compléter le profil touriste** (Protégé)

Request Body :

```json
{
  "age": 30,
  "num_tel": "0612345678",
  "bio": "Passionné de voyages",
  "pays_origine": "France",
  "centres_interet": ["Plage", "Randonnée", "Culture"],
  "langue_preferee": "Français"
}
```

#### PUT /api/touristes/:id

**Mettre à jour un touriste** (Protégé)

#### DELETE /api/touristes/:id

**Supprimer un touriste** (Protégé)

#### PATCH /api/touristes/:id/centres-interet

**Mettre à jour les centres d'intérêt** (Protégé)

#### PATCH /api/touristes/:id/langue-preferee

**Mettre à jour la langue** (Protégé)

---

### Organisateurs

#### GET /api/organisators

**Liste tous les organisateurs**

#### GET /api/organisators/:id

**Organisateur par ID**

#### PUT /api/organisators/complete-profile

**Compléter le profil organisateur** (Protégé)

Request Body :

```json
{
  "age": 45,
  "num_tel": "0612345678",
  "nom_entreprise": "Travelo Tours",
  "numero_licence": "LIC123456",
  "adresse_entreprise": "123 Rue de Paris, 75001 Paris",
  "site_web": "https://travelotours.com",
  "specialites": ["Tours culturels", "Aventure", "Plongée"],
  "certifications": ["ISO 9001", "IATA"]
}
```

#### PUT /api/organisators/:id

**Mettre à jour un organisateur** (Protégé)

#### DELETE /api/organisators/:id

**Supprimer un organisateur** (Protégé, Organisator seulement)

---

## 📊 Codes de statut HTTP

- **200 OK** : Requête réussie
- **201 Created** : Ressource créée (inscription)
- **400 Bad Request** : Données invalides
- **401 Unauthorized** : Token manquant ou invalide
- **403 Forbidden** : Accès refusé (manque de permissions)
- **404 Not Found** : Ressource non trouvée
- **500 Internal Server Error** : Erreur serveur

---

## 🧪 Tests avec Postman/Insomnia

### 1. Inscription (POST /api/users/signup)

```
POST http://localhost:3000/api/users/signup
Content-Type: application/json

{
  "fullname": "Test User",
  "email": "test@example.com",
  "mot_de_passe": "test123",
  "userType": "Touriste"
}
```

### 2. Connexion (POST /api/users/signin)

```
POST http://localhost:3000/api/users/signin
Content-Type: application/json

{
  "email": "test@example.com",
  "mot_de_passe": "test123"
}
```

### 3. Route protégée (GET /api/users/me)

```
GET http://localhost:3000/api/users/me
Authorization: Bearer {votre_access_token}
```

---

## 🚀 Déploiement

### Variables à modifier pour la production :

1. **JWT_SECRET** : Générer une clé sécurisée (ex: `openssl rand -base64 32`)
2. **REFRESH_TOKEN_SECRET** : Générer une autre clé
3. **MONGODB_URI** : URL de production (MongoDB Atlas)
4. **CLOUD_NAME, API_KEY, API_SECRET** : Identifiants Cloudinary de production

---

## 📝 Résumé des Dépendances

```json
{
  "bcryptjs": "Hashage des mots de passe",
  "cloudinary": "Stockage d'images dans le cloud",
  "dotenv": "Chargement des variables d'environnement",
  "express": "Framework web Node.js",
  "jsonwebtoken": "Génération et vérification des JWT",
  "mongoose": "ODM pour MongoDB",
  "multer": "Gestion des uploads de fichiers",
  "multer-storage-cloudinary": "Intégration Multer + Cloudinary",
  "nodemon": "Redémarrage auto en développement"
}
```

---

## 📞 Support

Pour toute question sur le backend, consultez :

- La documentation MongoDB : https://docs.mongodb.com/
- La documentation Express : https://expressjs.com/
- La documentation JWT : https://jwt.io/

---

## ✅ Checklist de vérification

- [x] MongoDB connecté
- [x] Variables .env configurées
- [x] Tokens JWT fonctionnels
- [x] Hashage des mots de passe
- [x] Routes protégées
- [x] Modèles avec héritage (discriminators)
- [x] Gestion des erreurs
- [x] Upload d'images (Cloudinary)

---

**🎉 Votre backend Travelo est prêt à être utilisé !**
