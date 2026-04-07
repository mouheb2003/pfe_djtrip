const jwt = require("jsonwebtoken");
const User = require("../models/user");
const emailService = require("../services/email");

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
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required",
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);

    const user = await User.findById(decoded.userId).select(
      "email fullname accountStatus suspendedUntil suspendReason banReason tokenVersion",
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // Revoke old access tokens after admin actions (ban/suspend/logout)
    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      return res.status(401).json({
        success: false,
        forceLogout: true,
        message: "Session expired. Please log in again.",
      });
    }

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

      return res.status(403).json({
        success: false,
        forceLogout: true,
        type: "suspended",
        reason: user.suspendReason || null,
        suspendedUntil: user.suspendedUntil || null,
        remainingSeconds,
        message: user.suspendReason
          ? `Compte suspendu: ${user.suspendReason}`
          : "Compte suspendu. Contactez le support.",
      });
    }

    if (user.accountStatus === "banned") {
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
      return res.status(403).json({
        success: false,
        forceLogout: true,
        message: "Compte inactif. Contactez le support.",
      });
    }

    req.user = decoded;
    next();
  } catch (err) {
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

// Middleware to verify Organisator userType
exports.verifyOrganisator = (req, res, next) => {
  if (req.user.userType !== "Organisator") {
    return res.status(403).json({
      success: false,
      message: "Access denied. Organisator access required.",
    });
  }
  next();
};

// Middleware to verify Touriste userType
exports.verifyTouriste = (req, res, next) => {
  if (req.user.userType !== "Touriste") {
    return res.status(403).json({
      success: false,
      message: "Access denied. Touriste access required.",
    });
  }
  next();
};

// Middleware to verify Admin userType
exports.verifyAdmin = (req, res, next) => {
  if (req.user.userType !== "Admin") {
    return res.status(403).json({
      success: false,
      message: "Access denied. Admin access required.",
    });
  }
  next();
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
