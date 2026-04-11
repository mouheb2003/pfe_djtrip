const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");

/**
 * Service for managing activity registrations
 */
class InscriptionService {
  /**
   * Creates a new registration
   * @param {String} touristeId - Tourist ID
   * @param {String} activiteId - Activity ID
   * @param {Object} inscriptionData - Additional data (optional)
   * @returns {Promise<Object>} Created registration
   */
  static async createInscription(touristeId, activiteId, inscriptionData = {}) {
    // Verify the activity exists and is available
    const activite = await Activite.findById(activiteId);

    if (!activite) {
      throw new Error("Activity not found");
    }

    if (!activite.disponible) {
      throw new Error("Activity is not available");
    }

    // Verify the tourist exists
    const touriste = await Touriste.findById(touristeId);

    if (!touriste) {
      throw new Error("Tourist not found");
    }

    // Check if the tourist is not already registered
    const existingInscription = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activiteId,
      statut: { $in: ["confirmée", "en attente"] },
    });

    if (existingInscription) {
      throw new Error("You are already registered for this activity");
    }

    // Check available spots
    if (
      activite.places_disponibles !== undefined &&
      activite.places_disponibles <= 0
    ) {
      throw new Error("No places available for this activity");
    }

    // Create the registration
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activiteId,
      date_inscription: new Date(),
      statut: "en attente",
      montant_paye: inscriptionData.montant_paye || activite.prix,
      ...inscriptionData,
    });

    await inscription.save();

    // Decrement available spots if applicable
    if (activite.places_disponibles !== undefined) {
      activite.places_disponibles -= 1;
      await activite.save();
    }

    console.log("✅ New inscription created:", inscription._id);
    return inscription;
  }

  /**
   * Get a registration by ID
   * @param {String} inscriptionId - Registration ID
   * @returns {Promise<Object>} Registration
   */
  static async getInscriptionById(inscriptionId) {
    const inscription = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email num_tel")
      .populate("activite_id");

    if (!inscription) {
      throw new Error("Inscription not found");
    }

    return inscription;
  }

  /**
   * Get all registrations for a tourist
   * @param {String} touristeId - Tourist ID
   * @returns {Promise<Array>} Registration list
   */
  static async getInscriptionsByTouriste(touristeId) {
    const inscriptions = await Inscription.find({
      touriste_id: touristeId,
    })
      .populate("activite_id")
      .sort({ date_inscription: -1 });

    return inscriptions;
  }

  /**
   * Get all registrations for an activity
   * @param {String} activiteId - Activity ID
   * @returns {Promise<Array>} Registration list
   */
  static async getInscriptionsByActivite(activiteId) {
    const inscriptions = await Inscription.find({
      activite_id: activiteId,
    })
      .populate("touriste_id", "fullname email num_tel")
      .sort({ date_inscription: -1 });

    return inscriptions;
  }

  /**
   * Update the status of a registration
   * @param {String} inscriptionId - Registration ID
   * @param {String} statut - New status
   * @returns {Promise<Object>} Updated registration
   */
  static async updateStatut(inscriptionId, statut) {
    const validStatuts = ["en attente", "confirmée", "annulée", "terminée"];

    if (!validStatuts.includes(statut)) {
      throw new Error(
        `Invalid status. Must be one of: ${validStatuts.join(", ")}`,
      );
    }

    const inscription = await Inscription.findById(inscriptionId);

    if (!inscription) {
      throw new Error("Inscription not found");
    }

    // If cancelling a confirmed or pending registration, free up the spot
    if (
      (inscription.statut === "confirmée" ||
        inscription.statut === "en attente") &&
      statut === "annulée"
    ) {
      const activite = await Activite.findById(inscription.activite_id);
      if (activite && activite.places_disponibles !== undefined) {
        activite.places_disponibles += 1;
        await activite.save();
      }
    }

    inscription.statut = statut;
    await inscription.save();

    console.log(`✅ Inscription status updated to ${statut}:`, inscriptionId);
    return inscription;
  }

  /**
   * Cancel a registration
   * @param {String} inscriptionId - Registration ID
   * @param {String} touristeId - Tourist ID (for verification)
   * @returns {Promise<Object>} Cancelled registration
   */
  static async cancelInscription(inscriptionId, touristeId) {
    const inscription = await Inscription.findById(inscriptionId);

    if (!inscription) {
      throw new Error("Inscription not found");
    }

    if (inscription.touriste_id.toString() !== touristeId) {
      throw new Error(
        "Unauthorized: You can only cancel your own inscriptions",
      );
    }

    if (inscription.statut === "annulée") {
      throw new Error("Inscription is already cancelled");
    }

    if (inscription.statut === "terminée") {
      throw new Error("Cannot cancel a completed inscription");
    }

    // Free up the spot
    const activite = await Activite.findById(inscription.activite_id);
    if (activite && activite.places_disponibles !== undefined) {
      activite.places_disponibles += 1;
      await activite.save();
    }

    inscription.statut = "annulée";
    await inscription.save();

    console.log("❌ Inscription cancelled:", inscriptionId);
    return inscription;
  }

  /**
   * Delete a registration
   * @param {String} inscriptionId - Registration ID
   * @returns {Promise<Boolean>} Operation success
   */
  static async deleteInscription(inscriptionId) {
    const inscription = await Inscription.findById(inscriptionId);

    if (!inscription) {
      throw new Error("Inscription not found");
    }

    // Free up the spot if the registration was not already cancelled
    if (inscription.statut !== "annulée") {
      const activite = await Activite.findById(inscription.activite_id);
      if (activite && activite.places_disponibles !== undefined) {
        activite.places_disponibles += 1;
        await activite.save();
      }
    }

    await Inscription.findByIdAndDelete(inscriptionId);

    console.log("🗑️ Inscription deleted:", inscriptionId);
    return true;
  }

  /**
   * Get registration statistics for an activity
   * @param {String} activiteId - Activity ID
   * @returns {Promise<Object>} Statistics
   */
  static async getActivityInscriptionStats(activiteId) {
    const inscriptions = await Inscription.find({ activite_id: activiteId });

    const stats = {
      total: inscriptions.length,
      enAttente: inscriptions.filter((i) => i.statut === "en attente").length,
      confirmees: inscriptions.filter((i) => i.statut === "confirmée").length,
      annulees: inscriptions.filter((i) => i.statut === "annulée").length,
      terminees: inscriptions.filter((i) => i.statut === "terminée").length,
    };

    return stats;
  }
}

module.exports = InscriptionService;
