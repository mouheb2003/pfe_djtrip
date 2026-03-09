const express = require("express");
const router = express.Router();
const activiteController = require("../controllers/activite");
const { verifyToken, verifyOrganisator } = require("../middleware/auth");
const upload = require("../middleware/upload");

// Routes publiques - Consultation des activités
// Obtenir toutes les activités (avec filtres optionnels)
router.get("/", activiteController.getAllActivites);

// Rechercher des activités
router.get("/search", activiteController.searchActivites);

// Routes protégées - Mes activités (organisateur)
// Obtenir mes activités actives (en cours et à venir)
router.get(
  "/my-activities",
  verifyToken,
  verifyOrganisator,
  activiteController.getMyActivities,
);

// Obtenir mes activités archivées (passées)
router.get(
  "/archived",
  verifyToken,
  verifyOrganisator,
  activiteController.getArchivedActivities,
);

// Obtenir une activité par ID
router.get("/:id", activiteController.getActiviteById);

// Obtenir les activités d'un organisateur spécifique
router.get(
  "/organisateur/:organisateurId",
  activiteController.getActivitesByOrganisateur,
);

// Routes protégées - Gestion des activités (nécessite authentification)
// Créer une nouvelle activité (réservé aux organisateurs)
router.post(
  "/",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  activiteController.createActivite,
);

// Mettre à jour une activité (réservé au propriétaire)
router.put(
  "/:id",
  verifyToken,
  verifyOrganisator,
  upload.array("photos", 10),
  activiteController.updateActivite,
);

// Supprimer une activité (réservé au propriétaire)
router.delete(
  "/:id",
  verifyToken,
  verifyOrganisator,
  activiteController.deleteActivite,
);

module.exports = router;
