const jwt = require("jsonwebtoken");
const User = require("../models/user");
const emailService = require("../services/email");

const lastActiveAtMap = new Map();

exports.trackUserActivity = (userId) => {
  if (!userId) return;
  const now = Date.now();
  const lastUpdate = lastActiveAtMap.get(userId.toString()) || 0;
  if (now - lastUpdate > 15000) {
    lastActiveAtMap.set(userId.toString(), now);
    try {
      User.updateOne(
        { _id: userId },
        { lastActiveAt: new Date(now) }
      ).exec().catch(err => console.error("Error updating lastActiveAt in background:", err));
    } catch (e) {
      console.error("Failed to enqueue user activity update:", e);
    }
  }
};

// JWT Secrets — must be defined in .env
const JWT_SECRET = process.env.JWT_SECRET;
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "2h";
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || "7d";

if (!JWT_SECRET || !REFRESH_TOKEN_SECRET) {
  throw new Error(
    "FATAL: JWT_SECRET and REFRESH_TOKEN_SECRET must be set in environment variables.",
  );
}

// Generate Access Token (short-lived)
exports.generateAccessToken = (userId, email, userType, tokenVersion = 0) => {
  return jwt.sign({ userId, email, userType, tokenVersion }, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN,
  });
};

// Generate Refresh Token (long-lived, includes tokenVersion to support revocation)
exports.generateRefreshToken = (userId, email, userType, tokenVersion = 0) => {
  return jwt.sign(
    { userId, email, userType, tokenVersion },
    REFRESH_TOKEN_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRES_IN },
  );
};

// Generate both tokens
exports.generateTokens = (userId, email, userType, tokenVersion = 0) => {
  const accessToken = exports.generateAccessToken(
    userId,
    email,
    userType,
    tokenVersion,
  );
  const refreshToken = exports.generateRefreshToken(
    userId,
    email,
    userType,
    tokenVersion,
  );
  return { accessToken, refreshToken };
};

// Middleware to verify access token
exports.verifyToken = async (req, res, next) => {
  try {
    console.log('[AUTH verifyToken] Starting verification for:', req.method, req.path);
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      console.log('[AUTH verifyToken] No token provided');
      return res.status(401).json({
        success: false,
        message: "Authentication token is required",
      });
    }
    console.log('[AUTH verifyToken] Token provided');

    const decoded = jwt.verify(token, JWT_SECRET);

    const user = await User.findById(decoded.userId).select(
      "email fullname accountStatus suspendedUntil suspendReason banReason tokenVersion userType",
    );

    if (!user) {
      console.log('[AUTH verifyToken] User not found');
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    console.log('[AUTH verifyToken] User found, accountStatus:', user.accountStatus, 'userType:', user.userType);

    // Revoke old access tokens after admin actions (ban/suspend/logout)
    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      console.log('[AUTH verifyToken] Token version mismatch');
      return res.status(401).json({
        success: false,
        forceLogout: true,
        message: "Session expired. Please log in again.",
      });
    }

    // Use userType from database instead of token to handle userType changes
    req.user = {
      userId: user._id,
      email: user.email,
      userType: user.userType,
      tokenVersion: user.tokenVersion,
    };

    // Track user activity on verified request
    exports.trackUserActivity(user._id);

    console.log('[AUTH verifyToken] req.user set, calling next()');

    // Auto-reactivate when suspension is expired
    if (user.accountStatus === "suspended" && user.suspendedUntil) {
      const now = new Date();
      if (user.suspendedUntil <= now) {
        const previousReason = user.suspendReason || null;
        user.accountStatus = "active";
        user.suspendedUntil = null;
        user.suspendReason = null;
        await user.save();

        if (user.email) {
          try {
            await emailService.sendAccountRestoredEmail(
              user.email,
              user.fullname || "DJTrip User",
              "suspended",
              previousReason,
            );
          } catch (emailErr) {
            console.error(
              "Error sending auto-restored account email:",
              emailErr,
            );
          }
        }
      }
    }

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

      console.log('[AUTH SUSPENSION] user.suspendedUntil:', user.suspendedUntil, 'type:', typeof user.suspendedUntil);
      console.log('[AUTH SUSPENSION] suspendedUntilISO:', suspendedUntilISO);
      console.log('[AUTH SUSPENSION] remainingSeconds:', remainingSeconds);
      console.log('[AUTH SUSPENSION] suspendReason:', user.suspendReason);

      return res.status(403).json({
        success: false,
        forceLogout: true,
        type: "suspended",
        reason: user.suspendReason || null,
        suspendedUntil: suspendedUntilISO,
        remainingSeconds,
        message: user.suspendReason
          ? `Compte suspendu: ${user.suspendReason}`
          : "Compte suspendu. Contactez le support.",
      });
    }

    if (user.accountStatus === "banned") {
      console.log('[AUTH verifyToken] User is banned');
      return res.status(403).json({
        success: false,
        forceLogout: true,
        type: "banned",
        reason: user.banReason || null,
        message: user.banReason
          ? `Compte banni: ${user.banReason}`
          : "Compte banni. Contactez le support.",
      });
    }

    if (user.accountStatus === "inactive") {
      console.log('[AUTH verifyToken] User is inactive');
      return res.status(403).json({
        success: false,
        forceLogout: true,
        message: "Compte inactif. Contactez le support.",
      });
    }

    console.log('[AUTH verifyToken] Verification passed');
    next();
  } catch (err) {
    console.log('[AUTH verifyToken] Error:', err.name, err.message);
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({
        success: false,
        message: "Authentication token expired",
      });
    }
    return res.status(401).json({
      success: false,
      message: "Invalid authentication token",
    });
  }
};

