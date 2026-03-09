# Email Verification Setup - Backend

## Configuration Email

### Option 1: Gmail (Pour le développement)

1. Ouvrez le fichier `.env`
2. Configurez les variables suivantes:

   ```env
   EMAIL_SERVICE=gmail
   EMAIL_USER=votre-email@gmail.com
   EMAIL_PASSWORD=votre-mot-de-passe-application
   ```

3. **Obtenir un mot de passe d'application Gmail:**
   - Activez la vérification en 2 étapes sur votre compte Google
   - Allez sur: https://myaccount.google.com/apppasswords
   - Créez un mot de passe d'application pour "Mail"
   - Utilisez ce mot de passe dans `EMAIL_PASSWORD`

### Option 2: Services Professionnels (Pour la production)

Pour un environnement de production, utilisez un service professionnel:

- **SendGrid** (recommandé)
- **Mailgun**
- **AWS SES**
- **Postmark**

Modifiez `services/email.js` pour configurer le transporteur selon le service choisi.

## Fonctionnalités Implémentées

### 1. Inscription avec envoi de code

- Endpoint: `POST /api/users/signup`
- Génère un code de vérification à 6 chiffres
- Envoie un email avec le code
- Code valide pendant 15 minutes

### 2. Vérification de l'email

- Endpoint: `POST /api/auth/verify-email`
- Headers: `Authorization: Bearer <token>`
- Body: `{ "code": "123456" }`
- Marque l'email comme vérifié
- Envoie un email de bienvenue

### 3. Renvoi du code

- Endpoint: `POST /api/auth/resend-verification`
- Body: `{ "email": "user@example.com" }`
- Génère et envoie un nouveau code
- Nouveau code valide pendant 15 minutes

## Modèle User Mis à Jour

Nouveaux champs ajoutés:

```javascript
{
  emailVerified: Boolean,          // État de vérification
  verificationCode: String,        // Code à 6 chiffres
  verificationCodeExpiry: Date     // Expiration du code
}
```

## Test de l'API

### 1. S'inscrire

```bash
curl -X POST http://localhost:3000/api/users/signup \
  -H "Content-Type: application/json" \
  -d '{
    "fullname": "Test User",
    "email": "test@example.com",
    "mot_de_passe": "password123",
    "userType": "Touriste"
  }'
```

### 2. Vérifier l'email

```bash
curl -X POST http://localhost:3000/api/auth/verify-email \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "code": "123456"
  }'
```

### 3. Renvoyer le code

```bash
curl -X POST http://localhost:3000/api/auth/resend-verification \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com"
  }'
```

## Mode Test (Sans email réel)

Si vous voulez tester sans configurer d'email:

1. Commentez l'envoi d'email dans `controllers/user.js`:

   ```javascript
   // const emailResult = await emailService.sendVerificationEmail(...);
   console.log("Verification code:", verificationCode); // Afficher dans console
   ```

2. Le code sera affiché dans la console du serveur
3. Utilisez ce code pour tester la vérification

## Sécurité

⚠️ **Important pour la production:**

- Ne commitez JAMAIS vos credentials dans le .env
- Utilisez des variables d'environnement sécurisées
- Limitez le nombre de tentatives de vérification
- Ajoutez un rate limiting sur les endpoints
- Utilisez HTTPS en production
