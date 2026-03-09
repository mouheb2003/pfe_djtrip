const jwt = require("jsonwebtoken");

// JWT Secrets (in production, use environment variables)
const JWT_SECRET = process.env.JWT_SECRET || "your_secret_key";
const REFRESH_TOKEN_SECRET =
  process.env.REFRESH_TOKEN_SECRET || "your_refresh_secret_key";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "2h";
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || "7d";

// Generate Access Token (short-lived)
exports.generateAccessToken = (userId, email, userType) => {
  return jwt.sign({ userId, email, userType }, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN,
  });
};

// Generate Refresh Token (long-lived)
exports.generateRefreshToken = (userId, email, userType) => {
  return jwt.sign({ userId, email, userType }, REFRESH_TOKEN_SECRET, {
    expiresIn: REFRESH_TOKEN_EXPIRES_IN,
  });
};

// Generate both tokens
exports.generateTokens = (userId, email, userType) => {
  const accessToken = exports.generateAccessToken(userId, email, userType);
  const refreshToken = exports.generateRefreshToken(userId, email, userType);

  return {
    accessToken,
    refreshToken,
  };
};

// Middleware to verify access token
exports.verifyToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({ message: "No token provided" });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // Add user info to request
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

// Refresh Token Handler
exports.refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({ message: "Refresh token required" });
    }

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);

    // Generate new access token
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
        .json({ message: "Refresh token expired. Please login again." });
    }
    return res.status(401).json({ message: "Invalid refresh token" });
  }
};
