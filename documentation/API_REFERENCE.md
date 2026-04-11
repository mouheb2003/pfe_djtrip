# 📡 API Reference - Travelo Backend

Documentation complète de toutes les routes API disponibles dans le backend Travelo.

**Base URL** : `http://192.168.3.12:3000` (développement)

---

## 🔐 Authentication

Toutes les routes protégées nécessitent un header `Authorization` :

```
Authorization: Bearer <access_token>
```

---

## 📋 Table des Matières

1. [Authentification](#authentification)
2. [Profil Utilisateur](#profil-utilisateur)
3. [Upload d'Images](#upload-dimages)
4. [Préférences](#préférences)
5. [Codes d'Erreur](#codes-derreur)

---

## 🔑 Authentification

### POST /users/signup

Créer un nouveau compte utilisateur.

**Headers** :

```
Content-Type: application/json
```

**Body** :

```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "nom_complet": "John Doe",
  "userType": "Touriste" // ou "Organisator"
}
```

**Response 201** :

```json
{
  "message": "Utilisateur créé avec succès",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "65abc123...",
    "email": "user@example.com",
    "nom_complet": "John Doe",
    "userType": "Touriste",
    "status": "inactif",
    "createdAt": "2026-02-28T10:00:00.000Z"
  }
}
```

**Errors** :

- `400` - Email déjà utilisé
- `400` - Champs manquants
- `400` - Format email invalide
- `400` - Mot de passe trop faible

---

### POST /users/signin

Connexion à un compte existant.

**Headers** :

```
Content-Type: application/json
```

**Body** :

```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

**Response 200** :

```json
{
  "message": "Connexion réussie",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "_id": "65abc123...",
    "email": "user@example.com",
    "nom_complet": "John Doe",
    "userType": "Touriste",
    "status": "actif", // ✅ Mis à jour automatiquement
    "derniere_connexion": "2026-02-28T10:30:00.000Z", // ✅ Mis à jour
    "age": 25,
    "telephone": "+212600000000",
    "pays": "Maroc",
    "langue_preferee": "Français",
    "bio": "Passionné de voyages",
    "avatar": "https://res.cloudinary.com/.../avatar.jpg",
    "centres_interet": ["Plages", "Aventure"],
    "accept_notifications_email": true,
    "accept_notifications_sms": false,
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-02-28T10:30:00.000Z"
  }
}
```

**Errors** :

- `400` - Email ou mot de passe incorrect
- `403` - Compte inactif (180 jours sans connexion)
- `400` - Champs manquants

---

### POST /users/logout

Déconnexion de l'utilisateur.

**Headers** :

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Body** : (Aucun)

**Response 200** :

```json
{
  "message": "Déconnexion réussie. À bientôt !"
}
```

**Side Effects** :

- ✅ Met à jour `status` → `"inactif"`
- ✅ Conserve `derniere_connexion`

**Errors** :

- `401` - Token manquant ou invalide
- `404` - Utilisateur non trouvé

---

### POST /users/refresh

Rafraîchir le token d'accès.

**Headers** :

```
Content-Type: application/json
```

**Body** :

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response 200** :

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors** :

- `401` - Refresh token invalide ou expiré
- `400` - Refresh token manquant

---

## 👤 Profil Utilisateur

### GET /users/profile

Récupérer le profil de l'utilisateur connecté.

**Headers** :

```
Authorization: Bearer <access_token>
```

**Response 200** :

```json
{
  "_id": "65abc123...",
  "email": "user@example.com",
  "nom_complet": "John Doe",
  "userType": "Touriste",
  "age": 25,
  "telephone": "+212600000000",
  "pays": "Maroc",
  "langue_preferee": "Français",
  "bio": "Passionné de voyages et découvertes",
  "avatar": "https://res.cloudinary.com/.../avatar.jpg",
  "centres_interet": ["Plages", "Aventure", "Culture"],
  "accept_notifications_email": true,
  "accept_notifications_sms": false,
  "status": "actif",
  "derniere_connexion": "2026-02-28T10:30:00.000Z",
  "createdAt": "2026-01-01T00:00:00.000Z",
  "updatedAt": "2026-02-28T10:35:00.000Z"
}
```

**Errors** :

- `401` - Token invalide
- `404` - Utilisateur non trouvé

---

### PUT /users/profile

Mettre à jour le profil utilisateur.

**Headers** :

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Body** (tous les champs sont optionnels) :

```json
{
  "nom_complet": "John Smith",
  "age": 26,
  "telephone": "+212611111111",
  "pays": "France",
  "langue_preferee": "English",
  "bio": "Nouvelle bio ici",
  "accept_notifications_email": false,
  "accept_notifications_sms": true
}
```

**Validations** :

- `age` : Entre 13 et 120
- `telephone` : Format international recommandé
- `bio` : Maximum 500 caractères
- `langue_preferee` : Uniquement pour `userType: "Touriste"`

**Response 200** :

```json
{
  "message": "Profil mis à jour avec succès",
  "user": {
    "_id": "65abc123...",
    "email": "user@example.com",
    "nom_complet": "John Smith",
    "age": 26,
    "telephone": "+212611111111",
    "pays": "France",
    "langue_preferee": "English",
    "bio": "Nouvelle bio ici",
    "accept_notifications_email": false,
    "accept_notifications_sms": true,
    "updatedAt": "2026-02-28T10:40:00.000Z"
  }
}
```

**Errors** :

- `401` - Token invalide
- `400` - Âge invalide (hors de 13-120)
- `400` - Bio trop longue (>500 caractères)
- `404` - Utilisateur non trouvé

---

### PUT /users/preferences

Mettre à jour les centres d'intérêt.

**Headers** :

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Body** :

```json
{
  "centres_interet": [
    "Plages",
    "Montagnes",
    "Aventure",
    "Culture",
    "Gastronomie"
  ]
}
```

**Préférences Disponibles** (20 options) :

- Plages
- Montagnes
- Villes
- Aventure
- Culture
- Gastronomie
- Nature
- Histoire
- Shopping
- Sport
- Détente
- Voyage en famille
- Voyage en couple
- Voyage solo
- Photographie
- Randonnée
- Plongée
- Camping
- Luxe
- Budget friendly

**Response 200** :

```json
{
  "message": "Préférences mises à jour avec succès",
  "user": {
    "_id": "65abc123...",
    "centres_interet": [
      "Plages",
      "Montagnes",
      "Aventure",
      "Culture",
      "Gastronomie"
    ],
    "updatedAt": "2026-02-28T10:45:00.000Z"
  }
}
```

**Errors** :

- `401` - Token invalide
- `400` - Format de données invalide
- `404` - Utilisateur non trouvé

---

## 📷 Upload d'Images

### POST /users/avatar

Uploader une photo de profil vers Cloudinary.

**Headers** :

```
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

**Body (Form Data)** :

```
avatar: <fichier image>
```

**Formats Acceptés** :

- JPEG (.jpg, .jpeg)
- PNG (.png)
- WebP (.webp)
- GIF (.gif)

**Taille Maximum** : 10 MB

**Traitement Automatique** :

- ✅ Upload vers Cloudinary
- ✅ Redimensionnement (400x400)
- ✅ Optimisation qualité (85%)
- ✅ Génération d'URL sécurisée (HTTPS)
- ✅ Mise à jour du champ `avatar` dans MongoDB

**Response 200** :

```json
{
  "message": "Avatar mis à jour avec succès",
  "avatarUrl": "https://res.cloudinary.com/dx5bpwemu/image/upload/v1234567890/avatars/user_123.jpg"
}
```

**Errors** :

- `401` - Token invalide
- `400` - Aucun fichier fourni
- `400` - Format de fichier non supporté
- `400` - Fichier trop volumineux (>10MB)
- `500` - Erreur d'upload Cloudinary
- `404` - Utilisateur non trouvé

---

## 🧪 Tests et Validation

### POST /users/test-protected

Route de test pour vérifier l'authentification.

**Headers** :

```
Authorization: Bearer <access_token>
```

**Response 200** :

```json
{
  "message": "Accès autorisé",
  "userId": "65abc123...",
  "userType": "Touriste"
}
```

**Errors** :

- `401` - Token manquant ou invalide

---

## 📊 Codes d'Erreur

### Erreurs d'Authentification

| Code | Message                       | Description                                  |
| ---- | ----------------------------- | -------------------------------------------- |
| 400  | Email already exists          | Email déjà utilisé lors de l'inscription     |
| 400  | Invalid email or password     | Identifiants incorrects lors de la connexion |
| 401  | No token provided             | Header Authorization manquant                |
| 401  | Invalid token                 | Token JWT invalide ou expiré                 |
| 401  | Failed to authenticate token  | Problème de vérification du token            |
| 403  | Account inactive for 180 days | Compte suspendu pour inactivité              |

### Erreurs de Validation

| Code | Message                        | Description                   |
| ---- | ------------------------------ | ----------------------------- |
| 400  | Missing required fields        | Champs obligatoires manquants |
| 400  | Age must be between 13 and 120 | Âge hors limites              |
| 400  | Bio too long (max 500 chars)   | Bio dépassant 500 caractères  |
| 400  | Invalid file format            | Format d'image non supporté   |
| 400  | File too large                 | Fichier >10MB                 |

### Erreurs Serveur

| Code | Message                  | Description                    |
| ---- | ------------------------ | ------------------------------ |
| 404  | User not found           | Utilisateur inexistant en base |
| 500  | Server error             | Erreur interne du serveur      |
| 500  | Cloudinary upload failed | Problème d'upload d'image      |
| 500  | Database error           | Erreur MongoDB                 |

---

## 🔒 Sécurité

### Tokens JWT

**Access Token** :

- Durée de vie : 15 minutes
- Utilisé pour toutes les requêtes authentifiées
- Stocké dans `Authorization: Bearer <token>`

**Refresh Token** :

- Durée de vie : 7 jours
- Utilisé pour obtenir un nouveau access token
- Stocké côté client (SharedPreferences)

### Mot de Passe

**Règles** :

- Minimum 8 caractères
- Au moins 1 majuscule
- Au moins 1 minuscule
- Au moins 1 chiffre
- Au moins 1 caractère spécial recommandé

**Stockage** :

- Hashé avec bcrypt (10 rounds)
- Jamais retourné dans les réponses API

### Statut du Compte

**Règles Automatiques** :

- ✅ Login → `status = "actif"`
- ✅ Logout → `status = "inactif"`
- ✅ 180 jours sans connexion → compte suspendu
- ✅ Reconnexion → réactivation automatique

---

## 🧪 Exemples de Requêtes

### cURL

#### Inscription

```bash
curl -X POST http://192.168.3.12:3000/users/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "nom_complet": "Test User",
    "userType": "Touriste"
  }'
```

#### Connexion

```bash
curl -X POST http://192.168.3.12:3000/users/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!"
  }'
```

#### Récupérer le Profil

```bash
curl -X GET http://192.168.3.12:3000/users/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Mettre à Jour le Profil

```bash
curl -X PUT http://192.168.3.12:3000/users/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "age": 26,
    "pays": "France",
    "bio": "Nouvelle bio"
  }'
```

#### Upload Avatar

```bash
curl -X POST http://192.168.3.12:3000/users/avatar \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -F "avatar=@/path/to/image.jpg"
```

#### Déconnexion

```bash
curl -X POST http://192.168.3.12:3000/users/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### PowerShell

#### Inscription

```powershell
$body = @{
    email = "test@example.com"
    password = "Test123!"
    nom_complet = "Test User"
    userType = "Touriste"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.3.12:3000/users/signup" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

#### Connexion

```powershell
$body = @{
    email = "test@example.com"
    password = "Test123!"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://192.168.3.12:3000/users/signin" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body

$token = $response.token
Write-Host "Token: $token"
```

#### Récupérer le Profil

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

Invoke-RestMethod -Uri "http://192.168.3.12:3000/users/profile" `
  -Method Get `
  -Headers $headers
```

---

## 📝 Notes de Développement

### CORS

Le serveur accepte toutes les origines en développement :

```javascript
app.use(cors({ origin: "*" }));
```

⚠️ **En production** : Spécifier les origines autorisées dans `.env`

### Uploads

Les fichiers sont stockés temporairement dans `/tmp` avant upload Cloudinary.

### Logs

Les erreurs sont loggées dans la console du serveur Node.js.

### Rate Limiting

⚠️ **À implémenter** : Protection contre les attaques par force brute

---

## 🔗 Liens Utiles

- [Documentation Frontend](README.md)
- [Guide d'Installation](SETUP.md)
- [Liste des Fonctionnalités](FEATURES.md)
- [Changelog](CHANGELOG_28-02-2026.md)

---

**Dernière mise à jour** : 28 Février 2026
