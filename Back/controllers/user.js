const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const Activite = require("../models/activite");
const bcrypt = require("bcryptjs");
const { OAuth2Client } = require("google-auth-library");
const { generateTokens } = require("../middleware/auth");
const emailService = require("../services/email");
const AvatarService = require("../services/avatar");
const UserService = require("../services/user");
const { createActivityLog } = require("../services/activityLogService");

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

async function restoreExpiredSuspensions({ userId } = {}) {
  const now = new Date();
  const query = {
    accountStatus: "suspended",
    suspendedUntil: { $ne: null, $lte: now },
  };

  if (userId) {
    query._id = userId;
  }

  const users = await User.find(query).select(
    "email fullname accountStatus suspendedUntil suspendReason suspendedAt",
  );

  if (!users.length) {
    return 0;
  }

  for (const user of users) {
    const previousReason = user.suspendReason;
    user.accountStatus = "active";
    user.suspendedUntil = null;
    user.suspendReason = null;
    user.suspendedAt = null;
    await user.save();

    try {
      await emailService.sendAccountRestoredEmail(
        user.email,
        user.fullname || "DJTrip User",
        "suspended",
        previousReason,
      );
    } catch (emailErr) {
      console.error("Error sending auto-restored account email:", emailErr);
    }
  }

  return users.length;
}

async function fetchFacebookProfile(accessToken) {
  if (typeof fetch !== "function") {
    throw new Error("Global fetch is not available on this Node.js runtime");
  }

  const fields = "id,name,email,picture.type(large)";
  const response = await fetch(
    `https://graph.facebook.com/me?fields=${fields}&access_token=${encodeURIComponent(accessToken)}`,
  );
  const data = await response.json();

  if (!response.ok || data.error) {
    const message = data?.error?.message || "Invalid Facebook token";
    throw new Error(message);
  }

  return data;
}

