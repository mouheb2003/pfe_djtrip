const express = require("express");
const router = express.Router();
const avisController = require("../controllers/avis");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken, verifyTouriste } = require("../middleware/auth");

// ─── Public routes ────────────────────────────────────────────────────────────
// Get all reviews for an activity
router.get(
  "/activite/:activiteId",
  cacheGet("avis:activite", 60),
  avisController.getActivityReviews,
);

// Get all ratings for an organizer
router.get(
  "/organisateur/:organisateurId",
  cacheGet("avis:organisateur", 60),
  avisController.getOrganisateurRatings,
);

// ─── Authenticated tourist routes ─────────────────────────────────────────────
// Check if I already reviewed a specific activity
router.get(
  "/my-review/activite/:activiteId",
  verifyToken,
  verifyTouriste,
  avisController.getMyActivityReview,
);

// Check if I already rated a specific organizer
router.get(
  "/my-rating/organisateur/:organisateurId",
  verifyToken,
  verifyTouriste,
  cacheGet("avis:my-rating", 60),
  avisController.getMyOrganisateurRating,
);

// Submit a review for an activity (tourist only)
router.post(
  "/activite/:activiteId",
  verifyToken,
  verifyTouriste,
  invalidateCache(["avis", "activites", "organisators"]),
  avisController.submitActivityReview,
);

// Submit a rating for an organizer (tourist only)
router.post(
  "/organisateur/:organisateurId",
  verifyToken,
  verifyTouriste,
  invalidateCache(["avis", "activites", "organisators"]),
  avisController.submitOrganisateurRating,
);

// Update own review/rating (tourist only)
router.put(
  "/:avisId",
  verifyToken,
  verifyTouriste,
  invalidateCache(["avis", "activites", "organisators"]),
  avisController.updateAvis,
);

// Delete own review/rating (tourist only)
router.delete(
  "/:avisId",
  verifyToken,
  verifyTouriste,
  invalidateCache(["avis", "activites", "organisators"]),
  avisController.deleteAvis,
);

module.exports = wrapRouter(router);
