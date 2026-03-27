const jwt = require("jsonwebtoken");
const User = require("../models/user");

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
exports.generateAccessToken = (userId, email, userType) => {
  return jwt.sign({ userId, email, userType }, JWT_SECRET, {
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
  const accessToken = exports.generateAccessToken(userId, email, userType);
  const refreshToken = exports.generateRefreshToken(
    userId,
    email,
    userType,
    tokenVersion,
  );
  return { accessToken, refreshToken };
};

// Middleware to verify access token
exports.verifyToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expired" });
    }
    return res.status(401).json({ message: "Invalid token" });
  }
};

// Middleware to verify Organisator userType
exports.verifyOrganisator = (req, res, next) => {
  if (req.user.userType !== "Organisator") {
    return res
      .status(403)
      .json({ message: "Access denied. Organisator access required." });
  }
  next();
};

// Middleware to verify Touriste userType
exports.verifyTouriste = (req, res, next) => {
  if (req.user.userType !== "Touriste") {
    return res
      .status(403)
      .json({ message: "Access denied. Touriste access required." });
  }
  next();
};

// Middleware to verify Admin userType
exports.verifyAdmin = (req, res, next) => {
  if (req.user.userType !== "Admin") {
    return res
      .status(403)
      .json({ message: "Access denied. Admin access required." });
  }
  next();
};

// Refresh Token Handler — verifies tokenVersion to detect revoked tokens
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({ message: "Refresh token required" });
    }

    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);

    // Check tokenVersion against the database to catch revoked tokens (e.g. after logout)
    const user = await User.findById(decoded.userId).select("tokenVersion");
    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }

    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      return res.status(401).json({
        message: "Token has been revoked. Please log in again.",
      });
    }

    const newAccessToken = exports.generateAccessToken(
      decoded.userId,
      decoded.email,
      decoded.userType,
    );

    res.status(200).json({
      message: "Token refreshed successfully",
      accessToken: newAccessToken,
    });
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res
        .status(401)
        .json({ message: "Refresh token expired. Please log in again." });
    }
    return res.status(401).json({ message: "Invalid refresh token" });
  }
};
