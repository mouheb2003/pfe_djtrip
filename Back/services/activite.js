const Activite = require("../models/activite");
const cloudinary = require("../config/cloudinary");

/**
 * Service pour gérer les opérations sur les activités
 */
class ActiviteService {
  /**
   * Upload une image vers Cloudinary
   * @param {Buffer} fileBuffer - Buffer du fichier image
   * @param {Object} options - Options d'upload
   * @returns {Promise<Object>} Résultat de l'upload avec secure_url
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
   * Upload plusieurs images vers Cloudinary
   * @param {Array<Buffer>} fileBuffers - Array de buffers des fichiers images
   * @returns {Promise<Array<String>>} Array des URLs des images uploadées
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
   * Supprime une image de Cloudinary
   * @param {String} imageUrl - URL de l'image à supprimer
   * @returns {Promise<Object>} Résultat de la suppression
   */
  static async deleteImageFromCloudinary(imageUrl) {
    try {
      // Extraire le public_id de l'URL Cloudinary
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
   * Crée une nouvelle activité
   * @param {Object} activiteData - Données de l'activité
   * @param {String} organisatorId - ID de l'organisateur
   * @returns {Promise<Object>} Activité créée
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
   * Récupère une activité par son ID
   * @param {String} activiteId - ID de l'activité
   * @returns {Promise<Object>} Activité
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
   * Récupère toutes les activités
   * @param {Object} filters - Filtres de recherche (optionnel)
   * @returns {Promise<Array>} Liste des activités
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
   * Récupère les activités d'un organisateur
   * @param {String} organisatorId - ID de l'organisateur
   * @returns {Promise<Array>} Liste des activités de l'organisateur
   */
  static async getActivitesByOrganisator(organisatorId) {
    const activites = await Activite.find({
      organisateur_id: organisatorId,
    });

    return activites;
  }

  /**
   * Met à jour une activité
   * @param {String} activiteId - ID de l'activité
   * @param {Object} updateData - Données à mettre à jour
   * @param {String} organisatorId - ID de l'organisateur (pour vérification)
   * @returns {Promise<Object>} Activité mise à jour
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
   * Supprime une activité
   * @param {String} activiteId - ID de l'activité
   * @param {String} organisatorId - ID de l'organisateur (pour vérification)
   * @returns {Promise<Boolean>} Succès de l'opération
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
   * Recherche des activités avec filtre avancé
   * @param {Object} searchParams - Paramètres de recherche
   * @returns {Promise<Array>} Liste des activités trouvées
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
   * Met à jour la disponibilité d'une activité
   * @param {String} activiteId - ID de l'activité
   * @param {Boolean} disponible - Nouvelle disponibilité
   * @param {String} organisatorId - ID de l'organisateur (pour vérification)
   * @returns {Promise<Object>} Activité mise à jour
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
