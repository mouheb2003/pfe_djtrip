const express = require("express");
const router = express.Router();
const organisatorController = require("../controllers/organisator");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");

// Compléter le profil organisateur (protégé, nécessite un token)
router.put(
  "/complete-profile",
  verifyToken,
  organisatorController.completeProfileOrganisator,
);

// Obtenir tous les organisateurs
router.get("/", organisatorController.getAllOrganisators);

// Obtenir un organisateur par ID
router.get("/:id", organisatorController.getOrganisatorById);

// Mettre à jour un organisateur (protégé)
router.put("/:id", verifyToken, organisatorController.updateOrganisator);

// Supprimer un organisateur (protégé, seulement organisateurs)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  organisatorController.deleteOrganisator,
);

module.exports = router;