// Sign Up - Register a new user (Phase 1: Basic info only)
exports.signUp = async (req, res) => {
  try {
    const userData = req.body;

    // Set signup method to email for email/password signup
    userData.signup_method = 'email';
    
    // For email signup, set is_onboarded to false initially
    userData.is_onboarded = false;
    
    // For organizers, set is_approved to false initially
    if (userData.userType === 'Organisator') {
      userData.is_approved = false;
    }

    // Create user using UserService
    const user = await UserService.createUser(userData);

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
      user.tokenVersion || 0,
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
      requires_onboarding: true,
      skip_user_type_selection: true // Email signup skips user type selection
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
    let user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    await restoreExpiredSuspensions({ userId: user._id });
    user = await User.findById(user._id);
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Check for lockout
    if (user.lockUntil && user.lockUntil > Date.now()) {
      const remainingSeconds = Math.ceil((user.lockUntil - Date.now()) / 1000);
      return res.status(423).json({
        message: "Account temporarily locked.",
        remainingSeconds,
      });
    }

    // Check account status
    if (user.accountStatus === "suspended") {
      const remainingSeconds = user.suspendedUntil
        ? Math.max(
            0,
            Math.ceil(
              (new Date(user.suspendedUntil).getTime() - Date.now()) / 1000,
            ),
          )
        : null;

      const suspendedUntilISO = user.suspendedUntil
        ? new Date(user.suspendedUntil).toISOString()
        : null;

      console.log('[SIGNIN SUSPENSION] user.suspendedUntil:', user.suspendedUntil, 'type:', typeof user.suspendedUntil);
      console.log('[SIGNIN SUSPENSION] suspendedUntilISO:', suspendedUntilISO);
      console.log('[SIGNIN SUSPENSION] remainingSeconds:', remainingSeconds);
      console.log('[SIGNIN SUSPENSION] suspendReason:', user.suspendReason);

      return res.status(403).json({
        type: "suspended",
        forceLogout: true,
        message: user.suspendReason
          ? `Account is suspended: ${user.suspendReason}`
          : "Account is suspended. Please contact support.",
        reason: user.suspendReason || null,
        suspendedUntil: suspendedUntilISO,
        remainingSeconds,
      });
    }

    if (user.accountStatus === "banned") {
      return res.status(403).json({
        message: user.banReason
          ? `Account is banned: ${user.banReason}`
          : "Account is banned. Please contact support.",
        reason: user.banReason || null,
      });
    }

    if (user.accountStatus === "inactive") {
      return res
        .status(403)
        .json({ message: "Account is inactive. Please contact support." });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(
      mot_de_passe,
      user.mot_de_passe,
    );
    if (!isPasswordValid) {
      // Increment login attempts
      user.loginAttempts = (user.loginAttempts || 0) + 1;

      if (user.loginAttempts >= 5) {
        user.lockUntil = new Date(Date.now() + 60 * 1000); // 1 minute lockout
        user.loginAttempts = 0; // Reset for after lockout
        await user.save();
        return res.status(423).json({
          message: "Too many attempts. Account locked for 1 minute.",
          lockUntil: user.lockUntil,
          remainingSeconds: 60,
        });
      }

      await user.save();
      return res.status(401).json({
        message: "Invalid email or password",
        attempts: user.loginAttempts,
      });
    }

    // Reset attempts on successful login
    user.loginAttempts = 0;
    user.lockUntil = undefined;

    // 🚀 NEW: Check if email is verified
    if (!user.emailVerified) {
      // Generate tokens so they can access the verification route if protected
      const { accessToken, refreshToken } = generateTokens(
        user._id,
        user.email,
        user.userType,
        user.tokenVersion || 0,
      );

      const userResponse = user.toObject();
      delete userResponse.mot_de_passe;
      delete userResponse.verificationCode;
      delete userResponse.verificationCodeExpiry;

      return res.status(200).json({
        message: "Email verification required",
        emailVerified: false,
        accessToken,
        refreshToken,
        user: userResponse,
      });
    }

    // 🚀 NEW: Force cleanup before login - mark all users as offline except this one
    console.log(
      `🧹 [LOGIN] Forcing cleanup before login for user ${user._id}...`,
    );
    await User.updateMany(
      { _id: { $ne: user._id }, isOnline: true },
      { isOnline: false },
    );
    console.log(`✅ [LOGIN] Marked all other users as offline`);

    // Update last connection and set online
    user.derniere_connexion = new Date();
    await user.save();

    // 🚀 NEW: Explicitly set online status
    await UserService.updateOnlineStatus(user._id, true);
    console.log(`✅ [LOGIN] User ${user._id} marked as online`);

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
      user.tokenVersion || 0,
    );

    // Return user without sensitive data
    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;
    delete userResponse.verificationCode;
    delete userResponse.verificationCodeExpiry;

    res.status(200).json({
      message: "Login successful",
      accessToken,
      refreshToken,
      user: userResponse,
    });
  } catch (err) {
    res.status(500).json({ message: "Error signing in", error: err.message });
  }
};

// Google Sign-In - Authenticate with Google ID token
exports.googleAuth = async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({ message: "Google ID token is required" });
    }
    if (!process.env.GOOGLE_CLIENT_ID) {
      return res.status(500).json({
        message: "Google auth is not configured on server",
      });
    }

    let ticket;
    try {
      ticket = await googleClient.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
    } catch (error) {
      return res.status(401).json({
        message: "Invalid Google token",
        error: error.message,
      });
    }

    const payload = ticket.getPayload();
    const googleId = payload?.sub;
    const email = payload?.email?.toLowerCase();
    const fullname = payload?.name || "Google User";
    const avatar = payload?.picture;
    const isEmailVerified = Boolean(payload?.email_verified);

    if (!googleId || !email) {
      return res.status(400).json({
        message: "Unable to retrieve required Google profile data",
      });
    }

    let user = await User.findOne({
      $or: [{ googleId }, { email }],
    });
    const isExistingUser = Boolean(user);

    if (isExistingUser) {
      if (!user.googleId) user.googleId = googleId;
      if (isEmailVerified && !user.emailVerified) user.emailVerified = true;
      if (!user.avatar && avatar) user.avatar = avatar;
      user.derniere_connexion = new Date();
      user.accountStatus = "active";
      await user.save();
    } else {
      user = new User({
        fullname,
        email,
        googleId,
        avatar,
        emailVerified: isEmailVerified,
        userType: "Touriste", // Default for Google signup, will be updated during onboarding
        signup_method: "google",
        is_onboarded: false, // Google signup requires onboarding
        accountStatus: "active",
        derniere_connexion: new Date(),
      });
      await user.save();
    }

    await UserService.updateOnlineStatus(user._id, true);

    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
      user.tokenVersion || 0,
    );

    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;
    delete userResponse.googleId;
    delete userResponse.facebookId;

    return res.status(200).json({
      message: isExistingUser
        ? "Google sign-in successful"
        : "Google sign-up successful",
      accessToken,
      refreshToken,
      user: userResponse,
      requires_onboarding: !user.is_onboarded,
      skip_user_type_selection: false, // Google signup shows user type selection
      is_new_user: !isExistingUser
    });
  } catch (err) {
    return res.status(500).json({
      message: "Error during Google authentication",
      error: err.message,
    });
  }
};

