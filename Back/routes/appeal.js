const express = require("express");
const router = express.Router();
const appealController = require("../controllers/appeal");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  verifyToken,
  verifyAdmin,
} = require("../middleware/auth");

// ========================================
// USER APPEAL ROUTES
// ========================================

// Submit a new appeal
router.post(
  "/",
  verifyToken,
  invalidateCache(["appeals"]),
  appealController.submitAppeal,
);

// Submit appeal without authentication (for suspended/banned users)
router.post(
  "/anonymous",
  invalidateCache(["appeals"]),
  appealController.submitAnonymousAppeal,
);

// Get current user's appeals
router.get(
  "/me",
  verifyToken,
  cacheGet("appeals:user", 60),
  appealController.getUserAppeals,
);

// ========================================
// ADMIN APPEAL ROUTES
// ========================================

// Get all appeals (admin dashboard)
router.get(
  "/admin",
  verifyToken,
  verifyAdmin,
  cacheGet("appeals:admin", 30),
  appealController.getAllAppeals,
);

// Get appeal statistics (admin)
router.get(
  "/admin/stats",
  verifyToken,
  verifyAdmin,
  cacheGet("appeals:stats", 60),
  appealController.getAppealStats,
);

// Get specific appeal details (admin)
router.get(
  "/admin/:id",
  verifyToken,
  verifyAdmin,
  cacheGet("appeals:details", 60),
  appealController.getAppealDetails,
);

// Update appeal status (admin)
router.patch(
  "/admin/:id",
  verifyToken,
  verifyAdmin,
  invalidateCache(["appeals"]),
  appealController.updateAppealStatus,
);

module.exports = wrapRouter(router);
