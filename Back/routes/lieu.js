const express = require("express");
const router = express.Router();
const lieuController = require("../controllers/lieu");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");
const validate = require("../middleware/validate");
const { createLieuSchema, updateLieuSchema, reviewSchema } = require("../validators/lieu");

// ─── Public routes ────────────────────────────────────────────────────────────
router.get("/", cacheGet("lieux:all", 60), lieuController.getAllLieux);
router.get("/featured", cacheGet("lieux:featured", 60), lieuController.getFeaturedLieux);
router.get("/type/:type", cacheGet("lieux:by-type", 60), lieuController.getLieuxByType);
router.get("/:id", cacheGet("lieux:by-id", 60), lieuController.getLieuById);

// ─── Protected Organizer routes (Lieux management) ──────────────────────────
// Note: Management typically done by admin/organizer in this app model
router.post(
  "/",
  verifyToken,
  // verifyOrganisator, // Enable if only organizers can add places
  validate(createLieuSchema),
  invalidateCache(["lieux"]),
  lieuController.createLieu,
);

router.put(
  "/:id",
  verifyToken,
  // verifyOrganisator,
  validate(updateLieuSchema),
  invalidateCache(["lieux"]),
  lieuController.updateLieu,
);

router.delete(
  "/:id",
  verifyToken,
  // verifyOrganisator,
  invalidateCache(["lieux"]),
  lieuController.deleteLieu,
);

// Review routes
router.post(
  "/:id/reviews",
  verifyToken,
  validate(reviewSchema),
  invalidateCache(["lieux"]),
  lieuController.addReview,
);

module.exports = wrapRouter(router);
