/**
 * Contrôleur pour la gestion des usernames
 * Génération, validation, et mise à jour des usernames uniques et symboliques
 */

const User = require("../models/user");
const { generateUsernameSuggestions, createUsernameForUser, isValidUsername } = require("../utils/usernameGenerator");
const { createActivityLog } = require("../services/activityLogService");

// Générer des suggestions de usernames
exports.generateUsernameSuggestions = async (req, res) => {
  try {
    const { fullname, count = 5 } = req.body;
    const userId = req.user.userId;

    if (!fullname || fullname.trim().length < 2) {
      return res.status(400).json({
        message: "Fullname is required and must be at least 2 characters"
      });
    }

    // Récupérer les usernames existants
    const existingUsernames = await User.find({ _id: { $ne: userId } })
      .select('username')
      .lean()
      .then(users => users.map(u => u.username).filter(Boolean));

    const suggestions = generateUsernameSuggestions(fullname, existingUsernames, count);

    res.status(200).json({
      success: true,
      suggestions,
      count: suggestions.length
    });
  } catch (error) {
    console.error('[USERNAME SUGGESTIONS] Error:', error);
    res.status(500).json({
      message: "Error generating username suggestions",
      error: error.message
    });
  }
};

// Vérifier si un username est disponible
exports.checkUsernameAvailability = async (req, res) => {
  try {
    const { username } = req.params;
    const userId = req.user.userId;

    if (!username || username.trim().length < 3) {
      return res.status(400).json({
        message: "Username must be at least 3 characters"
      });
    }

    if (!isValidUsername(username)) {
      return res.status(400).json({
        message: "Invalid username format. Only letters, numbers, and underscores allowed"
      });
    }

    const existingUser = await User.findOne({ 
      username: username.toLowerCase(),
      _id: { $ne: userId }
    });

    const isAvailable = !existingUser;

    res.status(200).json({
      success: true,
      available: isAvailable,
      username: username.toLowerCase(),
      message: isAvailable ? "Username is available" : "Username is already taken"
    });
  } catch (error) {
    console.error('[USERNAME CHECK] Error:', error);
    res.status(500).json({
      message: "Error checking username availability",
      error: error.message
    });
  }
};

// Mettre à jour le username de l'utilisateur
exports.updateUsername = async (req, res) => {
  try {
    const { username } = req.body;
    const userId = req.user.userId;

    if (!username || username.trim().length < 3) {
      return res.status(400).json({
        message: "Username must be at least 3 characters"
      });
    }

    if (!isValidUsername(username)) {
      return res.status(400).json({
        message: "Invalid username format. Only letters, numbers, and underscores allowed"
      });
    }

    // Vérifier si le username est déjà pris
    const existingUser = await User.findOne({ 
      username: username.toLowerCase(),
      _id: { $ne: userId }
    });

    if (existingUser) {
      return res.status(409).json({
        message: "Username is already taken"
      });
    }

    // Mettre à jour l'utilisateur
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { 
        username: username.toLowerCase(),
        updatedAt: new Date()
      },
      { new: true, select: 'username fullname email avatar' }
    );

    if (!updatedUser) {
      return res.status(404).json({
        message: "User not found"
      });
    }

    // Logger l'action
    try {
      await createActivityLog({
        actorId: userId,
        actorName: updatedUser.fullname,
        action: "update_username",
        targetType: "user",
        targetId: userId,
        templateKey: "update_username",
        metadata: {
          oldUsername: req.user.username || null,
          newUsername: username.toLowerCase()
        }
      });
    } catch (logError) {
      console.warn('Activity log failed for username update:', logError.message);
    }

    res.status(200).json({
      success: true,
      message: "Username updated successfully",
      user: {
        username: updatedUser.username,
        fullname: updatedUser.fullname,
        email: updatedUser.email,
        avatar: updatedUser.avatar
      }
    });
  } catch (error) {
    console.error('[USERNAME UPDATE] Error:', error);
    res.status(500).json({
      message: "Error updating username",
      error: error.message
    });
  }
};

// Générer automatiquement un username pour un nouvel utilisateur
exports.generateAutoUsername = async (req, res) => {
  try {
    const { fullname } = req.body;
    const userId = req.user.userId;

    if (!fullname || fullname.trim().length < 2) {
      return res.status(400).json({
        message: "Fullname is required and must be at least 2 characters"
      });
    }

    // Fonction pour vérifier si un username existe
    const checkExists = async (username) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase(),
        _id: { $ne: userId }
      });
      return !!existing;
    };

    const generatedUsername = await createUsernameForUser(fullname, checkExists);

    // Mettre à jour l'utilisateur avec le nouveau username
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { 
        username: generatedUsername,
        updatedAt: new Date()
      },
      { new: true, select: 'username fullname email avatar' }
    );

    if (!updatedUser) {
      return res.status(404).json({
        message: "User not found"
      });
    }

    // Logger l'action
    try {
      await createActivityLog({
        actorId: userId,
        actorName: updatedUser.fullname,
        action: "auto_generate_username",
        targetType: "user",
        targetId: userId,
        templateKey: "auto_generate_username",
        metadata: {
          generatedUsername: generatedUsername,
          basedOnFullname: fullname
        }
      });
    } catch (logError) {
      console.warn('Activity log failed for auto username generation:', logError.message);
    }

    res.status(200).json({
      success: true,
      message: "Username generated and assigned successfully",
      user: {
        username: updatedUser.username,
        fullname: updatedUser.fullname,
        email: updatedUser.email,
        avatar: updatedUser.avatar
      }
    });
  } catch (error) {
    console.error('[AUTO USERNAME] Error:', error);
    res.status(500).json({
      message: "Error generating username",
      error: error.message
    });
  }
};
