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

    // Check and update account status based on activity
    await exports.updateAccountStatusBasedOnActivity(user._id);

    // Re-fetch user after potential status update
    const updatedUser = await User.findById(user._id);

    // Check if user is active
    if (updatedUser.status === "inactif") {
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

    // Update last connection and set status to actif
    updatedUser.derniere_connexion = new Date();
    updatedUser.status = "actif";
    await updatedUser.save();

    // Generate access and refresh tokens
    const { accessToken, refreshToken } = generateTokens(
      updatedUser._id,
      updatedUser.email,
      updatedUser.userType,
    );

    // Return user without password
    const userResponse = updatedUser.toObject();
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

// Update profile (PUT /users/me)
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const updateData = req.body;

    // Fields that cannot be updated via this endpoint
    const restrictedFields = [
      "mot_de_passe",
      "_id",
      "email",
      "userType",
      "date_inscription",
    ];

    // Remove restricted fields from update data
    restrictedFields.forEach((field) => delete updateData[field]);

    // Find and update user
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "Profile updated successfully",
      user: user,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error updating profile", error: err.message });
  }
};

// Update avatar (PUT /users/me/avatar)
exports.updateAvatar = async (req, res) => {
  try {
    const userId = req.user.userId;

    if (!req.file) {
      return res.status(400).json({ message: "No avatar file provided" });
    }

    // Upload to Cloudinary (if configured)
    const cloudinary = require("cloudinary").v2;
    const result = await cloudinary.uploader.upload(req.file.path, {
      folder: "travelo/avatars",
      transformation: [
        { width: 400, height: 400, crop: "fill" },
        { quality: "auto" },
      ],
    });

    // Update user avatar
    const user = await User.findByIdAndUpdate(
      userId,
      { avatar: result.secure_url },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "Avatar updated successfully",
      avatar: result.secure_url,
      user: user,
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Error updating avatar", error: err.message });
  }
};

// Update account status based on activity
exports.updateAccountStatusBasedOnActivity = async (userId) => {
  try {
    const user = await User.findById(userId);
    if (!user) return;

    const now = new Date();
    const lastConnection = user.derniere_connexion || user.date_inscription;
    const daysSinceLastConnection = Math.floor(
      (now - lastConnection) / (1000 * 60 * 60 * 24),
    );

    // Auto-suspend account after 180 days of inactivity
    if (daysSinceLastConnection > 180 && user.status === "actif") {
      user.status = "inactif";
      await user.save();
    }

    // Reactivate account if user logs back in
    if (user.status === "inactif" && daysSinceLastConnection < 180) {
      user.status = "actif";
      await user.save();
    }
  } catch (err) {
    console.error("Error updating account status:", err.message);
  }
};

// Update account status manually (PUT /users/:id/status)
exports.updateAccountStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    // Validate status
    if (!["actif", "inactif"].includes(status)) {
      return res.status(400).json({
        message: 'Status must be either "actif" or "inactif"',
      });
    }

    // Update user status
    const user = await User.findByIdAndUpdate(
      id,
      { status: status },
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

// Logout - Set status to inactif (POST /users/logout)
exports.logout = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Find user and update status to inactif
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Set status to inactif and update derniere_connexion
    user.status = "inactif";
    user.derniere_connexion = new Date();
    await user.save();

    res.status(200).json({
      message: "Logout successful, account status set to inactive",
    });
  } catch (err) {
    res.status(500).json({ message: "Error logging out", error: err.message });
  }
};
