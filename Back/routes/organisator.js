const express = require("express");
const router = express.Router();
const organisatorController = require("../controllers/organisator");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");

// Complete organizer profile (protected, requires token)
router.put(
  "/complete-profile",
  verifyToken,
  invalidateCache(["organisators", "users"]),
  organisatorController.completeProfileOrganisator,
);

// Get all organizers
router.get(
  "/",
  cacheGet("organisators:all", 60),
  organisatorController.getAllOrganisators,
);

// Get an organizer by ID
router.get(
  "/:id",
  cacheGet("organisators:by-id", 60),
  organisatorController.getOrganisatorById,
);

// Update an organizer (protected)
router.put(
  "/:id",
  verifyToken,
  invalidateCache(["organisators", "users"]),
  organisatorController.updateOrganisator,
);

// Delete an organizer (protected, organizers only)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["organisators", "users"]),
  organisatorController.deleteOrganisator,
);

module.exports = wrapRouter(router);
