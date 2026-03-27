const express = require("express");
const router = express.Router();
const inscriptionController = require("../controllers/inscription");
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
  inscriptionController.createInscription,
);

// Get all registrations for the logged-in tourist
router.get(
  "/mes-inscriptions",
  verifyToken,
  verifyTouriste,
  inscriptionController.getInscriptionsByTouriste,
);

// Cancel a registration (Tourist only)
router.put(
  "/:inscriptionId/annuler",
  verifyToken,
  verifyTouriste,
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
  inscriptionController.getInscriptionsEnAttente,
);

// Get all registrations for the organizer
router.get(
  "/organisateur/mes-demandes",
  verifyToken,
  verifyOrganisator,
  inscriptionController.getInscriptionsByOrganisateur,
);

// Approve a registration (Organizer only)
router.put(
  "/:inscriptionId/approuver",
  verifyToken,
  verifyOrganisator,
  inscriptionController.approuverInscription,
);

// Reject a registration (Organizer only)
router.put(
  "/:inscriptionId/refuser",
  verifyToken,
  verifyOrganisator,
  inscriptionController.refuserInscription,
);

// ========================================
// COMMON ROUTES (Read access)
// ========================================

// Get a registration by ID (Protected - Tourist or Organizer)
router.get(
  "/:inscriptionId",
  verifyToken,
  inscriptionController.getInscriptionById,
);

// GET /stats/organizer - Organizer stats (bookings, revenue, activities)
router.get(
  "/stats/organizer",
  verifyToken,
  verifyOrganisator,
  inscriptionController.getOrganizerStats,
);

// GET /stats/tourist - Tourist stats (bookings count)
router.get(
  "/stats/tourist",
  verifyToken,
  verifyTouriste,
  inscriptionController.getTouristStats,
);

module.exports = router;
