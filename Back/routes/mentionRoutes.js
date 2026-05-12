/**
 * Routes pour la gestion des mentions dans les posts
 * Endpoints pour la détection, validation, et sauvegarde des mentions
 */

const express = require('express');
const router = express.Router();
const mentionController = require('../controllers/mentionController');
const { verifyToken } = require('../middleware/auth');

// GET /api/mentions/search - Rechercher des utilisateurs pour l'autocomplétion des mentions
router.get('/search', verifyToken, mentionController.searchMentions);

// POST /api/mentions/validate - Valider les mentions d'un contenu
router.post('/validate', verifyToken, mentionController.validateMentions);

// POST /api/mentions/save/:postId - Sauvegarder les mentions dans un post
router.post('/save/:postId', verifyToken, mentionController.saveMentions);

// GET /api/mentions/post/:postId - Récupérer les mentions d'un post
router.get('/post/:postId', verifyToken, mentionController.getPostMentions);

module.exports = router;
