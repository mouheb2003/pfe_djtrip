const express = require("express");
const router = express.Router();
const lieuController = require("../controllers/lieu");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");
const validate = require("../middleware/validate");
const {
  createLieuSchema,
  updateLieuSchema,
} = require("../validators/lieu");

// ─── Public routes ────────────────────────────────────────────────────────────
router.get("/", lieuController.getAllLieux);
router.get("/:id", lieuController.getLieuById);

// ─── Protected Organizer routes (Lieux management) ──────────────────────────
// Note: Management typically done by admin/organizer in this app model
router.post(
  "/",
  verifyToken,
  // verifyOrganisator, // Enable if only organizers can add places
  validate(createLieuSchema),
  lieuController.createLieu
);

router.put(
  "/:id",
  verifyToken,
  // verifyOrganisator,
  validate(updateLieuSchema),
  lieuController.updateLieu
);

router.delete(
  "/:id",
  verifyToken,
  // verifyOrganisator,
  lieuController.deleteLieu
);

module.exports = router;
