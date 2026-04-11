const Activite = require("../models/activite");
const cloudinary = require("../config/cloudinary");

/**
 * Service for managing activity operations
 */
class ActiviteService {
  /**
   * Uploads an image to Cloudinary
   * @param {Buffer} fileBuffer - Image file buffer
   * @param {Object} options - Upload options
   * @returns {Promise<Object>} Upload result with secure_url
   */
  static async uploadImageToCloudinary(fileBuffer, options = {}) {
    const defaultOptions = {
      folder: "DJTrip/activites",
      transformation: {
        width: 1200,
        height: 800,
        crop: "limit",
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
   * Uploads multiple images to Cloudinary
   * @param {Array<Buffer>} fileBuffers - Array of image file buffers
   * @returns {Promise<Array<String>>} Array of uploaded image URLs
   */
  static async uploadMultipleImages(fileBuffers) {
    try {
      const uploadPromises = fileBuffers.map((buffer) =>
        this.uploadImageToCloudinary(buffer),
      );

      const results = await Promise.all(uploadPromises);
      return results.map((result) => result.secure_url);
    } catch (error) {
      console.error("❌ Error uploading multiple images:", error);
      throw error;
    }
  }

  /**
   * Deletes an image from Cloudinary
   * @param {String} imageUrl - URL of the image to delete
   * @returns {Promise<Object>} Deletion result
   */
  static async deleteImageFromCloudinary(imageUrl) {
    try {
      // Extract the public_id from the Cloudinary URL
      const urlParts = imageUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const publicId = `DJTrip/activites/${filename.split(".")[0]}`;

      const result = await cloudinary.uploader.destroy(publicId);
      console.log("🗑️ Image deleted from Cloudinary:", publicId);
      return result;
    } catch (error) {
      console.error("❌ Error deleting image from Cloudinary:", error);
      throw error;
    }
  }

  /**
   * Creates a new activity
   * @param {Object} activiteData - Activity data
   * @param {String} organisatorId - Organizer ID
   * @returns {Promise<Object>} Created activity
   */
  static async createActivite(activiteData, organisatorId) {
    const {
      nom,
      description,
      prix,
      categorie,
      lieu,
      date_debut,
      date_fin,
      ...additionalData
    } = activiteData;

    // Validate required fields
    if (!nom || !description || !prix || !lieu || !date_debut) {
      throw new Error(
        "Missing required fields: nom, description, prix, lieu, date_debut are required",
      );
    }

    const activite = new Activite({
      nom,
      description,
      prix,
      categorie,
      lieu,
      date_debut,
      date_fin,
      organisateur_id: organisatorId,
      ...additionalData,
    });

    await activite.save();

    console.log("✅ New activite created:", activite._id);
    return activite;
  }

  /**
   * Retrieves an activity by its ID
   * @param {String} activiteId - Activity ID
   * @returns {Promise<Object>} Activity
   */
  static async getActiviteById(activiteId) {
    const activite = await Activite.findById(activiteId).populate(
      "organisateur_id",
      "fullname email organisation_name",
    );

    if (!activite) {
      throw new Error("Activite not found");
    }

    return activite;
  }

  /**
   * Retrieves all activities
   * @param {Object} filters - Search filters (optional)
   * @returns {Promise<Array>} List of activities
   */
  static async getAllActivites(filters = {}) {
    const query = {};

    // Apply filters if provided
    if (filters.categorie) {
      query.categorie = filters.categorie;
    }

    if (filters.lieu) {
      query.lieu = new RegExp(filters.lieu, "i"); // Case-insensitive search
    }

    if (filters.prixMax) {
      query.prix = { $lte: filters.prixMax };
    }

    if (filters.disponible !== undefined) {
      query.disponible = filters.disponible;
    }

    const activites = await Activite.find(query).populate(
      "organisateur_id",
      "fullname email organisation_name",
    );

    return activites;
  }

  /**
   * Retrieves activities for an organizer
   * @param {String} organisatorId - Organizer ID
   * @returns {Promise<Array>} List of organizer's activities
   */
  static async getActivitesByOrganisator(organisatorId) {
    const activites = await Activite.find({
      organisateur_id: organisatorId,
    });

    return activites;
  }

  /**
   * Updates an activity
   * @param {String} activiteId - Activity ID
   * @param {Object} updateData - Data to update
   * @param {String} organisatorId - Organizer ID (for verification)
   * @returns {Promise<Object>} Updated activity
   */
  static async updateActivite(activiteId, updateData, organisatorId) {
    // First verify that the activity belongs to the organisator
    const activite = await Activite.findById(activiteId);

    if (!activite) {
      throw new Error("Activite not found");
    }

    if (activite.organisateur_id.toString() !== organisatorId) {
      throw new Error("Unauthorized: You can only update your own activities");
    }

    // Restrictedfields that cannot be updated
    const restrictedFields = ["_id", "organisateur_id", "date_creation"];

    // Remove restricted fields
    const sanitizedData = { ...updateData };
    restrictedFields.forEach((field) => delete sanitizedData[field]);

    // Update activity
    const updatedActivite = await Activite.findByIdAndUpdate(
      activiteId,
      { $set: sanitizedData },
      { new: true, runValidators: true },
    ).populate("organisateur_id", "fullname email organisation_name");

    console.log("✅ Activite updated:", activiteId);
    return updatedActivite;
  }

  /**
   * Deletes an activity
   * @param {String} activiteId - Activity ID
   * @param {String} organisatorId - Organizer ID (for verification)
   * @returns {Promise<Boolean>} Operation success
   */
  static async deleteActivite(activiteId, organisatorId) {
    // First verify that the activity belongs to the organisator
    const activite = await Activite.findById(activiteId);

    if (!activite) {
      throw new Error("Activite not found");
    }

    if (activite.organisateur_id.toString() !== organisatorId) {
      throw new Error("Unauthorized: You can only delete your own activities");
    }

    await Activite.findByIdAndDelete(activiteId);

    console.log("🗑️ Activite deleted:", activiteId);
    return true;
  }

  /**
   * Searches activities with advanced filters
   * @param {Object} searchParams - Search parameters
   * @returns {Promise<Array>} List of found activities
   */
  static async searchActivites(searchParams) {
    const { keyword, categorie, lieu, prixMin, prixMax, dateDebut, dateFin } =
      searchParams;

    const query = {};

    // Keyword search in name and description
    if (keyword) {
      query.$or = [
        { nom: new RegExp(keyword, "i") },
        { description: new RegExp(keyword, "i") },
      ];
    }

    // Category filter
    if (categorie) {
      query.categorie = categorie;
    }

    // Location filter
    if (lieu) {
      query.lieu = new RegExp(lieu, "i");
    }

    // Price range filter
    if (prixMin || prixMax) {
      query.prix = {};
      if (prixMin) query.prix.$gte = prixMin;
      if (prixMax) query.prix.$lte = prixMax;
    }

    // Date range filter
    if (dateDebut || dateFin) {
      query.date_debut = {};
      if (dateDebut) query.date_debut.$gte = new Date(dateDebut);
      if (dateFin) query.date_debut.$lte = new Date(dateFin);
    }

    // Only show available activities
    query.disponible = true;

    const activites = await Activite.find(query).populate(
      "organisateur_id",
      "fullname email organisation_name",
    );

    return activites;
  }

  /**
   * Updates an activity's availability
   * @param {String} activiteId - Activity ID
   * @param {Boolean} disponible - New availability value
   * @param {String} organisatorId - Organizer ID (for verification)
   * @returns {Promise<Object>} Updated activity
   */
  static async updateDisponibilite(activiteId, disponible, organisatorId) {
    const activite = await Activite.findById(activiteId);

    if (!activite) {
      throw new Error("Activite not found");
    }

    if (activite.organisateur_id.toString() !== organisatorId) {
      throw new Error("Unauthorized: You can only update your own activities");
    }

    activite.disponible = disponible;
    await activite.save();

    console.log(
      `✅ Activite disponibilite updated to ${disponible}:`,
      activiteId,
    );
    return activite;
  }
}

module.exports = ActiviteService;
