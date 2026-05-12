/**
 * Routes pour la gestion des usernames
 * Endpoints pour générer, valider, et mettre à jour les usernames
 */

const express = require('express');
const router = express.Router();
const usernameController = require('../controllers/usernameController');
const { authenticateToken } = require('../middleware/auth');

// Middleware d'authentification pour toutes les routes
router.use(authenticateToken);

// POST /api/username/suggestions - Générer des suggestions de usernames
router.post('/suggestions', usernameController.generateUsernameSuggestions);

// GET /api/username/check/:username - Vérifier la disponibilité d'un username
router.get('/check/:username', usernameController.checkUsernameAvailability);

// PUT /api/username/update - Mettre à jour le username de l'utilisateur
router.put('/update', usernameController.updateUsername);

// POST /api/username/generate-auto - Générer automatiquement un username
router.post('/generate-auto', usernameController.generateAutoUsername);

module.exports = router;
