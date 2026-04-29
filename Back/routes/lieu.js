console.log('[LIEU ROUTES] Loading lieu routes...');

const express = require("express");
const router = express.Router();
const lieuController = require("../controllers/lieu");
console.log('[LIEU ROUTES] Lieu controller loaded');
const wrapRouter = require("../middleware/wrapRouter");
const { verifyToken, verifyAdmin } = require("../middleware/auth");
const Config = require("../models/lieu").Config;

// ==================== PUBLIC ENDPOINTS ====================

// Get Google Maps API key (must be before /:id to avoid conflicts)
router.get("/config/google-maps-key", async (req, res) => {
  try {
    const config = await Config.findOne({ key: "google_maps_api_key" });
    if (config) {
      return res.json({ apiKey: config.value });
    }
    // Fallback to environment variable
    return res.json({ apiKey: process.env.GOOGLE_MAPS_API_KEY || "" });
  } catch (error) {
    return res.status(500).json({ message: "Error fetching Google Maps API key" });
  }
});

// Get all lieux
router.get("/", lieuController.getAllLieux);

// Get a single lieu by ID or slug
router.get("/:id", lieuController.getLieuById);

// ==================== AUTHENTICATED ENDPOINTS ====================

// Create a new lieu (ADMIN only)
router.post("/", verifyToken, verifyAdmin, lieuController.createLieu);

// Update a lieu (ADMIN only)
router.put("/:id", verifyToken, verifyAdmin, lieuController.updateLieu);

// Delete a lieu (ADMIN only)
router.delete("/:id", verifyToken, verifyAdmin, lieuController.deleteLieu);

// Upload images for a lieu (ADMIN only)
router.post("/:id/upload-images", verifyToken, verifyAdmin, lieuController.uploadImages);

// Update Google Maps API key (ADMIN only)
router.put("/config/google-maps-key", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { apiKey } = req.body;
    if (!apiKey) {
      return res.status(400).json({ message: "API key is required" });
    }

    await Config.findOneAndUpdate(
      { key: "google_maps_api_key" },
      { value: apiKey, description: "Google Maps JavaScript API Key" },
      { upsert: true, new: true }
    );

    return res.json({ message: "Google Maps API key updated successfully" });
  } catch (error) {
    return res.status(500).json({ message: "Error updating Google Maps API key" });
  }
});

console.log('[LIEU ROUTES] All routes defined, wrapping router...');
module.exports = wrapRouter(router);
console.log('[LIEU ROUTES] Lieu routes loaded successfully');
