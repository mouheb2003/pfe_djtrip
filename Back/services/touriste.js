const Touriste = require("../models/touriste");
const UserService = require("./user");

/**
 * Service pour gérer les opérations spécifiques aux touristes
 */
class TouristeService {
  /**
   * Récupère un touriste par son ID
   * @param {String} touristeId - ID du touriste
   * @returns {Promise<Object>} Touriste
   */
  static async getTouristeById(touristeId) {
    const touriste =
      await Touriste.findById(touristeId).select("-mot_de_passe");

    if (!touriste) {
      throw new Error("Touriste not found");
    }

    return touriste;
  }

  /**
   * Récupère tous les touristes
   * @returns {Promise<Array>} Liste des touristes
   */
  static async getAllTouristes() {
    const touristes = await Touriste.find().select("-mot_de_passe");
    return touristes;
  }

  /**
   * Met à jour les informations spécifiques d'un touriste
   * @param {String} touristeId - ID du touriste
   * @param {Object} updateData - Données à mettre à jour
   * @returns {Promise<Object>} Touriste mis à jour
   */
  static async updateTouristeProfile(touristeId, updateData) {
    // Fields specific to Touriste
    const allowedFields = [
      "languePreferee",
      "centreInteret",
      "preferencesVoyage",
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

    const touriste = await Touriste.findByIdAndUpdate(
      touristeId,
      { $set: sanitizedData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      throw new Error("Touriste not found");
    }

    console.log("✅ Touriste profile updated:", touristeId);
    return touriste;
  }

  /**
   * Récupère les statistiques d'un touriste
   * @param {String} touristeId - ID du touriste
   * @returns {Promise<Object>} Statistiques du touriste
   */
  static async getTouristeStats(touristeId) {
    const touriste = await this.getTouristeById(touristeId);

    // Placeholder for future stats calculation
    // This could include number of activities booked, reviews written, etc.
    const stats = {
      totalActivitiesBooked: 0,
      totalReviews: 0,
      ...touriste.toObject(),
    };

    return stats;
  }

  /**
   * Vérifie si un utilisateur est un touriste
   * @param {String} userId - ID de l'utilisateur
   * @returns {Promise<Boolean>} True si touriste
   */
  static async isTouriste(userId) {
    const user = await Touriste.findById(userId);
    return !!user;
  }
}

module.exports = TouristeService;
