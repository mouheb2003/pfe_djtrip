const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const { refreshToken, verifyToken } = require("../middleware/auth");
const upload = require("../middleware/upload");

// POST /signup - Register a new user
router.post("/signup", userController.signUp);

// POST /signin - Login user
router.post("/signin", userController.signIn);

// POST /forgot-password - Send password reset code
router.post("/forgot-password", userController.forgotPassword);

// POST /reset-password - Reset password with code
router.post("/reset-password", userController.resetPassword);

// POST /logout - Logout user (protected route)
router.post("/logout", verifyToken, userController.logout);

// POST /refresh-token - Refresh access token
router.post("/refresh-token", refreshToken);

// GET /me - Get current user info (protected route)
router.get("/me", verifyToken, userController.myInfo);

// GET /me/favorites - Get current user's favorite activities
router.get("/me/favorites", verifyToken, userController.getFavorites);

// POST /me/favorites/:activityId - Add activity to favorites
router.post("/me/favorites/:activityId", verifyToken, userController.addFavorite);

// DELETE /me/favorites/:activityId - Remove activity from favorites
router.delete("/me/favorites/:activityId", verifyToken, userController.removeFavorite);

// PUT /me - Update current user profile (protected route)
router.put("/me", verifyToken, userController.updateProfile);

// PUT /me/avatar - Update current user avatar (protected route)
router.put(
  "/me/avatar",
  verifyToken,
  upload.single("avatar"),
  userController.updateAvatar,
);

// DELETE /me/avatar - Delete current user avatar (protected route)
router.delete("/me/avatar", verifyToken, userController.deleteAvatar);

// PUT /:id/status - Update account status (protected route)
router.put("/:id/status", verifyToken, userController.updateAccountStatus);

// GET / - Get all users
router.get("/", userController.getAllUsers);

// GET /:id - Get user by ID
router.get("/:id", userController.getUserById);

module.exports = router;
