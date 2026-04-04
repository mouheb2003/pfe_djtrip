const express = require("express");
const router = express.Router();
const touristeController = require("../controllers/touriste");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken } = require("../middleware/auth");

// Tourist routes
// Note: Registration (signup) and sign-in are in routes/user.js

// Complete tourist profile after registration (protected)
router.put(
  "/complete-profile",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.completeProfileTouriste,
);

// Get all tourists
router.get(
  "/",
  cacheGet("touristes:all", 60),
  touristeController.getAllTouristes,
);

// Get a tourist by ID
router.get(
  "/:id",
  cacheGet("touristes:by-id", 60),
  touristeController.getTouristeById,
);

// Update a tourist (protected)
router.put(
  "/:id",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.updateTouriste,
);

// Delete a tourist (protected)
router.delete(
  "/:id",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.deleteTouriste,
);

// Tourist-specific attribute routes

// Update interests (protected)
router.patch(
  "/:id/centres-interet",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.updateCentresInteret,
);

// Compat: accept PUT as well as PATCH for clients still using PUT
router.put(
  "/:id/centres-interet",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.updateCentresInteret,
);

// Update preferred language (protected)
router.patch(
  "/:id/langue-preferee",
  verifyToken,
  invalidateCache(["touristes", "users"]),
  touristeController.updateLanguePreferee,
);

module.exports = wrapRouter(router);
