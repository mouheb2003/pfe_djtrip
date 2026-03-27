const cloudinary = require("../config/cloudinary");
const User = require("../models/user");

/**
 * Service to manage user avatars
 */
class AvatarService {
  /**
   * Upload an avatar to Cloudinary
   * @param {Buffer} fileBuffer - Image file buffer
   * @param {Object} options - Upload options
   * @returns {Promise<Object>} Upload result with secure_url
   */
  static async uploadToCloudinary(fileBuffer, options = {}) {
    const defaultOptions = {
      folder: "DJTrip/avatars",
      transformation: {
        width: 400,
        height: 400,
        crop: "fill",
        quality: "auto",
      },
    };

    const uploadOptions = { ...defaultOptions, ...options };

    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        uploadOptions,
        (error, result) => {
          if (error) {
            console.error("❌ Cloudinary upload error:", error);
            reject(error);
          } else {
            console.log("✅ Cloudinary upload successful:", result.secure_url);
            resolve(result);
          }
        },
      );

      uploadStream.end(fileBuffer);
    });
  }

  /**
   * Updates a user's avatar in the database
   * @param {String} userId - User ID
   * @param {String} avatarUrl - Avatar URL
   * @returns {Promise<Object>} Updated user
   */
  static async updateUserAvatar(userId, avatarUrl) {
    const user = await User.findByIdAndUpdate(
      userId,
      { avatar: avatarUrl },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log("✅ User avatar updated in database");
    return user;
  }

  /**
   * Deletes an avatar from Cloudinary
   * @param {String} avatarUrl - URL of the avatar to delete
   * @returns {Promise<Object>} Deletion result
   */
  static async deleteFromCloudinary(avatarUrl) {
    try {
      // Extract the public_id from the Cloudinary URL
      const urlParts = avatarUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const publicId = `DJTrip/avatars/${filename.split(".")[0]}`;

      const result = await cloudinary.uploader.destroy(publicId);
      console.log("🗑️ Avatar deleted from Cloudinary:", publicId);
      return result;
    } catch (error) {
      console.error("❌ Error deleting avatar from Cloudinary:", error);
      throw error;
    }
  }

  /**
   * Deletes a user's avatar (Cloudinary + DB)
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated user
   */
  static async deleteAvatar(userId) {
    const user = await User.findById(userId).select("avatar");

    if (!user) {
      throw new Error("User not found");
    }

    if (user.avatar) {
      try {
        await this.deleteFromCloudinary(user.avatar);
      } catch (error) {
        console.warn(
          "⚠️ Could not delete avatar from Cloudinary:",
          error.message,
        );
      }
    }

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $unset: { avatar: 1 } },
      { new: true },
    ).select("-mot_de_passe");

    console.log("✅ Avatar deleted for user:", userId);
    return updatedUser;
  }

  /**
   * Replaces a user's avatar (deletes the old one and uploads the new one)
   * @param {String} userId - User ID
   * @param {Buffer} fileBuffer - New file buffer
   * @returns {Promise<Object>} Updated user with the new avatar
   */
  static async replaceAvatar(userId, fileBuffer) {
    // Retrieve the current user
    const currentUser = await User.findById(userId).select("avatar");

    if (!currentUser) {
      throw new Error("User not found");
    }

    // Delete the old avatar if it exists
    if (currentUser.avatar) {
      try {
        await this.deleteFromCloudinary(currentUser.avatar);
      } catch (error) {
        console.warn("⚠️ Could not delete old avatar:", error.message);
        // Continue even if deletion fails
      }
    }

    // Upload the new avatar
    const uploadResult = await this.uploadToCloudinary(fileBuffer);

    // Update the user
    const updatedUser = await this.updateUserAvatar(
      userId,
      uploadResult.secure_url,
    );

    return {
      user: updatedUser,
      avatarUrl: uploadResult.secure_url,
    };
  }
}

module.exports = AvatarService;
