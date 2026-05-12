const express = require("express");
const router = express.Router();
const inscriptionController = require("../controllers/inscription");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  verifyToken,
  verifyTouriste,
  verifyOrganisator,
  verifyAdmin,
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
  // cacheGet("inscriptions:touriste:bookings", 60), // Temporarily disabled cache
  inscriptionController.getMyBookings,
);

// Get public endpoint to get tourist's participated activities count
router.get(
  "/touriste/:touristeId/count",
  inscriptionController.getTouristeParticipatedCount,
);

// Get public endpoint to get activity participants (any user can see)
router.get(
  "/activite/:activiteId/participants",
  verifyToken,
  cacheGet("inscriptions:activite:participants", 60),
  inscriptionController.getActivityParticipants,
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
  "/:inscriptionId/approve",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.approveReservation,
);

// Reject a registration (Organizer only)
router.put(
  "/:inscriptionId/reject",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.rejectReservation,
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

// ========================================
// ADMIN ROUTES
// ========================================

// Get participants for an activity (Admin only)
router.get(
  "/admin/activity-participants",
  verifyToken,
  verifyAdmin,
  cacheGet("inscriptions:admin:activity", 60),
  inscriptionController.getInscriptionsByActivityAdmin,
);

// ========================================
// QR CODE VERIFICATION ROUTES
// ========================================

// Verify/confirm booking via QR code scan (Organizer only)
router.post(
  "/qr/validate",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.validateQrBooking,
);

router.put(
  "/:inscriptionId/verifier",
  verifyToken,
  verifyOrganisator,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.verifyInscription,
);

// ========================================
// REVIEW REMINDER ROUTES
// ========================================

// POST /inscriptions/:id/dismiss-review-reminder
// Dismiss review reminder and schedule next reminder
router.post(
  "/:id/dismiss-review-reminder",
  verifyToken,
  verifyTouriste,
  inscriptionController.dismissReviewReminder,
);

// GET /inscriptions/:id/review-reminder
// Get review reminder data for a booking
router.get(
  "/:id/review-reminder",
  verifyToken,
  verifyTouriste,
  inscriptionController.getReviewReminderData,
);

// GET /inscriptions/review-reminders
// Get all bookings that should show review reminder for authenticated user
router.get(
  "/review-reminders",
  verifyToken,
  verifyTouriste,
  inscriptionController.getPendingReviewReminders,
);

// PATCH /inscriptions/:id/reviewed
// Mark booking as reviewed (Tourist only)
router.patch(
  "/:id/reviewed",
  verifyToken,
  verifyTouriste,
  invalidateCache(["inscriptions", "activites"]),
  inscriptionController.markAsReviewed,
);

module.exports = wrapRouter(router);
