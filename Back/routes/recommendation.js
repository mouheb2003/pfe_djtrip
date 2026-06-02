const express = require("express");
const router = express.Router();
const recommendationController = require("../controllers/recommendation");
const wrapRouter = require("../middleware/wrapRouter");
const { verifyToken, verifyTouriste } = require("../middleware/auth");
const { cacheGet } = require("../middleware/cache");

// Get recommendations based on tourist interests
router.get(
  "/",
  verifyToken,
  verifyTouriste,
  cacheGet("recommendations:user", 300), // Cache for 5 mins
  recommendationController.getRecommendations
);

module.exports = wrapRouter(router);
