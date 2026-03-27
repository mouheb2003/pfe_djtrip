const express = require("express");
const router = express.Router();
const touristeController = require("../controllers/touriste");
const { verifyToken } = require("../middleware/auth");

// Tourist routes
// Note: Registration (signup) and sign-in are in routes/user.js

// Complete tourist profile after registration (protected)
router.put(
  "/complete-profile",
  verifyToken,
  touristeController.completeProfileTouriste,
);

// Get all tourists
router.get("/", touristeController.getAllTouristes);

// Get a tourist by ID
router.get("/:id", touristeController.getTouristeById);

// Update a tourist (protected)
router.put("/:id", verifyToken, touristeController.updateTouriste);

// Delete a tourist (protected)
router.delete("/:id", verifyToken, touristeController.deleteTouriste);

// Tourist-specific attribute routes

// Update interests (protected)
router.patch(
  "/:id/centres-interet",
  verifyToken,
  touristeController.updateCentresInteret,
);

// Compat: accept PUT as well as PATCH for clients still using PUT
router.put(
  "/:id/centres-interet",
  verifyToken,
  touristeController.updateCentresInteret,
);

// Update preferred language (protected)
router.patch(
  "/:id/langue-preferee",
  verifyToken,
  touristeController.updateLanguePreferee,
);

module.exports = router;
