const Touriste = require("../models/touriste");
const UserService = require("./user");

/**
 * Service for managing tourist-specific operations
 */
class TouristeService {
  /**
   * Get a tourist by ID
   * @param {String} touristeId - Tourist ID
   * @returns {Promise<Object>} Tourist
   */
  static async getTouristeById(touristeId) {
    const touriste =
      await Touriste.findById(touristeId).select("-mot_de_passe");

    if (!touriste) {
      throw new Error("Tourist not found");
    }

    return touriste;
  }

  /**
   * Get all tourists
   * @returns {Promise<Array>} Tourist list
   */
  static async getAllTouristes() {
    const touristes = await Touriste.find().select("-mot_de_passe");
    return touristes;
  }

  /**
   * Update tourist-specific information
   * @param {String} touristeId - Tourist ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated tourist
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
      throw new Error("Tourist not found");
    }

    console.log("✅ Touriste profile updated:", touristeId);
    return touriste;
  }

  /**
   * Get statistics for a tourist
   * @param {String} touristeId - Tourist ID
   * @returns {Promise<Object>} Tourist statistics
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
   * Check if a user is a tourist
   * @param {String} userId - User ID
   * @returns {Promise<Boolean>} True if tourist
   */
  static async isTouriste(userId) {
    const user = await Touriste.findById(userId);
    return !!user;
  }
}

module.exports = TouristeService;
