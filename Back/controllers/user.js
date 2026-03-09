const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const bcrypt = require("bcryptjs");
const { generateTokens } = require("../middleware/auth");
const emailService = require("../services/email");
const AvatarService = require("../services/avatar");
const UserService = require("../services/user");

// Sign Up - Register a new user (Phase 1: Basic info only)
exports.signUp = async (req, res) => {
  try {
    const userData = req.body;

    // Create user using UserService
    const user = await UserService.createUser(userData);

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
    );

    // Return user without sensitive data
    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;
    delete userResponse.verificationCode;
    delete userResponse.verificationCodeExpiry;

    res.status(201).json({
      message: "User registered successfully. Please verify your email.",
      accessToken,
      refreshToken,
      user: userResponse,
    });
  } catch (err) {
    // Handle specific errors
    if (err.message === "Email already registered") {
      return res.status(400).json({ message: err.message });
    }
    if (err.message.includes("required") || err.message.includes("userType")) {
      return res.status(400).json({ message: err.message });
    }

    res
      .status(500)
      .json({ message: "Error registering user", error: err.message });
  }
};
// Forgot Password - Send reset code
exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    await UserService.forgotPassword(email);

    res.status(200).json({
      message: "Password reset code has been sent to your email",
    });
  } catch (err) {
    if (err.message === "No account found with this email address") {
      return res.status(404).json({ message: err.message });
    }

    res.status(500).json({
      message: "Error sending password reset code",
      error: err.message,
    });
  }
};

// Reset Password - Verify code and update password
exports.resetPassword = async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;

    if (!email || !code || !newPassword) {
      return res.status(400).json({
        message: "Email, code, and new password are required",
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        message: "Password must be at least 6 characters long",
      });
    }

    await UserService.resetPassword(email, code, newPassword);

    res.status(200).json({
      message: "Password has been reset successfully. You can now login.",
    });
  } catch (err) {
    if (
      err.message === "No account found with this email address" ||
      err.message === "No password reset request found" ||
      err.message === "Invalid reset code" ||
      err.message.includes("expired")
    ) {
      return res.status(400).json({ message: err.message });
    }

    res.status(500).json({
      message: "Error resetting password",
      error: err.message,
    });
  }
};
// Sign In - Login user
exports.signIn = async (req, res) => {
  try {
    const { email, mot_de_passe } = req.body;

    // Validate input
    if (!email || !mot_de_passe) {
      return res
        .status(400)
        .json({ message: "Email and password are required" });
    }

    // Find user by email (include password for verification)
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Check and update account status based on activity
    await UserService.updateAccountStatusBasedOnActivity(user._id);

    // Re-fetch user after potential status update
    const updatedUser = await UserService.getUserById(user._id, true);

    // Check account status
    if (updatedUser.accountStatus === "suspended") {
      return res
        .status(403)
        .json({ message: "Account is suspended. Please contact support." });
    }

    if (updatedUser.accountStatus === "banned") {
      return res
        .status(403)
        .json({ message: "Account is banned. Please contact support." });
    }

    if (updatedUser.accountStatus === "inactive") {
      return res
        .status(403)
        .json({ message: "Account is inactive. Please contact support." });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(
      mot_de_passe,
      updatedUser.mot_de_passe,
    );
    if (!isPasswordValid) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Update last connection
    await UserService.updateLastConnection(updatedUser._id);

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      updatedUser._id,
      updatedUser.email,
      updatedUser.userType,
    );

    res.status(200).json({
      message: "Login successful",
      accessToken,
      refreshToken,
    });
  } catch (err) {
    res.status(500).json({ message: "Error logging in", error: err.message });
  }
};

// Get current user info from token
exports.myInfo = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Use UserService to fetch user
    const user = await UserService.getUserById(userId);

    res.status(200).json({
      message: "User info retrieved successfully",
      user: user,
    });
  } catch (err) {
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }
    res.status(500).json({
      message: "Error retrieving user info",
      error: err.message,
    });
  }
};

// Get all users
exports.getAllUsers = async (req, res) => {
  try {
    // Use UserService to fetch all users
    const users = await UserService.getAllUsers();

    res.status(200).json({
      message: "Users retrieved successfully",
      count: users.length,
      users: users,
    });
  } catch (err) {
    res.status(500).json({
      message: "Error retrieving users",
      error: err.message,
    });
  }
};

// Get user by ID
exports.getUserById = async (req, res) => {
  try {
    // Use UserService to fetch user
    const user = await UserService.getUserById(req.params.id);

    res.status(200).json({
      message: "User retrieved successfully",
      user: user,
    });
  } catch (err) {
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }
    res.status(500).json({
      message: "Error retrieving user",
      error: err.message,
    });
  }
};

