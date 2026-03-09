const Organisator = require("../models/organisator");
const UserService = require("./user");

/**
 * Service pour gérer les opérations spécifiques aux organisateurs
 */
class OrganisatorService {
  /**
   * Récupère un organisateur par son ID
   * @param {String} organisatorId - ID de l'organisateur
   * @returns {Promise<Object>} Organisateur
   */
  static async getOrganisatorById(organisatorId) {
    const organisator =
      await Organisator.findById(organisatorId).select("-mot_de_passe");

    if (!organisator) {
      throw new Error("Organisator not found");
    }

    return organisator;
  }

  /**
   * Récupère tous les organisateurs
   * @returns {Promise<Array>} Liste des organisateurs
   */
  static async getAllOrganisators() {
    const organisators = await Organisator.find().select("-mot_de_passe");
    return organisators;
  }

  /**
   * Met à jour les informations spécifiques d'un organisateur
   * @param {String} organisatorId - ID de l'organisateur
   * @param {Object} updateData - Données à mettre à jour
   * @returns {Promise<Object>} Organisateur mis à jour
   */
  static async updateOrganisatorProfile(organisatorId, updateData) {
    // Fields specific to Organisator
    const allowedFields = [
      "organisation_name",
      "organisation_type",
      "website",
      "social_media",
      "num_tel",
      "bio",
      "pays_origine",
      "age",
    ];

    // Filter only allowed fields
    const sanitizedData = {};
    Object.keys(updateData).forEach((key) => {
      if (allowedFields.includes(key)) {
        sanitizedData[key] = updateData[key];
      }
    });

    const organisator = await Organisator.findByIdAndUpdate(
      organisatorId,
      { $set: sanitizedData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!organisator) {
      throw new Error("Organisator not found");
    }

    console.log("✅ Organisator profile updated:", organisatorId);
    return organisator;
  }

  /**
   * Récupère les statistiques d'un organisateur
   * @param {String} organisatorId - ID de l'organisateur
   * @returns {Promise<Object>} Statistiques de l'organisateur
   */
  static async getOrganisatorStats(organisatorId) {
    const organisator = await this.getOrganisatorById(organisatorId);

    // Placeholder for future stats calculation
    // This could include number of activities created, bookings, ratings, etc.
    const stats = {
      totalActivities: 0,
      totalBookings: 0,
      averageRating: 0,
      ...organisator.toObject(),
    };

    return stats;
  }

  /**
   * Vérifie si un utilisateur est un organisateur
   * @param {String} userId - ID de l'utilisateur
   * @returns {Promise<Boolean>} True si organisateur
   */
  static async isOrganisator(userId) {
    const user = await Organisator.findById(userId);
    return !!user;
  }
}

module.exports = OrganisatorService;
