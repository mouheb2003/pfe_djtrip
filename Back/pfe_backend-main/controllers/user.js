const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const bcrypt = require("bcryptjs");
const { generateTokens } = require("../middleware/auth");

// Sign Up - Register a new user (Phase 1: Basic info only)
exports.signUp = async (req, res) => {
  try {
    const { fullname, email, mot_de_passe, userType, ...additionalData } =
      req.body;

    // Validate required fields
    if (!fullname || !email || !mot_de_passe) {
      return res
        .status(400)
        .json({ message: "Fullname, email, and password are required" });
    }

    // Validate userType
    if (!userType || !["Touriste", "Organisator"].includes(userType)) {
      return res.status(400).json({
        message: 'userType must be either "Touriste" or "Organisator"',
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: "Email already registered" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(mot_de_passe, 10);

    // Create user based on userType
    let user;
    const baseData = {
      fullname,
      email,
      mot_de_passe: hashedPassword,
      date_inscription: new Date(),
      status: "actif",
      ...additionalData,
    };

    if (userType === "Touriste") {
      user = new Touriste(baseData);
    } else if (userType === "Organisator") {
      user = new Organisator(baseData);
    }

    await user.save();

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
    );

    // Return user without password
    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;

    res.status(201).json({
      message: "User registered successfully. Please complete your profile.",
      accessToken,
      refreshToken,
      user: userResponse,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error registering user", error: err.message });
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

    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Check if user is active
    if (user.status === "inactif") {
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
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Update last connection
    user.derniere_connexion = new Date();
    await user.save();

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      user._id,
      user.email,
      user.userType,
    );

    // Return user without password
    const userResponse = user.toObject();
    delete userResponse.mot_de_passe;

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
    // req.user.userId is set by verifyToken middleware
    const userId = req.user.userId;

    // Fetch user from database
    const user = await User.findById(userId).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "User info retrieved successfully",
      user: user,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error retrieving user info", error: err.message });
  }
};

// Get all users
exports.getAllUsers = async (req, res) => {
  try {
    // Fetch all users from database (including Touriste and Organisator)
    const users = await User.find().select("-mot_de_passe");

    res.status(200).json({
      message: "Users retrieved successfully",
      count: users.length,
      users: users,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error retrieving users", error: err.message });
  }
};

// Get user by ID
exports.getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "User retrieved successfully",
      user: user,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error retrieving user", error: err.message });
  }
};