// Facebook Login - Authenticate with Facebook access token
exports.facebookAuth = async (req, res) => {
  try {
    const { accessToken } = req.body;

    if (!accessToken) {
      return res.status(400).json({
        message: "Facebook access token is required",
      });
    }

    let profile;
    try {
      profile = await fetchFacebookProfile(accessToken);
    } catch (error) {
      return res.status(401).json({
        message: "Invalid Facebook token",
        error: error.message,
      });
    }

    const facebookId = profile?.id;
    const email = profile?.email?.toLowerCase();
    const fullname = profile?.name || "Facebook User";
    const avatar = profile?.picture?.data?.url;
    const normalizedEmail = email || `fb_${facebookId}@facebook.local`;

    if (!facebookId) {
      return res.status(400).json({
        message: "Unable to retrieve Facebook profile information",
      });
    }

    let user = await User.findOne({
      $or: [{ facebookId }, { email: normalizedEmail }],
    });
    const isExistingUser = Boolean(user);

    if (isExistingUser) {
      if (!user.facebookId) user.facebookId = facebookId;
      if (!user.emailVerified) user.emailVerified = true;
      if (!user.avatar && avatar) user.avatar = avatar;
      user.derniere_connexion = new Date();
      user.accountStatus = "active";
      await user.save();
    } else {
      user = new User({
        fullname,
        email: normalizedEmail,
        facebookId,
        avatar,
        emailVerified: Boolean(email),
        userType: "Touriste",
        accountStatus: "active",
        derniere_connexion: new Date(),
      });
      await user.save();
    }

    await UserService.updateOnlineStatus(user._id, true);

    const { accessToken: appAccessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
      user.tokenVersion || 0,
    );

    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;
    delete userResponse.googleId;
    delete userResponse.facebookId;

    return res.status(200).json({
      message: isExistingUser
        ? "Facebook sign-in successful"
        : "Facebook sign-up successful",
      accessToken: appAccessToken,
      refreshToken,
      user: userResponse,
    });
  } catch (err) {
    return res.status(500).json({
      message: "Error during Facebook authentication",
      error: err.message,
    });
  }
};

// Get current user info from token
exports.myInfo = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Use UserService to fetch user
    const user = await UserService.getUserById(userId);

    // 🚀 NEW: Ajouter les spécialités d'activités prédéfinies si organisateur
    if (
      user &&
      user.userType === "Organisator" &&
      (!user.specialites_activites || user.specialites_activites.length === 0)
    ) {
      // Spécialités par défaut pour les organisateurs
      const defaultSpecialties = [
        "Sports & Aventure",
        "Musique & Concerts",
        "Art & Culture",
        "Gastronomie & Cuisine",
        "Plage & Mer",
        "Montagne & Randonnée",
        "Histoire & Patrimoine",
        "Jeux & Divertissement",
        "Bien-être & Spa",
        "Photographie & Tour",
        "Transport & Excursion",
        "Camping & Nature",
        "Festivals & Événements",
      ];

      user.specialites_activites = defaultSpecialties;
      await user.save();
    }

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
    await restoreExpiredSuspensions();

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find().select("-mot_de_passe").skip(skip).limit(limit).lean(),
      User.countDocuments(),
    ]);

    res.status(200).json({
      message: "Users retrieved successfully",
      count: users.length,
      total,
      page,
      pages: Math.ceil(total / limit),
      users,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error retrieving users", error: err.message });
  }
};

