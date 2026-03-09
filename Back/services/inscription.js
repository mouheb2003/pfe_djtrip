const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");

/**
 * Service pour gérer les inscriptions aux activités
 */
class InscriptionService {
  /**
   * Crée une nouvelle inscription
   * @param {String} touristeId - ID du touriste
   * @param {String} activiteId - ID de l'activité
   * @param {Object} inscriptionData - Données supplémentaires (optionnel)
   * @returns {Promise<Object>} Inscription créée
   */
  static async createInscription(touristeId, activiteId, inscriptionData = {}) {
    // Vérifier que l'activité existe et est disponible
    const activite = await Activite.findById(activiteId);

    if (!activite) {
      throw new Error("Activity not found");
    }

    if (!activite.disponible) {
      throw new Error("Activity is not available");
    }

    // Vérifier que le touriste existe
    const touriste = await Touriste.findById(touristeId);

    if (!touriste) {
      throw new Error("Touriste not found");
    }

    // Vérifier si le touriste n'est pas déjà inscrit
    const existingInscription = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activiteId,
      statut: { $in: ["confirmée", "en attente"] },
    });

    if (existingInscription) {
      throw new Error("You are already registered for this activity");
    }

    // Vérifier les places disponibles
    if (
      activite.places_disponibles !== undefined &&
      activite.places_disponibles <= 0
    ) {
      throw new Error("No places available for this activity");
    }

    // Créer l'inscription
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activiteId,
      date_inscription: new Date(),
      statut: "en attente",
      montant_paye: inscriptionData.montant_paye || activite.prix,
      ...inscriptionData,
    });

    await inscription.save();

    // Décrémenter les places disponibles si applicable
    if (activite.places_disponibles !== undefined) {
      activite.places_disponibles -= 1;
      await activite.save();
    }

    console.log("✅ New inscription created:", inscription._id);
    return inscription;
  }

  /**
   * Récupère une inscription par son ID
   * @param {String} inscriptionId - ID de l'inscription
   * @returns {Promise<Object>} Inscription
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
   * Récupère toutes les inscriptions d'un touriste
   * @param {String} touristeId - ID du touriste
   * @returns {Promise<Array>} Liste des inscriptions
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
   * Récupère toutes les inscriptions pour une activité
   * @param {String} activiteId - ID de l'activité
   * @returns {Promise<Array>} Liste des inscriptions
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
   * Met à jour le statut d'une inscription
   * @param {String} inscriptionId - ID de l'inscription
   * @param {String} statut - Nouveau statut
   * @returns {Promise<Object>} Inscription mise à jour
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

    // Si on annule une inscription confirmée ou en attente, libérer la place
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
   * Annule une inscription
   * @param {String} inscriptionId - ID de l'inscription
   * @param {String} touristeId - ID du touriste (pour vérification)
   * @returns {Promise<Object>} Inscription annulée
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

    // Libérer la place
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
   * Supprime une inscription
   * @param {String} inscriptionId - ID de l'inscription
   * @returns {Promise<Boolean>} Succès de l'opération
   */
  static async deleteInscription(inscriptionId) {
    const inscription = await Inscription.findById(inscriptionId);

    if (!inscription) {
      throw new Error("Inscription not found");
    }

    // Libérer la place si l'inscription n'était pas déjà annulée
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
   * Récupère les statistiques d'inscriptions pour une activité
   * @param {String} activiteId - ID de l'activité
   * @returns {Promise<Object>} Statistiques
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
