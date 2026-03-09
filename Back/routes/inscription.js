const express = require("express");
const router = express.Router();
const inscriptionController = require("../controllers/inscription");
const {
  verifyToken,
  verifyTouriste,
  verifyOrganisator,
} = require("../middleware/auth");

// ========================================
// ROUTES TOURISTE (Gérer ses inscriptions)
// ========================================

// Créer une inscription à une activité (Touriste uniquement)
router.post(
  "/",
  verifyToken,
  verifyTouriste,
  inscriptionController.createInscription,
);

// Obtenir toutes les inscriptions du touriste connecté
router.get(
  "/mes-inscriptions",
  verifyToken,
  verifyTouriste,
  inscriptionController.getInscriptionsByTouriste,
);

// Annuler une inscription (Touriste uniquement)
router.put(
  "/:inscriptionId/annuler",
  verifyToken,
  verifyTouriste,
  inscriptionController.annulerInscription,
);

// ========================================
// ROUTES ORGANISATEUR (Gérer les demandes)
// ========================================

// Obtenir les inscriptions en attente pour l'organisateur
router.get(
  "/organisateur/en-attente",
  verifyToken,
  verifyOrganisator,
  inscriptionController.getInscriptionsEnAttente,
);

// Obtenir toutes les inscriptions de l'organisateur
router.get(
  "/organisateur/mes-demandes",
  verifyToken,
  verifyOrganisator,
  inscriptionController.getInscriptionsByOrganisateur,
);

// Approuver une inscription (Organisateur uniquement)
router.put(
  "/:inscriptionId/approuver",
  verifyToken,
  verifyOrganisator,
  inscriptionController.approuverInscription,
);

// Refuser une inscription (Organisateur uniquement)
router.put(
  "/:inscriptionId/refuser",
  verifyToken,
  verifyOrganisator,
  inscriptionController.refuserInscription,
);

// ========================================
// ROUTES COMMUNES (Consultation)
// ========================================

// Obtenir une inscription par ID (Protégé - Touriste ou Organisateur)
router.get(
  "/:inscriptionId",
  verifyToken,
  inscriptionController.getInscriptionById,
);

module.exports = router;
