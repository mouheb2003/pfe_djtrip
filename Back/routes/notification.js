const express = require("express");
const router = express.Router();
const notificationController = require("../controllers/notification");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  verifyToken,
  verifyAdmin,
} = require("../middleware/auth");

// ========================================
// USER NOTIFICATION ROUTES
// ========================================

// Get user notifications
router.get(
  "/",
  verifyToken,
  cacheGet("notifications:user", 30),
  notificationController.getUserNotifications,
);

// Get unread count
router.get(
  "/unread-count",
  verifyToken,
  cacheGet("notifications:unread", 60),
  notificationController.getUnreadCount,
);

// Mark notification as read
router.patch(
  "/:id/read",
  verifyToken,
  invalidateCache(["notifications:user", "notifications:unread"]),
  notificationController.markAsRead,
);

// Mark all notifications as read
router.patch(
  "/read-all",
  verifyToken,
  invalidateCache(["notifications:user", "notifications:unread"]),
  notificationController.markAllAsRead,
);

// Delete notification
router.delete(
  "/:id",
  verifyToken,
  invalidateCache(["notifications:user"]),
  notificationController.deleteNotification,
);

// ========================================
// ADMIN NOTIFICATION ROUTES
// ========================================

// Create notification (internal)
router.post(
  "/",
  verifyToken,
  invalidateCache(["notifications:user"]),
  notificationController.createNotification,
);

// Create bulk notifications (internal/system)
router.post(
  "/bulk",
  verifyToken,
  invalidateCache(["notifications:user", "notifications:admin"]),
  notificationController.createBulkNotifications,
);

// Get all notifications (admin)
router.get(
  "/admin",
  verifyToken,
  verifyAdmin,
  cacheGet("notifications:admin", 30),
  notificationController.getAllNotifications,
);

module.exports = wrapRouter(router);
