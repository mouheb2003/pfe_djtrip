const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const { refreshToken, verifyToken } = require("../middleware/auth");

// POST /signup - Register a new user
router.post("/signup", userController.signUp);

// POST /signin - Login user
router.post("/signin", userController.signIn);

// POST /refresh-token - Refresh access token
router.post("/refresh-token", refreshToken);

// GET /me - Get current user info (protected route)
router.get("/me", verifyToken, userController.myInfo);

// GET / - Get all users
router.get("/", userController.getAllUsers);

// GET /:id - Get user by ID
router.get("/:id", userController.getUserById);

module.exports = router;
