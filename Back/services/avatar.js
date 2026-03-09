const cloudinary = require("../config/cloudinary");
const User = require("../models/user");

/**
 * Service pour gérer les avatars des utilisateurs
 */
class AvatarService {
  /**
   * Upload un avatar vers Cloudinary
   * @param {Buffer} fileBuffer - Buffer du fichier image
   * @param {Object} options - Options d'upload
   * @returns {Promise<Object>} Résultat de l'upload avec secure_url
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
   * Met à jour l'avatar d'un utilisateur dans la base de données
   * @param {String} userId - ID de l'utilisateur
   * @param {String} avatarUrl - URL de l'avatar
   * @returns {Promise<Object>} Utilisateur mis à jour
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
   * Supprime un avatar de Cloudinary
   * @param {String} avatarUrl - URL de l'avatar à supprimer
   * @returns {Promise<Object>} Résultat de la suppression
   */
  static async deleteFromCloudinary(avatarUrl) {
    try {
      // Extraire le public_id de l'URL Cloudinary
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
   * Remplace l'avatar d'un utilisateur (supprime l'ancien et upload le nouveau)
   * @param {String} userId - ID de l'utilisateur
   * @param {Buffer} fileBuffer - Buffer du nouveau fichier
   * @returns {Promise<Object>} Utilisateur mis à jour avec le nouvel avatar
   */
  static async replaceAvatar(userId, fileBuffer) {
    // Récupérer l'utilisateur actuel
    const currentUser = await User.findById(userId).select("avatar");

    if (!currentUser) {
      throw new Error("User not found");
    }

    // Supprimer l'ancien avatar si existant
    if (currentUser.avatar) {
      try {
        await this.deleteFromCloudinary(currentUser.avatar);
      } catch (error) {
        console.warn("⚠️ Could not delete old avatar:", error.message);
        // Continue même si la suppression échoue
      }
    }

    // Upload le nouvel avatar
    const uploadResult = await this.uploadToCloudinary(fileBuffer);

    // Mettre à jour l'utilisateur
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
