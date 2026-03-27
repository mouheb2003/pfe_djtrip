const express = require("express");
const router = express.Router();
const activiteController = require("../controllers/activite");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");
const upload = require("../middleware/upload");
const validate = require("../middleware/validate");
const {
  createActiviteSchema,
  updateActiviteSchema,
} = require("../validators/activite");

// ─── Public routes ────────────────────────────────────────────────────────────

// Get all activities (optional filters: search, sort, prix_min, prix_max, type_activite, niveau_difficulte, temporalite)
router.get("/", activiteController.getAllActivites);

// Search for activities (legacy endpoint — unified search now via GET / with ?search=)
router.get("/search", activiteController.searchActivites);

// ─── Protected Organizer routes ───────────────────────────────────────────────

// Get my active activities (ongoing and upcoming)
router.get(
  "/my-activities",
  verifyToken,
  verifyOrganisator,
  activiteController.getMyActivities,
);

// Get my archived activities (past)
router.get(
  "/archived",
  verifyToken,
  verifyOrganisator,
  activiteController.getArchivedActivities,
);

// ─── Parameterized public routes ──────────────────────────────────────────────

// ⚠️  These MUST come after named routes above to avoid route conflicts
// Get an activity by ID
router.get("/:id", activiteController.getActiviteById);

// Get activities for a specific organizer
router.get(
  "/organisateur/:organisateurId",
  activiteController.getActivitesByOrganisateur,
);

// ─── Protected write routes ───────────────────────────────────────────────────

// Create a new activity (organizers only) — with Joi validation
router.post(
  "/",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  validate(createActiviteSchema),
  activiteController.createActivite,
);

// Update an activity (owner only) — with Joi validation
router.put(
  "/:id",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  validate(updateActiviteSchema),
  activiteController.updateActivite,
);

// Delete an activity (owner only)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  activiteController.deleteActivite,
);

module.exports = router;