// Update profile (PUT /users/me)
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const updateData = req.body;

    // Use UserService to update profile
    const user = await UserService.updateProfile(userId, updateData);

    res.status(200).json({
      message: "Profile updated successfully",
      user: user,
    });
  } catch (err) {
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }
    res.status(500).json({
      message: "Error updating profile",
      error: err.message,
    });
  }
};

// Update avatar (PUT /users/me/avatar)
exports.updateAvatar = async (req, res) => {
  try {
    const userId = req.user.userId;

    console.log("📤 Avatar upload request from user:", userId);

    // Validate file presence
    if (!req.file) {
      console.log("❌ No file in request or file rejected by filter");
      return res.status(400).json({
        message:
          "No avatar file provided or invalid file format. Only .jpg, .jpeg, .png, and .webp files are allowed.",
      });
    }

    console.log("📁 File received:", {
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
    });

    // Check if Cloudinary is configured
    if (
      !process.env.CLOUD_NAME ||
      !process.env.API_KEY ||
      !process.env.API_SECRET
    ) {
      console.error("❌ Cloudinary not configured");
      return res.status(500).json({
        message: "Server configuration error: Cloudinary not configured",
      });
    }

    console.log("☁️ Processing avatar upload...");

    // Use AvatarService to handle upload and database update
    const result = await AvatarService.replaceAvatar(userId, req.file.buffer);

    res.status(200).json({
      message: "Avatar updated successfully",
      avatar: result.avatarUrl,
      user: result.user,
    });
  } catch (err) {
    console.error("❌ Error in updateAvatar:", err);

    // Handle specific errors
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(500).json({
      message: "Error updating avatar",
      error: err.message,
    });
  }
};

// Update account status based on activity
exports.updateAccountStatusBasedOnActivity = async (userId) => {
  try {
    // Use UserService to check and update account status
    await UserService.updateAccountStatusBasedOnActivity(userId);
  } catch (err) {
    console.error("Error updating account status:", err.message);
  }
};

// Update account status manually (PUT /users/:id/status)
exports.updateAccountStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { accountStatus } = req.body;

    // Validate accountStatus
    if (
      !["active", "suspended", "banned", "inactive"].includes(accountStatus)
    ) {
      return res.status(400).json({
        message:
          'Account status must be either "active", "suspended", "banned", or "inactive"',
      });
    }

    // Update user account status
    const user = await User.findByIdAndUpdate(
      id,
      { accountStatus: accountStatus },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "Account status updated successfully",
      user: user,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error updating account status", error: err.message });
  }
};

// Logout - Set user offline (POST /users/logout)
exports.logout = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Set user to offline status
    await UserService.updateOnlineStatus(userId, false);

    res.status(200).json({
      message: "Logout successful",
    });
  } catch (err) {
    res.status(500).json({ message: "Error logging out", error: err.message });
  }
};

// Verify Email - Verify email with code (POST /auth/verify-email)
exports.verifyEmail = async (req, res) => {
  try {
    const { code } = req.body;
    const userId = req.user.userId;

    if (!code) {
      return res.status(400).json({ message: "Verification code is required" });
    }

    // Get user email first
    const user = await UserService.getUserById(userId);

    // Verify email using UserService
    const verifiedUser = await UserService.verifyEmail(user.email, code);

    // Send welcome email
    await emailService.sendWelcomeEmail(
      verifiedUser.email,
      verifiedUser.fullname,
    );

    res.status(200).json({
      message: "Email verified successfully",
      emailVerified: true,
    });
  } catch (err) {
    // Handle specific errors
    if (err.message === "User not found") {
      return res.status(404).json({ message: err.message });
    }
    if (
      err.message === "Email already verified" ||
      err.message === "Invalid verification code" ||
      err.message === "Verification code expired"
    ) {
      return res.status(400).json({ message: err.message });
    }

    res
      .status(500)
      .json({ message: "Error verifying email", error: err.message });
  }
};

// Resend Verification Code (POST /auth/resend-verification)
exports.resendVerificationCode = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    // Resend verification code using UserService
    const result = await UserService.resendVerificationCode(email);

    if (!result.success) {
      return res.status(500).json({
        message: "Error sending verification email",
      });
    }

    res.status(200).json({
      message: "Verification code sent successfully",
      success: true,
    });
  } catch (err) {
    // Handle specific errors
    if (err.message === "User not found") {
      return res.status(404).json({ message: err.message });
    }
    if (err.message === "Email already verified") {
      return res.status(400).json({ message: err.message });
    }

    res.status(500).json({
      message: "Error resending verification code",
      error: err.message,
    });
  }
};
