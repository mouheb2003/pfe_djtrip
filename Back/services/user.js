const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const Admin = require("../models/admin");
const bcrypt = require("bcryptjs");
const emailService = require("./email");

/**
 * Service for managing user operations
 */
class UserService {
  /**
   * Retrieves a user by their ID
   * @param {String} userId - User ID
   * @param {Boolean} includePassword - Include password (default: false)
   * @returns {Promise<Object>} User
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
   * Retrieves all users
   * @returns {Promise<Array>} List of users
   */
  static async getAllUsers() {
    const users = await User.find().select("-mot_de_passe");
    return users;
  }

  /**
   * Retrieves a user by email
   * @param {String} email - User email
   * @param {Boolean} includePassword - Include password (default: false)
   * @returns {Promise<Object>} User
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
   * Updates a user's profile
   * @param {String} userId - User ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated user
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
   * Updates a user's password
   * @param {String} userId - User ID
   * @param {String} currentPassword - Current password
   * @param {String} newPassword - New password
   * @returns {Promise<Boolean>} Operation success
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
   * Updates account status (active, suspended, banned, inactive)
   * @param {String} userId - User ID
   * @param {String} accountStatus - New status (active/suspended/banned/inactive)
   * @returns {Promise<Object>} Updated user
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
   * Updates last connection and online status of a user
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated user
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
   * Updates online status
   * @param {String} userId - User ID
   * @param {Boolean} isOnline - Online state
   * @returns {Promise<Object>} Updated user
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
   * Checks and updates account status based on activity
   * NOTE: This method no longer automatically changes accountStatus
   * It now serves only for monitoring purposes
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated user
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
   * Creates a new user (used for registration)
   * @param {Object} userData - User data
   * @returns {Promise<Object>} Created user
   */
  static async createUser(userData) {
    const { fullname, email, mot_de_passe, userType, ...additionalData } =
      userData;

    // Validate required fields
    if (!fullname || !email || !mot_de_passe) {
      throw new Error("Fullname, email, and password are required");
    }

    // Validate userType
    if (!userType || !["Touriste", "Organisator", "Admin"].includes(userType)) {
      throw new Error(
        'userType must be either "Touriste", "Organisator", or "Admin"',
      );
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
    } else if (userType === "Admin") {
      user = new Admin(baseData);
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
   * Verifies the email verification code
   * @param {String} email - User email
   * @param {String} code - Verification code
   * @returns {Promise<Object>} Verified user
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
   * Resends an email verification code
   * @param {String} email - User email
   * @returns {Promise<Object>} User with new code
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
   * Deletes a user
   * @param {String} userId - User ID
   * @returns {Promise<Boolean>} Operation success
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
