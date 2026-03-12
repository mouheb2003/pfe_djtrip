const express = require("express");
const router = express.Router();
const avisController = require("../controllers/avis");
const { verifyToken, verifyTouriste } = require("../middleware/auth");

// ─── Public routes ────────────────────────────────────────────────────────────
// Get all reviews for an activity
router.get("/activite/:activiteId", avisController.getActivityReviews);

// Get all ratings for an organizer
router.get(
  "/organisateur/:organisateurId",
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
  avisController.getMyOrganisateurRating,
);

// Submit a review for an activity (tourist only)
router.post(
  "/activite/:activiteId",
  verifyToken,
  verifyTouriste,
  avisController.submitActivityReview,
);

// Submit a rating for an organizer (tourist only)
router.post(
  "/organisateur/:organisateurId",
  verifyToken,
  verifyTouriste,
  avisController.submitOrganisateurRating,
);

// Delete own review/rating (tourist only)
router.delete(
  "/:avisId",
  verifyToken,
  verifyTouriste,
  avisController.deleteAvis,
);

module.exports = router;