// 🚀 NEW: Get all users PUBLIC for testing online status
exports.getAllUsersPublic = async (req, res) => {
  try {
    console.log("🔍 [PUBLIC] Fetching all users with online status...");

    await restoreExpiredSuspensions();

    const users = await User.find()
      .select(
        "-mot_de_passe -verificationCode -verificationCodeExpiry -passwordResetCode -passwordResetCodeExpiry",
      )
      .lean();

    console.log(`📊 [PUBLIC] Found ${users.length} users`);

    // Add online status info for debugging
    const usersWithStatus = users.map((user) => ({
      ...user,
      _debugInfo: {
        isOnline: user.isOnline || false,
        lastConnection: user.derniere_connexion || null,
        accountStatus: user.accountStatus || "unknown",
      },
    }));

    res.status(200).json({
      message: "Users retrieved successfully (PUBLIC)",
      count: usersWithStatus.length,
      timestamp: new Date().toISOString(),
      users: usersWithStatus,
    });
  } catch (err) {
    console.error("❌ [PUBLIC] Error retrieving users:", err);
    res
      .status(500)
      .json({ message: "Error retrieving users", error: err.message });
  }
};

// Get user by ID
exports.getUserById = async (req, res) => {
  try {
    await restoreExpiredSuspensions({ userId: req.params.id });

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

// Change password (PUT /users/me/password)
exports.changePassword = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res
        .status(400)
        .json({ message: "Current password and new password are required" });
    }
    if (newPassword.length < 8) {
      return res
        .status(400)
        .json({ message: "New password must be at least 8 characters" });
    }

    await UserService.updatePassword(userId, currentPassword, newPassword);

    res.status(200).json({ message: "Password changed successfully" });
  } catch (err) {
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }
    if (err.message === "Current password is incorrect") {
      return res.status(400).json({ message: err.message });
    }
    res
      .status(500)
      .json({ message: "Error changing password", error: err.message });
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
    if (
      err.name === "ValidationError" ||
      err.name === "CastError" ||
      err.code === 11000 ||
      err.message.includes("Invalid") ||
      err.message.includes("Phone")
    ) {
      return res.status(400).json({
        message: err.message || "Invalid profile data",
        error: err.message,
      });
    }
    res.status(500).json({
      message: "Error updating profile",
      error: err.message,
    });
  }
};

// Get current user's favorites (GET /users/me/favorites)
exports.getFavorites = async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await User.findById(userId).populate("favorites").lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    const favorites = user.favorites || [];
    res.json(favorites);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Add activity to favorites (POST /users/me/favorites/:activityId)
exports.addFavorite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { activityId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!user.favorites) user.favorites = [];
    if (user.favorites.some((id) => id.toString() === activityId)) {
      return res.json({
        message: "Already in favorites",
        favorites: user.favorites,
      });
    }
    const activite = await Activite.findById(activityId);
    if (!activite)
      return res.status(404).json({ message: "Activity not found" });
    user.favorites.push(activityId);
    await user.save();
    res.json({ message: "Added to favorites", favorites: user.favorites });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Remove activity from favorites (DELETE /users/me/favorites/:activityId)
exports.removeFavorite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { activityId } = req.params;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!user.favorites) user.favorites = [];
    user.favorites = user.favorites.filter(
      (id) => id.toString() !== activityId,
    );
    await user.save();
    res.json({ message: "Removed from favorites", favorites: user.favorites });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Delete avatar (DELETE /users/me/avatar)
