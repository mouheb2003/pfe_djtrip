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

// POST /auth/google - Authenticate with Google
router.post("/auth/google", userController.googleAuth);

// POST /auth/facebook - Authenticate with Facebook
router.post("/auth/facebook", userController.facebookAuth);

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
router.put("/privacy", verifyToken, userController.updatePrivacySettings);
router.put(
  "/advanced-privacy",
  verifyToken,
  userController.updateAdvancedSettings,
);

// GET /:id - Get user by ID
router.get("/:id", cacheGet("users:by-id", 60), userController.getUserById);

module.exports = wrapRouter(router);