// Optional authentication middleware - tries to verify token but continues even if missing/invalid
exports.optionalToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      // No token provided, continue without user
      return next();
    }

    const decoded = jwt.verify(token, JWT_SECRET);

    const user = await User.findById(decoded.userId).select(
      "email fullname accountStatus suspendedUntil suspendReason banReason tokenVersion userType",
    );

    if (!user) {
      // User not found, continue without user
      return next();
    }

    // Check token version
    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      // Token version mismatch, continue without user
      return next();
    }

    // Set user in request if valid
    req.user = {
      userId: user._id,
      email: user.email,
      userType: user.userType,
      tokenVersion: user.tokenVersion,
    };

    // Track user activity on verified request
    exports.trackUserActivity(user._id);

    next();
  } catch (err) {
    // Token invalid or expired, continue without user
    next();
  }
};

// Middleware to verify Organisator userType
exports.verifyOrganisator = async (req, res, next) => {
  try {
    console.log('[AUTH verifyOrganisator] Starting verification for:', req.method, req.path);
    // Fetch fresh user data from database to ensure we have the latest userType
    const User = require("../models/user");
    const user = await User.findById(req.user.userId).select(
      "userType is_onboarded is_approved signup_method"
    );

    if (!user) {
      console.log('[AUTH verifyOrganisator] User not found');
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    console.log('[AUTH verifyOrganisator] User found, userType:', user.userType, 'is_onboarded:', user.is_onboarded, 'is_approved:', user.is_approved);

    // Update req.user with fresh data
    req.user.userType = user.userType;
    req.user.is_onboarded = user.is_onboarded;
    req.user.is_approved = user.is_approved;

    // Check if user is an organizer
    if (user.userType !== "Organisator") {
      // Only return requires_onboarding if user has no userType at all
      const needsOnboarding = !user.userType || user.userType === null;
      console.log('[AUTH verifyOrganisator] User is not an organizer, needsOnboarding:', needsOnboarding);
      return res.status(403).json({
        success: false,
        message: "Access denied. Organisator access required.",
        requires_onboarding: needsOnboarding,
      });
    }

    // For organizers, check if they are onboarded and approved
    if (!user.is_onboarded) {
      console.log('[AUTH verifyOrganisator] Organizer not onboarded');
      return res.status(403).json({
        success: false,
        message: "Please complete onboarding to access organizer features",
        requires_onboarding: true,
      });
    }

    if (!user.is_approved) {
      console.log('[AUTH verifyOrganisator] Organizer not approved');
      return res.status(403).json({
        success: false,
        message: "Your organizer account is waiting for approval",
        requires_approval: true,
      });
    }

    console.log('[AUTH verifyOrganisator] Verification passed');
    next();
  } catch (error) {
    console.error("[AUTH verifyOrganisator] Error:", error);
    return res.status(500).json({
      success: false,
      message: "Error verifying organizer access",
    });
  }
};

// Middleware to verify Touriste userType
exports.verifyTouriste = async (req, res, next) => {
  try {
    // Fetch fresh user data from database to ensure we have the latest userType
    const User = require("../models/user");
    const user = await User.findById(req.user.userId).select(
      "userType is_onboarded"
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // Update req.user with fresh data
    req.user.userType = user.userType;
    req.user.is_onboarded = user.is_onboarded;

    // Check if user is a tourist
    if (user.userType !== "Touriste") {
      // Only return requires_onboarding if user has no userType at all
      const needsOnboarding = !user.userType || user.userType === null;
      return res.status(403).json({
        success: false,
        message: "Access denied. Touriste access required.",
        requires_onboarding: needsOnboarding,
      });
    }

    next();
  } catch (error) {
    console.error("Error in verifyTouriste middleware:", error);
    return res.status(500).json({
      success: false,
      message: "Error verifying tourist access",
    });
  }
};

// Middleware to verify Admin userType
exports.verifyAdmin = async (req, res, next) => {
  try {
    // Fetch fresh user data from database to ensure we have the latest userType
    const User = require("../models/user");
    const user = await User.findById(req.user.userId).select("userType");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // Update req.user with fresh data
    req.user.userType = user.userType;

    // Check if user is an admin
    if (user.userType !== "Admin") {
      return res.status(403).json({
        success: false,
        message: "Access denied. Admin access required.",
      });
    }

    next();
  } catch (error) {
    console.error("Error in verifyAdmin middleware:", error);
    return res.status(500).json({
      success: false,
      message: "Error verifying admin access",
    });
  }
};

// Middleware to verify Tourist or Organizer userType (for routes accessible to both)
exports.verifyTouristeOrOrganisator = async (req, res, next) => {
  try {
    // Fetch fresh user data from database to ensure we have the latest userType
    const User = require("../models/user");
    const user = await User.findById(req.user.userId).select(
      "userType is_onboarded is_approved"
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // Update req.user with fresh data
    req.user.userType = user.userType;
    req.user.is_onboarded = user.is_onboarded;
    req.user.is_approved = user.is_approved;

    // Check if user is a tourist or organizer
    if (user.userType !== "Touriste" && user.userType !== "Organisator") {
      const needsOnboarding = !user.userType || user.userType === null;
      return res.status(403).json({
        success: false,
        message: "Access denied. Tourist or Organizer access required.",
        requires_onboarding: needsOnboarding,
      });
    }

    // For organizers, check if they are onboarded and approved
    if (user.userType === "Organisator") {
      if (!user.is_onboarded) {
        return res.status(403).json({
          success: false,
          message: "Please complete onboarding to access this feature",
          requires_onboarding: true,
        });
      }

      if (!user.is_approved) {
        return res.status(403).json({
          success: false,
          message: "Your organizer account is waiting for approval",
          requires_approval: true,
        });
      }
    }

    next();
  } catch (error) {
    console.error("Error in verifyTouristeOrOrganisator middleware:", error);
    return res.status(500).json({
      success: false,
      message: "Error verifying access",
    });
  }
};

// Refresh Token Handler — verifies tokenVersion to detect revoked tokens
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({
        success: false,
        message: "Refresh token required",
      });
    }

    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);

    // Check tokenVersion against the database to catch revoked tokens (e.g. after logout)
    const user = await User.findById(decoded.userId).select("tokenVersion");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      return res.status(401).json({
        success: false,
        message: "Token has been revoked. Please log in again.",
      });
    }

    const newAccessToken = exports.generateAccessToken(
      decoded.userId,
      decoded.email,
      decoded.userType,
      user.tokenVersion || 0,
    );

    res.status(200).json({
      success: true,
      message: "Token refreshed successfully",
      accessToken: newAccessToken,
    });
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({
        success: false,
        message: "Refresh token expired. Please log in again.",
      });
    }
    return res.status(401).json({
      success: false,
      message: "Invalid refresh token",
    });
  }
};