exports.deleteAvatar = async (req, res) => {
  try {
    const userId = req.user.userId;
    console.log("🗑️ Delete avatar request from user:", userId);

    const updatedUser = await AvatarService.deleteAvatar(userId);

    res.status(200).json({
      message: "Avatar deleted successfully",
      user: updatedUser,
    });
  } catch (err) {
    console.error("❌ Error in deleteAvatar:", err);
    if (err.message === "User not found") {
      return res.status(404).json({ message: "User not found" });
    }
    res
      .status(500)
      .json({ message: "Error deleting avatar", error: err.message });
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
    const adminId = req.user.userId;
    const { id } = req.params;
    const {
      accountStatus,
      suspendedUntil,
      suspendDays,
      suspendReason,
      banReason,
    } = req.body;

    // Validate accountStatus
    if (
      !["active", "suspended", "banned", "inactive"].includes(accountStatus)
    ) {
      return res.status(400).json({
        message:
          'Account status must be either "active", "suspended", "banned", or "inactive"',
      });
    }

    const existingUser = await User.findById(id).select(
      "fullname accountStatus suspendReason banReason",
    );
    if (!existingUser) {
      return res.status(404).json({ message: "User not found" });
    }

    const previousStatus = existingUser.accountStatus;
    const previousReason =
      previousStatus === "banned"
        ? existingUser.banReason
        : existingUser.suspendReason;

    const updatePayload = { accountStatus };

    if (accountStatus === "suspended") {
      if (
        !suspendReason ||
        typeof suspendReason !== "string" ||
        !suspendReason.trim()
      ) {
        return res.status(400).json({
          message: "suspendReason must be a non-empty string",
        });
      }

      if (typeof suspendDays !== "undefined") {
        const days = Number.parseInt(suspendDays, 10);

        if (!Number.isInteger(days) || days <= 0) {
          return res.status(400).json({
            message: "suspendDays must be a positive integer",
          });
        }

        updatePayload.suspendedUntil = new Date(
          Date.now() + days * 24 * 60 * 60 * 1000,
        );
      } else if (suspendedUntil) {
        const parsedDate = new Date(suspendedUntil);

        if (Number.isNaN(parsedDate.getTime()) || parsedDate <= new Date()) {
          return res.status(400).json({
            message: "suspendedUntil must be a valid future date",
          });
        }

        updatePayload.suspendedUntil = parsedDate;
      } else {
        // No end date means suspension stays active until manual reactivation.
        updatePayload.suspendedUntil = null;
      }

      updatePayload.suspendReason = suspendReason.trim();
      updatePayload.suspendedAt = new Date();
    } else {
      updatePayload.suspendedUntil = null;
      updatePayload.suspendReason = null;
      updatePayload.suspendedAt = null;
    }

    if (accountStatus === "banned") {
      if (!banReason || typeof banReason !== "string" || !banReason.trim()) {
        return res.status(400).json({
          message: "banReason must be a non-empty string",
        });
      }

      updatePayload.banReason = banReason.trim();
      updatePayload.bannedAt = new Date();
    } else {
      updatePayload.banReason = null;
      updatePayload.bannedAt = null;
    }

    const shouldRevokeSession =
      accountStatus === "suspended" || accountStatus === "banned";

    // Update user account status
    const user = await User.findByIdAndUpdate(
      id,
      shouldRevokeSession
        ? {
            $set: { ...updatePayload, isOnline: false },
            $inc: { tokenVersion: 1 },
          }
        : { $set: updatePayload },
      { new: true },
    ).select("-mot_de_passe");

    // Send email notifications BEFORE sending response
    if (accountStatus === "suspended") {
      try {
        console.log(`[SUSPENSION] Sending email to ${user.email} for user ${user.fullname}`);
        await emailService.sendSuspensionNotification(
          user.email,
          user.fullname,
          updatePayload.suspendReason,
          updatePayload.suspendedUntil,
        );
        console.log(`[SUSPENSION] Email sent successfully to ${user.email}`);
      } catch (emailErr) {
        console.error("[SUSPENSION] Error sending suspension notification email:", emailErr);
      }
    }

    if (accountStatus === "banned") {
      try {
        console.log(`[BAN] Sending email to ${user.email} for user ${user.fullname}`);
        await emailService.sendBanNotification(
          user.email,
          user.fullname,
          updatePayload.banReason,
        );
        console.log(`[BAN] Email sent successfully to ${user.email}`);
      } catch (emailErr) {
        console.error("[BAN] Error sending ban notification email:", emailErr);
      }
    }

    if (
      accountStatus === "active" &&
      ["suspended", "banned"].includes(previousStatus)
    ) {
      try {
        console.log(`[RESTORED] Sending email to ${user.email} for user ${user.fullname}`);
        await emailService.sendAccountRestoredEmail(
          user.email,
          user.fullname,
          previousStatus,
          previousReason,
        );
        console.log(`[RESTORED] Email sent successfully to ${user.email}`);
      } catch (emailErr) {
        console.error("[RESTORED] Error sending account restored email:", emailErr);
      }
    }

    res.status(200).json({
      message: "Account status updated successfully",
      user: user,
    });

    if (shouldRevokeSession) {
      const io = req.app.get("io");
      if (io) {
        const restrictionType =
          accountStatus === "banned" ? "banned" : "suspended";
        const restrictionReason =
          restrictionType === "banned"
            ? updatePayload.banReason
            : updatePayload.suspendReason;

        io.to(`user_${id}`).emit("account_restricted", {
          type: restrictionType,
          reason: restrictionReason || null,
          suspendedUntil:
            restrictionType === "suspended"
              ? updatePayload.suspendedUntil || null
              : null,
          remainingSeconds:
            restrictionType === "suspended" && updatePayload.suspendedUntil
              ? Math.max(
                  0,
                  Math.ceil(
                    (new Date(updatePayload.suspendedUntil).getTime() -
                      Date.now()) /
                      1000,
                  ),
                )
              : null,
          message:
            restrictionType === "banned"
              ? restrictionReason
                ? `Compte banni: ${restrictionReason}`
                : "Compte banni. Contactez le support."
              : restrictionReason
                ? `Compte suspendu: ${restrictionReason}`
                : "Compte suspendu. Contactez le support.",
        });
        io.in(`user_${id}`).disconnectSockets(true);
      }
    }

    
    try {
      await createActivityLog({
        actorId: adminId,
        action: "update_user_status",
        targetType: "user",
        targetId: user._id,
        templateKey: "update_user_status",
        metadata: {
          status: accountStatus,
          targetName: existingUser?.fullname || user.fullname || "Utilisateur",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for updateAccountStatus:",
        logError.message,
      );
    }
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error updating account status", error: err.message });
  }
};

// Ban User - Ban a user and send email notification (Admin only)
exports.banUser = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const { id } = req.params;
    const { banReason } = req.body;

    if (!banReason || typeof banReason !== "string" || !banReason.trim()) {
      return res.status(400).json({
        message: "Ban reason must be a non-empty string",
      });
    }

    // Find user and update status to banned
    const user = await User.findByIdAndUpdate(
      id,
      {
        $set: {
          accountStatus: "banned",
          banReason: banReason.trim(),
          bannedAt: new Date(),
          isOnline: false,
        },
        $inc: { tokenVersion: 1 },
      },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Send ban notification email
    try {
      await emailService.sendBanNotification(
        user.email,
        user.fullname,
        banReason,
      );
    } catch (emailErr) {
      console.error("Error sending ban notification email:", emailErr);
      // Don't fail the request if email fails, just log it
    }

    res.status(200).json({
      message: "User banned successfully and notification email sent",
      user: user,
    });

    const io = req.app.get("io");
    if (io) {
      io.to(`user_${id}`).emit("account_restricted", {
        type: "banned",
        reason: banReason.trim(),
        message: `Compte banni: ${banReason.trim()}`,
      });
      io.in(`user_${id}`).disconnectSockets(true);
    }

    try {
      await createActivityLog({
        actorId: adminId,
        action: "ban_user",
        targetType: "user",
        targetId: user._id,
        templateKey: "ban_user",
        metadata: {
          targetName: user.fullname || "Utilisateur",
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for banUser:", logError.message);
    }
  } catch (err) {
    res.status(500).json({ message: "Error banning user", error: err.message });
  }
};

// Unban User - Restore a banned user account (Admin only)
exports.unbanUser = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const { id } = req.params;

    const existingUser = await User.findById(id).select("banReason");

    const user = await User.findByIdAndUpdate(
      id,
      {
        accountStatus: "active",
        banReason: null,
        bannedAt: null,
      },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    try {
      await emailService.sendAccountRestoredEmail(
        user.email,
        user.fullname,
        "banned",
        existingUser?.banReason || null,
      );
    } catch (emailErr) {
      console.error("Error sending account restored email:", emailErr);
    }

    res.status(200).json({
      message: "User unbanned successfully",
      user: user,
    });

    try {
      await createActivityLog({
        actorId: adminId,
        action: "unban_user",
        targetType: "user",
        targetId: user._id,
        templateKey: "unban_user",
        metadata: {
          targetName: user.fullname || "Utilisateur",
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for unbanUser:", logError.message);
    }
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error unbanning user", error: err.message });
  }
};

// Logout - Set user offline (POST /users/logout)
// 🚀 NEW: Privacy settings endpoints
exports.updatePrivacySettings = async (req, res) => {
  try {
    const userId = req.user.id;
    const privacyData = req.body;

    const updatedUser = await UserService.updatePrivacySettings(
      userId,
      privacyData,
    );

    res.status(200).json({
      success: true,
      message: "Privacy settings updated successfully",
      user: updatedUser,
    });
  } catch (error) {
    console.error("Error updating privacy settings:", error);
    res.status(400).json({
      success: false,
      message: error.message || "Error updating privacy settings",
    });
  }
};

exports.updateAdvancedSettings = async (req, res) => {
  try {
    const userId = req.user.id;
    const advancedData = req.body;

    const updatedUser = await UserService.updateAdvancedSettings(
      userId,
      advancedData,
    );

    res.status(200).json({
      success: true,
      message: "Advanced settings updated successfully",
      user: updatedUser,
    });
  } catch (error) {
    console.error("Error updating advanced settings:", error);
    res.status(400).json({
      success: false,
      message: error.message || "Error updating advanced settings",
    });
  }
};

// Logout - Set user offline (POST /users/logout)
exports.logout = async (req, res) => {
  try {
    const userId = req.user.userId;
    console.log(`🔴 [LOGOUT] User ${userId} is logging out...`);

    // 🚀 UPDATE: Set user offline in database
    await UserService.updateOnlineStatus(userId, false);

    console.log(`✅ [LOGOUT] User ${userId} marked as offline in database`);

    // 🚀 UPDATE: Emit offline status to partners
    const Message = require("../models/message");
    const io = req.app.get("io"); // Get socket.io instance from app

    if (io) {
      // Find all conversation partners
      const [sentTo, receivedFrom] = await Promise.all([
        Message.distinct("receiver_id", { sender_id: userId }),
        Message.distinct("sender_id", { receiver_id: userId }),
      ]);
      const partnerIds = [
        ...new Set([...sentTo.map(String), ...receivedFrom.map(String)]),
      ];

      // Emit offline status to all partners
      partnerIds.forEach((partnerId) => {
        io.to(`user_${partnerId}`).emit("user_status", {
          userId,
          isOnline: false,
          timestamp: Date.now(),
        });
        console.log(
          `📡 [LOGOUT] Emitted offline status to partner: ${partnerId}`,
        );
      });
    } else {
      console.log(`⚠️ [LOGOUT] Socket.io instance not available`);
    }

    // Invalidate all existing refresh tokens by bumping tokenVersion
    await require("../models/user").findByIdAndUpdate(userId, {
      $inc: { tokenVersion: 1 },
    });

    console.log(`🎯 [LOGOUT] User ${userId} logout completed successfully`);
    res.status(200).json({ message: "Logout successful" });
  } catch (err) {
    console.error(`❌ [LOGOUT] Error during logout:`, err);
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

// Delete user account (DELETE /users/me)
exports.deleteAccount = async (req, res) => {
  try {
    const userId = req.user.userId;
    console.log("🗑️ Delete account request from user:", userId);

    // Find and delete user
    const user = await User.findByIdAndDelete(userId);

    if (!user) {
      console.log("❌ User not found:", userId);
      return res.status(404).json({ message: "User not found" });
    }

    console.log("✅ Account deleted successfully:", userId);
    res.status(200).json({
      message: "Account deleted successfully",
      success: true,
    });
  } catch (err) {
    console.error("❌ Error deleting account:", err);
    res.status(500).json({
      message: "Error deleting account",
      error: err.message,
    });
  }
};

// Delete user by ID (Admin only) (DELETE /users/:id)
exports.deleteUser = async (req, res) => {
  try {
    const userId = req.params.id;
    console.log("🗑️ Admin request to delete user:", userId);

    // Find and delete user
    const user = await User.findByIdAndDelete(userId);

    if (!user) {
      console.log("❌ User not found:", userId);
      return res.status(404).json({ message: "User not found" });
    }

    console.log("✅ User deleted successfully by admin:", userId);
    res.status(200).json({
      message: "User deleted successfully",
      success: true,
    });
  } catch (err) {
    console.error("❌ Error deleting user:", err);
    res.status(500).json({
      message: "Error deleting user",
      error: err.message,
    });
  }
};
