const Organisator = require("../models/organisator");
const UserService = require("./user");

/**
 * Service for managing organizer-specific operations
 */
class OrganisatorService {
  /**
   * Get an organizer by ID
   * @param {String} organisatorId - Organizer ID
   * @returns {Promise<Object>} Organizer
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
   * Get all organizers
   * @returns {Promise<Array>} Organizer list
   */
  static async getAllOrganisators() {
    const organisators = await Organisator.find().select("-mot_de_passe");
    return organisators;
  }

  /**
   * Update an organizer's specific information
   * @param {String} organisatorId - Organizer ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated organizer
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
   * Get statistics for an organizer
   * @param {String} organisatorId - Organizer ID
   * @returns {Promise<Object>} Organizer statistics
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
   * Check if a user is an organizer
   * @param {String} userId - User ID
   * @returns {Promise<Boolean>} True if organizer
   */
  static async isOrganisator(userId) {
    const user = await Organisator.findById(userId);
    return !!user;
  }
}

module.exports = OrganisatorService;
