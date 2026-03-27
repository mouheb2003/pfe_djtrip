const express = require("express");
const router = express.Router();
const organisatorController = require("../controllers/organisator");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");

// Complete organizer profile (protected, requires token)
router.put(
  "/complete-profile",
  verifyToken,
  organisatorController.completeProfileOrganisator,
);

// Get all organizers
router.get("/", organisatorController.getAllOrganisators);

// Get an organizer by ID
router.get("/:id", organisatorController.getOrganisatorById);

// Update an organizer (protected)
router.put("/:id", verifyToken, organisatorController.updateOrganisator);

// Delete an organizer (protected, organizers only)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  organisatorController.deleteOrganisator,
);

module.exports = router;
