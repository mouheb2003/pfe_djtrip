const express = require("express");
const router = express.Router();
const inscriptionController = require("../controllers/inscription");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  verifyToken,
  verifyTouriste,
  verifyOrganisator,
} = require("../middleware/auth");

// ========================================
// TOURIST ROUTES (Manage registrations)
// ========================================

// Create a registration for an activity (Tourist only)
router.post(
  "/",
  verifyToken,
  verifyTouriste,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.createInscription,
);

// Get all registrations for the logged-in tourist (Legacy, keeping for backwards compatibility)
router.get(
  "/mes-inscriptions",
  verifyToken,
  verifyTouriste,
  cacheGet("inscriptions:touriste", 60),
  inscriptionController.getInscriptionsByTouriste,
);


// Get my bookings for the logged-in tourist (bucketed by status)
router.get(
  "/touriste/my-bookings",
  verifyToken,
  verifyTouriste,
  cacheGet("inscriptions:touriste:bookings", 60),
  inscriptionController.getMyBookings,
);

// Cancel a registration (Tourist only)
router.put(
  "/:inscriptionId/annuler",
  verifyToken,
  verifyTouriste,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.annulerInscription,
);

// ========================================
// ORGANIZER ROUTES (Manage requests)
// ========================================

// Get pending registrations for the organizer
router.get(
  "/organisateur/en-attente",
  verifyToken,
  verifyOrganisator,
  cacheGet("inscriptions:en-attente", 60),
  inscriptionController.getInscriptionsEnAttente,
);

// Get all registrations for the organizer
router.get(
  "/organisateur/mes-demandes",
  verifyToken,
  verifyOrganisator,
  cacheGet("inscriptions:organisateur", 60),
  inscriptionController.getInscriptionsByOrganisateur,
);

// Approve a registration (Organizer only)
router.put(
  "/:inscriptionId/approuver",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.approuverInscription,
);

// Reject a registration (Organizer only)
router.put(
  "/:inscriptionId/refuser",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.refuserInscription,
);

// ========================================
// COMMON ROUTES (Read access)
// ========================================

// Get a registration by ID (Protected - Tourist or Organizer)
router.get(
  "/:inscriptionId",
  verifyToken,
  cacheGet("inscriptions:by-id", 60),
  inscriptionController.getInscriptionById,
);

// GET /stats/organizer - Organizer stats (bookings, revenue, activities)
router.get(
  "/stats/organizer",
  verifyToken,
  verifyOrganisator,
  cacheGet("inscriptions:stats:organizer", 60),
  inscriptionController.getOrganizerStats,
);

// GET /stats/tourist - Tourist stats (bookings count)
router.get(
  "/stats/tourist",
  verifyToken,
  verifyTouriste,
  cacheGet("inscriptions:stats:tourist", 60),
  inscriptionController.getTouristStats,
);

module.exports = wrapRouter(router);
