const express = require("express");
const router = express.Router();
const touristeController = require("../controllers/touriste");
const { verifyToken } = require("../middleware/auth");

// Routes pour les touristes
// Note: Inscription (signup) et connexion (signin) sont dans routes/user.js

// Compléter le profil touriste après inscription (protégé)
router.put(
  "/complete-profile",
  verifyToken,
  touristeController.completeProfileTouriste,
);

// Obtenir tous les touristes
router.get("/", touristeController.getAllTouristes);

// Obtenir un touriste par ID
router.get("/:id", touristeController.getTouristeById);

// Mettre à jour un touriste (protégé)
router.put("/:id", verifyToken, touristeController.updateTouriste);

// Supprimer un touriste (protégé)
router.delete("/:id", verifyToken, touristeController.deleteTouriste);

// Routes spécifiques pour les attributs du touriste

// Mettre à jour les centres d'intérêt (protégé)
router.patch(
  "/:id/centres-interet",
  verifyToken,
  touristeController.updateCentresInteret,
);

// Mettre à jour la langue préférée (protégé)
router.patch(
  "/:id/langue-preferee",
  verifyToken,
  touristeController.updateLanguePreferee,
);

module.exports = router;
