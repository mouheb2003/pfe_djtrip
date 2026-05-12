const express = require('express');
const router = express.Router();
const aiTextController = require('../controllers/aiText');
const authMiddleware = require('../middleware/auth');

// AI Text Processing Endpoint
router.post('/process', authMiddleware.verifyToken, aiTextController.processText);

// Health check for AI service
router.get('/health', aiTextController.healthCheck);

module.exports = router;
