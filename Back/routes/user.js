const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const validate = require("../middleware/validate");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  signUpSchema,
  signInSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} = require("../validators/user");
const {
  refreshToken,
  verifyToken,
  verifyAdmin,
} = require("../middleware/auth");
const upload = require("../middleware/upload");

// POST /signup - Register a new user
router.post(
  "/signup",
  validate(signUpSchema),
  invalidateCache(["users", "touristes", "organisators"]),
  userController.signUp,
);

// POST /signin - Login user
router.post("/signin", validate(signInSchema), userController.signIn);

// POST /forgot-password - Send password reset code
router.post(
  "/forgot-password",
  validate(forgotPasswordSchema),
  userController.forgotPassword,
);

// POST /reset-password - Reset password with code
router.post(
  "/reset-password",
  validate(resetPasswordSchema),
  userController.resetPassword,
);

// POST /logout - Logout user (protected route)
router.post(
  "/logout",
  verifyToken,
  invalidateCache(["users", "posts", "messages"]),
  userController.logout,
);

// POST /disconnect-all - Disconnect all users (temporarily for testing)
router.post('/disconnect-all', verifyToken, async (req, res) => {
  try {
    // Temporarily remove admin check for testing
    console.log(`🔌 [DISCONNECT_ALL] User ${req.user.userId} requested to disconnect all users`);

    console.log('🔌 [DISCONNECT_ALL] Admin requested to disconnect all users');
    
    // Update all users to offline status
    const User = require('../models/user');
    const result = await User.updateMany(
      {}, // All users
      { 
        $set: { 
          lastActiveAt: new Date(Date.now() - 60000), // Set to 60 seconds ago to ensure offline status
          isOnline: false 
        }
      }
    );

    console.log(`🔌 [DISCONNECT_ALL] Updated ${result.modifiedCount} users to offline status`);
    
    res.json({
      success: true,
      message: `Successfully disconnected ${result.modifiedCount} users`,
      modifiedCount: result.modifiedCount
    });
  } catch (err) {
    console.error('❌ [DISCONNECT_ALL] Error disconnecting users:', err);
    res.status(500).json({
      message: "Error disconnecting users",
      error: err.message
    });
  }
});

// POST /disconnect-all-test - Test endpoint without authentication
router.post('/disconnect-all-test', async (req, res) => {
  try {
    console.log('🔌 [DISCONNECT_ALL_TEST] Test endpoint - disconnecting all users');
    
    // Update all users to offline status
    const User = require('../models/user');
    const result = await User.updateMany(
      {}, // All users
      { 
        $set: { 
          lastActiveAt: new Date(Date.now() - 60000), // Set to 60 seconds ago to ensure offline status
          isOnline: false 
        }
      }
    );

    console.log(`🔌 [DISCONNECT_ALL_TEST] Updated ${result.modifiedCount} users to offline status`);
    
    res.json({
      success: true,
      message: `Successfully disconnected ${result.modifiedCount} users (TEST)`,
      modifiedCount: result.modifiedCount
    });
  } catch (err) {
    console.error('❌ [DISCONNECT_ALL_TEST] Error disconnecting users:', err);
    res.status(500).json({
      message: "Error disconnecting users",
      error: err.message
    });
  }
});

// POST /heartbeat - Update user's last active timestamp (protected route)
router.post(
  "/heartbeat",
  verifyToken,
  userController.heartbeat,
);

// POST /heartbeat/:userId - Update specific user's last active timestamp (for admin/testing)
router.post(
  "/heartbeat/:userId",
  verifyToken,
  userController.heartbeatForUser,
);

// POST /refresh-token - Refresh access token
router.post("/refresh-token", refreshToken);

// GET /me - Get current user info (protected route)
router.get("/me", verifyToken, cacheGet("users:me", 60), userController.myInfo);

// GET /me/favorites - Get current user's favorite activities
router.get(
  "/me/favorites",
  verifyToken,
  cacheGet("users:favorites", 60),
  userController.getFavorites,
);

// POST /me/favorites/:activityId - Add activity to favorites
router.post(
  "/me/favorites/:activityId",
  verifyToken,
  invalidateCache(["users:favorites", "activites"]),
  userController.addFavorite,
);

// DELETE /me/favorites/:activityId - Remove activity from favorites
router.delete(
  "/me/favorites/:activityId",
  verifyToken,
  invalidateCache(["users:favorites", "activites"]),
  userController.removeFavorite,
);

