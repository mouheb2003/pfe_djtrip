const express = require("express");
const router = express.Router();
const activiteController = require("../controllers/activite");
const aiImageGenerator = require("../controllers/aiImageGenerator");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  verifyToken,
  verifyOrganisator,
  verifyAdmin,
} = require("../middleware/auth");
const upload = require("../middleware/upload");
const validate = require("../middleware/validate");
const {
  createActiviteSchema,
  updateActiviteSchema,
} = require("../validators/activite");

// ─── Public routes ────────────────────────────────────────────────────────────

// Get all activities (optional filters: search, sort, prix_min, prix_max, type_activite, niveau_difficulte, temporalite)
router.get(
  "/",
  cacheGet("activites:all", 60),
  activiteController.getAllActivites,
);

// Get ALL global activities grouped by timeline (Upcoming, Ongoing, Past)
// This is for the central MyActivities global screen
router.get(
  "/timeline",
  cacheGet("activites:timeline", 60),
  activiteController.getGlobalActivitiesByTimeline,
);

// Search for activities (legacy endpoint — unified search now via GET / with ?search=)
router.get(
  "/search",
  cacheGet("activites:search", 60),
  activiteController.searchActivites,
);

// ─── Protected Organizer routes ───────────────────────────────────────────────

// Get my active activities (ongoing and upcoming)
router.get(
  "/my-activities",
  verifyToken,
  verifyOrganisator,
  cacheGet("activites:mine", 60),
  activiteController.getMyActivities,
);

// Get my archived activities (past)
router.get(
  "/archived",
  verifyToken,
  verifyOrganisator,
  cacheGet("activites:archived", 60),
  activiteController.getArchivedActivities,
);

// Admin activity management
router.get(
  "/admin",
  verifyToken,
  verifyAdmin,
  cacheGet("activites:admin", 60),
  activiteController.getAdminActivites,
);
router.post(
  "/admin",
  verifyToken,
  verifyAdmin,
  invalidateCache(["activites"]),
  activiteController.createAdminActivite,
);
router.put(
  "/admin/:id",
  verifyToken,
  verifyAdmin,
  invalidateCache(["activites"]),
  activiteController.updateAdminActivite,
);
router.delete(
  "/admin/:id",
  verifyToken,
  verifyAdmin,
  invalidateCache(["activites"]),
  activiteController.deleteAdminActivite,
);

// Get activities for a specific organizer
router.get(
  "/organisateur/:organisateurId",
  cacheGet("activites:organisateur", 60),
  activiteController.getActivitesByOrganisateur,
);

// ─── Parameterized public routes ──────────────────────────────────────────────

// ⚠️  These MUST come after named routes above to avoid route conflicts
// Get an activity by ID (no cache to ensure fresh data on navigation)
router.get(
  "/:id",
  activiteController.getActiviteById,
);

// ─── Protected write routes ───────────────────────────────────────────────────

// Create a new activity (organizers only) — with Joi validation
router.post(
  "/",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  validate(createActiviteSchema),
  invalidateCache(["activites"]),
  activiteController.createActivite,
);

// Update an activity (owner only) — with Joi validation
router.put(
  "/:id",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  validate(updateActiviteSchema),
  invalidateCache(["activites"]),
  activiteController.updateActivite,
);

// Delete an activity (owner only)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["activites"]),
  activiteController.deleteActivite,
);

// Generate AI image for activity (organizers only)
router.post(
  "/generate-image",
  verifyToken,
  verifyOrganisator,
  aiImageGenerator.generateActivityImage,
);

// Bookmark routes (for both Tourist and Organizer)
router.post(
  "/:activityId/bookmark",
  verifyToken,
  invalidateCache(["activites"]),
  activiteController.toggleActivityBookmark,
);
router.get(
  "/bookmarks",
  verifyToken,
  cacheGet("activites:bookmarks", 60),
  activiteController.getBookmarkedActivities,
);

module.exports = wrapRouter(router);
