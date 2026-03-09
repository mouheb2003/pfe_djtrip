const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const bcrypt = require("bcryptjs");
const emailService = require("./email");

/**
 * Service pour gérer les opérations sur les utilisateurs
 */
class UserService {
  /**
   * Récupère un utilisateur par son ID
   * @param {String} userId - ID de l'utilisateur
   * @param {Boolean} includePassword - Inclure le mot de passe (par défaut: false)
   * @returns {Promise<Object>} Utilisateur
   */
  static async getUserById(userId, includePassword = false) {
    const query = User.findById(userId);

    if (!includePassword) {
      query.select("-mot_de_passe");
    }

    const user = await query;

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Récupère tous les utilisateurs
   * @returns {Promise<Array>} Liste des utilisateurs
   */
  static async getAllUsers() {
    const users = await User.find().select("-mot_de_passe");
    return users;
  }

  /**
   * Récupère un utilisateur par email
   * @param {String} email - Email de l'utilisateur
   * @param {Boolean} includePassword - Inclure le mot de passe
   * @returns {Promise<Object>} Utilisateur
   */
  static async getUserByEmail(email, includePassword = false) {
    const query = User.findOne({ email });

    if (!includePassword) {
      query.select("-mot_de_passe");
    }

    const user = await query;

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Met à jour le profil d'un utilisateur
   * @param {String} userId - ID de l'utilisateur
   * @param {Object} updateData - Données à mettre à jour
   * @returns {Promise<Object>} Utilisateur mis à jour
   */
  static async updateProfile(userId, updateData) {
    // Fields that cannot be updated via this method
    const restrictedFields = [
      "mot_de_passe",
      "_id",
      "email",
      "userType",
      "date_inscription",
      "verificationCode",
      "verificationCodeExpiry",
      "passwordResetCode",
      "passwordResetCodeExpiry",
      "isOnline",
      "accountStatus",
      "derniere_connexion",
    ];

    // Remove restricted fields from update data
    const sanitizedData = { ...updateData };
    restrictedFields.forEach((field) => delete sanitizedData[field]);

    // Find and update user
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: sanitizedData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log("✅ User profile updated:", userId);
    return user;
  }

  /**
   * Met à jour le mot de passe d'un utilisateur
   * @param {String} userId - ID de l'utilisateur
   * @param {String} currentPassword - Mot de passe actuel
   * @param {String} newPassword - Nouveau mot de passe
   * @returns {Promise<Boolean>} Succès de l'opération
   */
  static async updatePassword(userId, currentPassword, newPassword) {
    // Get user with password
    const user = await User.findById(userId);

    if (!user) {
      throw new Error("User not found");
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(
      currentPassword,
      user.mot_de_passe,
    );

    if (!isPasswordValid) {
      throw new Error("Current password is incorrect");
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password
    user.mot_de_passe = hashedPassword;
    await user.save();

    console.log("✅ User password updated:", userId);
    return true;
  }

  /**
   * Met à jour le statut du compte d'un utilisateur (active, suspended, banned, inactive)
   * @param {String} userId - ID de l'utilisateur
   * @param {String} accountStatus - Nouveau statut (active/suspended/banned/inactive)
   * @returns {Promise<Object>} Utilisateur mis à jour
   */
  static async updateAccountStatus(userId, accountStatus) {
    if (
      !["active", "suspended", "banned", "inactive"].includes(accountStatus)
    ) {
      throw new Error(
        'Account status must be either "active", "suspended", "banned", or "inactive"',
      );
    }

    const user = await User.findByIdAndUpdate(
      userId,
      { accountStatus },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log(`✅ User account status updated to ${accountStatus}:`, userId);
    return user;
  }

  /**
   * Met à jour la dernière connexion et l'état en ligne d'un utilisateur
   * @param {String} userId - ID de l'utilisateur
   * @returns {Promise<Object>} Utilisateur mis à jour
   */
  static async updateLastConnection(userId) {
    const user = await User.findByIdAndUpdate(
      userId,
      {
        derniere_connexion: new Date(),
        isOnline: true,
      },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Met à jour l'état en ligne de l'utilisateur
   * @param {String} userId - ID de l'utilisateur
   * @param {Boolean} isOnline - État en ligne
   * @returns {Promise<Object>} Utilisateur mis à jour
   */
  static async updateOnlineStatus(userId, isOnline) {
    const user = await User.findByIdAndUpdate(
      userId,
      { isOnline: isOnline },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log(
      `🔵 User online status updated: ${userId} - ${isOnline ? "Online" : "Offline"}`,
    );
    return user;
  }

  /**
   * Vérifie et met à jour le statut du compte basé sur l'activité
   * NOTE: Cette méthode ne change plus automatiquement accountStatus
   * Elle sert maintenant uniquement à des fins de monitoring
   * @param {String} userId - ID de l'utilisateur
   * @returns {Promise<Object>} Utilisateur mis à jour
   */
  static async updateAccountStatusBasedOnActivity(userId) {
    const user = await User.findById(userId);

    if (!user) {
      throw new Error("User not found");
    }

    // Log for monitoring purposes only
    if (user.derniere_connexion) {
      const now = new Date();
      const daysSinceLastConnection = Math.floor(
        (now - user.derniere_connexion) / (1000 * 60 * 60 * 24),
      );

      if (daysSinceLastConnection > 90) {
        console.log(
          `ℹ️ User inactive for ${daysSinceLastConnection} days:`,
          userId,
        );
      }
    }

    return user;
  }

  /**
   * Crée un nouvel utilisateur (utilisé pour l'inscription)
   * @param {Object} userData - Données de l'utilisateur
   * @returns {Promise<Object>} Utilisateur créé
   */
  static async createUser(userData) {
    const { fullname, email, mot_de_passe, userType, ...additionalData } =
      userData;

    // Validate required fields
    if (!fullname || !email || !mot_de_passe) {
      throw new Error("Fullname, email, and password are required");
    }

    // Validate userType
    if (!userType || !["Touriste", "Organisator"].includes(userType)) {
      throw new Error('userType must be either "Touriste" or "Organisator"');
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      throw new Error("Email already registered");
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(mot_de_passe, 10);

    // Generate verification code
    const verificationCode = emailService.generateVerificationCode();
    const verificationCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Prepare base data
    const baseData = {
      fullname,
      email,
      mot_de_passe: hashedPassword,
      date_inscription: new Date(),
      accountStatus: "active",
      isOnline: false,
      emailVerified: false,
      verificationCode,
      verificationCodeExpiry,
      ...additionalData,
    };

    // Create user based on userType
    let user;
    if (userType === "Touriste") {
      user = new Touriste(baseData);
    } else if (userType === "Organisator") {
      user = new Organisator(baseData);
    }

    await user.save();

    // Send verification email asynchronously (don't block response)
    emailService
      .sendVerificationEmail(email, verificationCode, fullname)
      .then((emailResult) => {
        console.log(
          "📧 Verification email sent:",
          user._id,
          "Success:",
          emailResult.success,
        );
      })
      .catch((error) => {
        console.error("❌ Error sending verification email:", error.message);
      });

    // Log verification code in development mode
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("📧 EMAIL VERIFICATION CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", fullname);
      console.log("Email:", email);
      console.log("Code:", verificationCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ New user created:", user._id);
    return user;
  }

  /**
   * Vérifie le code de vérification email
   * @param {String} email - Email de l'utilisateur
   * @param {String} code - Code de vérification
   * @returns {Promise<Object>} Utilisateur vérifié
   */
  static async verifyEmail(email, code) {
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("User not found");
    }

    if (user.emailVerified) {
      throw new Error("Email already verified");
    }

    if (!user.verificationCode || user.verificationCode !== code) {
      throw new Error("Invalid verification code");
    }

    if (new Date() > user.verificationCodeExpiry) {
      throw new Error("Verification code expired");
    }

    // Mark email as verified
    user.emailVerified = true;
    user.verificationCode = undefined;
    user.verificationCodeExpiry = undefined;
    await user.save();

    console.log("✅ Email verified for user:", user._id);
    return user;
  }

  /**
   * Renvoie un code de vérification email
   * @param {String} email - Email de l'utilisateur
   * @returns {Promise<Object>} Utilisateur avec nouveau code
   */
  static async resendVerificationCode(email) {
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("User not found");
    }

    if (user.emailVerified) {
      throw new Error("Email already verified");
    }

    // Generate new verification code
    const verificationCode = emailService.generateVerificationCode();
    const verificationCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    user.verificationCode = verificationCode;
    user.verificationCodeExpiry = verificationCodeExpiry;
    await user.save();

    // Send verification email
    const emailResult = await emailService.sendVerificationEmail(
      email,
      verificationCode,
      user.fullname,
    );

    // Log in development
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("📧 NEW VERIFICATION CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", user.fullname);
      console.log("Email:", email);
      console.log("Code:", verificationCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ Verification code resent to:", email);
    return { success: emailResult.success, user };
  }

  /**
   * Supprime un utilisateur
   * @param {String} userId - ID de l'utilisateur
   * @returns {Promise<Boolean>} Succès de l'opération
   */
  static async deleteUser(userId) {
    const user = await User.findByIdAndDelete(userId);

    if (!user) {
      throw new Error("User not found");
    }

    console.log("🗑️ User deleted:", userId);
    return true;
  }

  /**
   * Forgot Password - Generate reset code and send email
   * @param {string} email - User email
   * @returns {Object} - Result object
   */
  static async forgotPassword(email) {
    // Find user by email
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("No account found with this email address");
    }

    // Generate 6-digit reset code
    const resetCode = emailService.generateVerificationCode();
    const resetCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Save reset code to user
    user.passwordResetCode = resetCode;
    user.passwordResetCodeExpiry = resetCodeExpiry;
    await user.save();

    // Send password reset email asynchronously (don't block response)
    emailService
      .sendPasswordResetEmail(email, resetCode, user.fullname)
      .then((emailResult) => {
        console.log(
          "📧 Password reset email sent:",
          user._id,
          "Success:",
          emailResult.success,
        );
      })
      .catch((error) => {
        console.error("❌ Error sending password reset email:", error.message);
      });

    // Log reset code in development mode
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("🔑 PASSWORD RESET CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", user.fullname);
      console.log("Email:", email);
      console.log("Reset Code:", resetCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ Password reset code generated for user:", user._id);

    return {
      success: true,
      message: "Password reset code sent to your email",
    };
  }

  /**
   * Reset Password - Verify code and update password
   * @param {string} email - User email
   * @param {string} code - Reset code
   * @param {string} newPassword - New password
   * @returns {Object} - Result object
   */
  static async resetPassword(email, code, newPassword) {
    // Find user by email
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("No account found with this email address");
    }

    // Check if reset code exists and is not expired
    if (!user.passwordResetCode || !user.passwordResetCodeExpiry) {
      throw new Error("No password reset request found");
    }

    if (user.passwordResetCode !== code) {
      throw new Error("Invalid reset code");
    }

    if (new Date() > user.passwordResetCodeExpiry) {
      throw new Error("Reset code has expired. Please request a new one");
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password, clear reset code, and reactivate account
    user.mot_de_passe = hashedPassword;
    user.passwordResetCode = undefined;
    user.passwordResetCodeExpiry = undefined;
    user.accountStatus = "active"; // Reactivate account on password reset
    user.derniere_connexion = new Date(); // Update last connection
    await user.save();

    console.log("✅ Password reset successful for user:", user._id);

    return {
      success: true,
      message: "Password has been reset successfully",
    };
  }
}

module.exports = UserService;