// PUT /me/password - Change current user password (protected route)
router.put(
  "/me/password",
  verifyToken,
  invalidateCache(["users:me", "users"]),
  userController.changePassword,
);

// PUT /me - Update current user profile (protected route)
router.put(
  "/me",
  verifyToken,
  invalidateCache(["users", "users:me", "posts"]),
  userController.updateProfile,
);

// POST /me/fcm-token - Add or update FCM token for push notifications (protected route)
router.post(
  "/me/fcm-token",
  verifyToken,
  userController.addFcmToken,
);

// DELETE /me/fcm-token/:deviceId - Remove FCM token for push notifications (protected route)
router.delete(
  "/me/fcm-token/:deviceId",
  verifyToken,
  userController.removeFcmToken,
);

// PUT /me/reminder-preferences - Update reminder preferences (protected route)
router.put(
  "/me/reminder-preferences",
  verifyToken,
  invalidateCache(["users", "users:me"]),
  userController.updateReminderPreferences,
);

// PUT /me/avatar - Update current user avatar (protected route)
router.put(
  "/me/avatar",
  verifyToken,
  upload.single("avatar"),
  invalidateCache(["users", "users:me", "posts"]),
  userController.updateAvatar,
);

// DELETE /me/avatar - Delete current user avatar (protected route)
router.delete(
  "/me/avatar",
  verifyToken,
  invalidateCache(["users", "users:me", "posts"]),
  userController.deleteAvatar,
);

// PUT /me/cover-photo - Update current user cover photo (protected route)
router.put(
  "/me/cover-photo",
  verifyToken,
  upload.single("coverPhoto"),
  invalidateCache(["users", "users:me", "posts"]),
  userController.updateCoverPhoto,
);

// DELETE /me/cover-photo - Delete current user cover photo (protected route)
router.delete(
  "/me/cover-photo",
  verifyToken,
  invalidateCache(["users", "users:me", "posts"]),
  userController.deleteCoverPhoto,
);

// DELETE /me - Delete current user account (protected route)
router.delete(
  "/me",
  verifyToken,
  invalidateCache(["users", "touristes", "organisators", "posts"]),
  userController.deleteAccount,
);

// DELETE /:id - Delete user account (Admin only)
router.delete(
  "/:id",
  verifyToken,
  verifyAdmin,
  invalidateCache(["users", "touristes", "organisators", "posts"]),
  userController.deleteUser,
);

// PUT /:id/status - Update account status (Admin only)
router.put(
  "/:id/status",
  verifyToken,
  verifyAdmin,
  invalidateCache(["users", "touristes", "organisators"]),
  userController.updateAccountStatus,
);

// PUT /:id/ban - Ban user account (Admin only)
router.put(
  "/:id/ban",
  verifyToken,
  verifyAdmin,
  invalidateCache(["users", "touristes", "organisators"]),
  userController.banUser,
);

// PUT /:id/unban - Unban user account (Admin only)
router.put(
  "/:id/unban",
  verifyToken,
  verifyAdmin,
  invalidateCache(["users", "touristes", "organisators"]),
  userController.unbanUser,
);

// GET / - Get all users (Admin only)
router.get(
  "/",
  verifyToken,
  verifyAdmin,
  cacheGet("users:admin", 60),
  userController.getAllUsers,
);

// GET /all - Get all users (PUBLIC for testing)
router.get("/all", cacheGet("users:all", 60), userController.getAllUsersPublic);

// GET /admin - Get admin user (optimized for chat support)
router.get("/admin", cacheGet("users:admin:single", 30), userController.getAdminUser);
router.put("/privacy", verifyToken, userController.updatePrivacySettings);
router.patch(
  "/privacy-settings",
  verifyToken,
  invalidateCache(["users", "users:me", "posts"]),
  userController.updatePrivacySettings,
);
router.put(
  "/advanced-privacy",
  verifyToken,
  userController.updateAdvancedSettings,
);

// REMOVED: Get user by username
// router.get("/username/:username", cacheGet("users:by-username", 60), userController.getUserByUsername);

// GET /:id - Get user by ID
router.get("/:id", cacheGet("users:by-id", 60), userController.getUserById);

// GET /:id/overview - Get comprehensive user overview with all related data
router.get("/:id/overview", verifyToken, verifyAdmin, userController.getUserOverview);

module.exports = wrapRouter(router);
