const express = require("express");
const router = express.Router();
const userController = require("../controllers/user");
const wrapRouter = require("../middleware/wrapRouter");
const { verifyToken } = require("../middleware/auth");

// POST /verify-email - Verify email with code (protected route)
router.post("/verify-email", verifyToken, userController.verifyEmail);

// POST /resend-verification - Resend verification code
router.post("/resend-verification", userController.resendVerificationCode);

// POST /google - Authenticate with Google
router.post("/google", userController.googleAuth);

// POST /facebook - Authenticate with Facebook
router.post("/facebook", userController.facebookAuth);

module.exports = wrapRouter(router);
